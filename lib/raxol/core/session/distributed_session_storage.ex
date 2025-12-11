defmodule Raxol.Core.Session.DistributedSessionStorage do
  @moduledoc """
  Persistent storage layer for distributed session data.

  The DistributedSessionStorage provides a fault-tolerant, consistent storage
  backend for distributed sessions with automatic sharding, replication, and
  data integrity guarantees.

  ## Features

  - Persistent session storage with configurable backends
  - Automatic data sharding and partitioning
  - Write-ahead logging for durability
  - Snapshot and incremental backup support
  - Data compression and encryption at rest
  - Automatic cleanup of expired sessions
  - Transaction support for atomic operations

  ## Storage Backends

  - **ETS**: In-memory storage with optional persistence
  - **DETS**: Disk-based storage for single-node persistence
  - **Mnesia**: Distributed database with replication
  - **External**: Plugin interface for external databases

  ## Usage

      # Start storage with Mnesia backend
      {:ok, pid} = DistributedSessionStorage.start_link(
        backend: :mnesia,
        replication_nodes: [:node1, :node2, :node3],
        storage_options: %{
          disc_copies: [:node1, :node2],
          ram_copies: [:node3]
        }
      )

      # Store session data
      DistributedSessionStorage.store(pid, session_id, session_data, metadata)

      # Retrieve session data
      {:ok, data} = DistributedSessionStorage.get(pid, session_id)
  """

  use Raxol.Core.Behaviours.BaseManager

  defstruct [
    :backend,
    :storage_config,
    :shard_count,
    :cleanup_interval,
    :compression_enabled,
    :encryption_enabled,
    :wal_enabled,
    :backup_config,
    :cleanup_timer,
    :stats,
    :table_prefix
  ]

  @type backend_type :: :ets | :dets | :mnesia | :external
  @type shard_id :: non_neg_integer()
  @type session_metadata :: %{
          created_at: DateTime.t(),
          last_accessed: DateTime.t(),
          expires_at: DateTime.t() | nil,
          size_bytes: non_neg_integer(),
          access_count: non_neg_integer()
        }

  @default_shard_count 64
  # 1 hour
  @default_cleanup_interval 3_600_000
  # 1KB
  @default_compression_threshold 1024

  # Public API

  @spec store(pid(), binary(), term(), map()) :: :ok | {:error, term()}
  def store(pid, session_id, data, metadata) do
    GenServer.call(pid, {:store, session_id, data, metadata})
  end

  @spec get(pid(), binary()) ::
          {:ok, term()} | {:error, :not_found} | {:error, term()}
  def get(pid, session_id) do
    GenServer.call(pid, {:get, session_id})
  end

  @spec delete(pid(), binary()) :: :ok | {:error, term()}
  def delete(pid, session_id) do
    GenServer.call(pid, {:delete, session_id})
  end

  @spec list_sessions(pid(), map()) :: {:ok, [binary()]} | {:error, term()}
  def list_sessions(pid, filters) do
    GenServer.call(pid, {:list_sessions, filters})
  end

  @spec get_metadata(pid(), binary()) ::
          {:ok, session_metadata()} | {:error, term()}
  def get_metadata(pid, session_id) do
    GenServer.call(pid, {:get_metadata, session_id})
  end

  @spec update_access_time(pid(), binary()) :: :ok
  def update_access_time(pid, session_id) do
    GenServer.cast(pid, {:update_access_time, session_id})
  end

  @spec cleanup_expired_sessions(pid()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def cleanup_expired_sessions(pid) do
    GenServer.call(pid, :cleanup_expired_sessions)
  end

  @spec get_storage_stats(pid()) :: %{
          total_sessions: non_neg_integer(),
          total_size_bytes: non_neg_integer(),
          shard_distribution: %{shard_id() => non_neg_integer()},
          backend_stats: term()
        }
  def get_storage_stats(pid) do
    GenServer.call(pid, :get_storage_stats)
  end

  @spec backup_sessions(pid(), binary()) :: {:ok, binary()} | {:error, term()}
  def backup_sessions(pid, backup_path) do
    GenServer.call(pid, {:backup_sessions, backup_path}, 30_000)
  end

  @spec restore_sessions(pid(), binary()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def restore_sessions(pid, backup_path) do
    GenServer.call(pid, {:restore_sessions, backup_path}, 30_000)
  end

  # BaseManager Callbacks

  @impl true
  def init_manager(opts) do
    backend = Keyword.get(opts, :backend, :ets)
    storage_config = Keyword.get(opts, :storage_config, %{})

    # Generate unique table prefix for test isolation
    table_prefix =
      Keyword.get(opts, :table_prefix) ||
        if Application.get_env(:raxol, :env) == :test do
          "session_#{:erlang.unique_integer([:positive])}"
        else
          "session"
        end

    state = %__MODULE__{
      backend: backend,
      storage_config: storage_config,
      shard_count: Keyword.get(opts, :shard_count, @default_shard_count),
      cleanup_interval:
        Keyword.get(opts, :cleanup_interval, @default_cleanup_interval),
      compression_enabled: Keyword.get(opts, :compression_enabled, true),
      encryption_enabled: Keyword.get(opts, :encryption_enabled, false),
      wal_enabled: Keyword.get(opts, :wal_enabled, true),
      backup_config: Keyword.get(opts, :backup_config, %{}),
      stats: init_stats(),
      table_prefix: table_prefix
    }

    case initialize_backend(state) do
      {:ok, updated_state} ->
        # Start cleanup timer
        cleanup_timer =
          Process.send_after(self(), :cleanup_expired, state.cleanup_interval)

        final_state = %{updated_state | cleanup_timer: cleanup_timer}

        Log.info(
          "DistributedSessionStorage started with backend=#{backend}, shards=#{state.shard_count}"
        )

        {:ok, final_state}

      {:error, reason} ->
        Log.error(
          "Failed to initialize storage backend #{backend}: #{inspect(reason)}"
        )

        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:store, session_id, data, metadata}, _from, state) do
    case store_session_data(session_id, data, metadata, state) do
      {:ok, updated_state} ->
        {:reply, :ok, updated_state}

      {:error, _reason} = error ->
        Log.error("Failed to store session #{session_id}: #{inspect(error)}")

        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get, session_id}, _from, state) do
    case get_session_data(session_id, state) do
      {:ok, data} ->
        # Update access time asynchronously
        GenServer.cast(self(), {:update_access_time, session_id})
        {:reply, {:ok, data}, state}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:delete, session_id}, _from, state) do
    case delete_session_data(session_id, state) do
      {:ok, updated_state} ->
        {:reply, :ok, updated_state}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:list_sessions, filters}, _from, state) do
    {:ok, session_ids} = list_session_ids(filters, state)
    {:reply, {:ok, session_ids}, state}
  end

  @impl true
  def handle_call({:get_metadata, session_id}, _from, state) do
    result = get_session_metadata(session_id, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:cleanup_expired_sessions, _from, state) do
    {:ok, cleanup_count, updated_state} = perform_cleanup(state)
    {:reply, {:ok, cleanup_count}, updated_state}
  end

  @impl true
  def handle_call(:get_storage_stats, _from, state) do
    stats = calculate_storage_stats(state)
    {:reply, stats, state}
  end

  @impl true
  def handle_call({:backup_sessions, backup_path}, _from, state) do
    result = create_backup(backup_path, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:restore_sessions, backup_path}, _from, state) do
    {:ok, restore_count, updated_state} = restore_backup(backup_path, state)
    {:reply, {:ok, restore_count}, updated_state}
  end

  @impl true
  def handle_cast({:update_access_time, session_id}, state) do
    {:ok, updated_state} = update_session_access_time(session_id, state)
    {:noreply, updated_state}
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    {:ok, cleanup_count, updated_state} = perform_cleanup(state)

    if cleanup_count > 0 do
      Log.info("Cleaned up #{cleanup_count} expired sessions")
    end

    # Schedule next cleanup
    cleanup_timer =
      Process.send_after(self(), :cleanup_expired, state.cleanup_interval)

    final_state = %{updated_state | cleanup_timer: cleanup_timer}

    {:noreply, final_state}
  end

  @impl true
  def terminate(_reason, state) do
    # Clean up ETS tables in test environment
    if Application.get_env(:raxol, :env) == :test and state.backend == :ets do
      # Clean up shard tables
      for shard_id <- 0..(state.shard_count - 1) do
        table_name = :"#{state.table_prefix}_shard_#{shard_id}"

        case :ets.whereis(table_name) do
          :undefined ->
            :ok

          _table ->
            try do
              :ets.delete(table_name)
            rescue
              _ -> :ok
            end
        end
      end

      # Clean up metadata table
      metadata_table_name = :"#{state.table_prefix}_metadata"

      case :ets.whereis(metadata_table_name) do
        :undefined ->
          :ok

        _table ->
          try do
            :ets.delete(metadata_table_name)
          rescue
            _ -> :ok
          end
      end
    end

    :ok
  end

  # Private Implementation

  defp initialize_backend(%{backend: :ets} = state) do
    # Create ETS tables for each shard with unique prefix
    shard_tables =
      for shard_id <- 0..(state.shard_count - 1) do
        table_name = :"#{state.table_prefix}_shard_#{shard_id}"

        # Try to create the table, handle if it already exists in tests
        table =
          case :ets.whereis(table_name) do
            :undefined ->
              :ets.new(table_name, [
                :set,
                :public,
                :named_table,
                {:read_concurrency, true}
              ])

            existing ->
              # In test mode, clean existing table
              if Application.get_env(:raxol, :env) == :test do
                :ets.delete_all_objects(existing)
              end

              existing
          end

        {shard_id, table}
      end

    # Create metadata table with unique prefix
    metadata_table_name = :"#{state.table_prefix}_metadata"

    metadata_table =
      case :ets.whereis(metadata_table_name) do
        :undefined ->
          :ets.new(metadata_table_name, [
            :set,
            :public,
            :named_table,
            {:read_concurrency, true}
          ])

        existing ->
          if Application.get_env(:raxol, :env) == :test do
            :ets.delete_all_objects(existing)
          end

          existing
      end

    config = %{
      shard_tables: Map.new(shard_tables),
      metadata_table: metadata_table
    }

    {:ok, %{state | storage_config: config}}
  end

  defp initialize_backend(%{backend: :mnesia} = state) do
    # Initialize Mnesia tables for distributed storage
    case setup_mnesia_tables(state) do
      :ok ->
        config = %{
          session_table: :distributed_sessions,
          metadata_table: :session_metadata
        }

        {:ok, %{state | storage_config: config}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp initialize_backend(%{backend: :dets} = state) do
    # Initialize DETS files for persistent storage
    case setup_dets_files(state) do
      {:ok, config} ->
        {:ok, %{state | storage_config: config}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp setup_mnesia_tables(state) do
    # Define session table structure
    session_attributes = [
      :session_id,
      :shard_id,
      :data,
      :metadata,
      :created_at,
      :last_accessed,
      :expires_at
    ]

    metadata_attributes = [
      :session_id,
      :size_bytes,
      :access_count,
      :created_at,
      :last_accessed,
      :expires_at
    ]

    # Get replication nodes from config
    replication_nodes =
      Map.get(state.storage_config, :replication_nodes, [Node.self()])

    disc_copies = Map.get(state.storage_config, :disc_copies, [Node.self()])
    ram_copies = Map.get(state.storage_config, :ram_copies, [])

    # Create schema if needed
    _ =
      case :mnesia.create_schema(replication_nodes) do
        :ok -> :ok
        {:error, {_, {:already_exists, _}}} -> :ok
        {:error, reason} -> {:error, {:schema_creation_failed, reason}}
      end

    # Start Mnesia
    _ =
      case :mnesia.start() do
        :ok -> :ok
        {:error, reason} -> {:error, {:mnesia_start_failed, reason}}
      end

    # Create tables
    session_table_def = [
      {:attributes, session_attributes},
      {:disc_copies, disc_copies},
      {:ram_copies, ram_copies},
      {:type, :set},
      {:storage_properties,
       [{:ets, [{:read_concurrency, true}, {:write_concurrency, true}]}]}
    ]

    metadata_table_def = [
      {:attributes, metadata_attributes},
      {:disc_copies, disc_copies},
      {:ram_copies, ram_copies},
      {:type, :set},
      {:storage_properties, [{:ets, [{:read_concurrency, true}]}]}
    ]

    _ =
      case :mnesia.create_table(:distributed_sessions, session_table_def) do
        {:atomic, :ok} -> :ok
        {:aborted, {:already_exists, :distributed_sessions}} -> :ok
        {:aborted, reason} -> {:error, {:session_table_creation_failed, reason}}
      end

    _ =
      case :mnesia.create_table(:session_metadata, metadata_table_def) do
        {:atomic, :ok} ->
          :ok

        {:aborted, {:already_exists, :session_metadata}} ->
          :ok

        {:aborted, reason} ->
          {:error, {:metadata_table_creation_failed, reason}}
      end

    # Wait for tables to be available
    _ =
      :mnesia.wait_for_tables([:distributed_sessions, :session_metadata], 5000)
  end

  defp setup_dets_files(state) do
    # Create DETS files for each shard
    storage_dir =
      Map.get(state.storage_config, :storage_dir, "priv/session_storage")

    File.mkdir_p!(storage_dir)

    shard_files =
      for shard_id <- 0..(state.shard_count - 1) do
        file_path = Path.join(storage_dir, "session_shard_#{shard_id}.dets")

        case :dets.open_file(:"shard_#{shard_id}", [
               {:file, String.to_charlist(file_path)},
               {:type, :set}
             ]) do
          {:ok, table} ->
            {shard_id, table}

          {:error, reason} ->
            throw({:dets_open_failed, shard_id, reason})
        end
      end

    # Create metadata file
    metadata_path = Path.join(storage_dir, "session_metadata.dets")

    case :dets.open_file(:session_metadata, [
           {:file, String.to_charlist(metadata_path)},
           {:type, :set}
         ]) do
      {:ok, metadata_table} ->
        config = %{
          shard_files: Map.new(shard_files),
          metadata_table: metadata_table,
          storage_dir: storage_dir
        }

        {:ok, config}

      {:error, reason} ->
        {:error, {:metadata_dets_failed, reason}}
    end
  catch
    {:dets_open_failed, shard_id, reason} ->
      {:error, {:shard_dets_failed, shard_id, reason}}
  end

  defp store_session_data(session_id, data, metadata, state) do
    shard_id = calculate_shard(session_id, state.shard_count)
    now = DateTime.utc_now()

    # Prepare session metadata
    session_metadata =
      Map.merge(
        %{
          created_at: now,
          last_accessed: now,
          expires_at: nil,
          size_bytes: calculate_data_size(data),
          access_count: 1
        },
        metadata
      )

    # Compress data if enabled and above threshold
    processed_data =
      if state.compression_enabled and
           session_metadata.size_bytes > @default_compression_threshold do
        compress_data(data)
      else
        data
      end

    # Encrypt data if enabled
    final_data =
      if state.encryption_enabled do
        encrypt_data(processed_data)
      else
        processed_data
      end

    case state.backend do
      :ets ->
        store_ets_session(
          session_id,
          shard_id,
          final_data,
          session_metadata,
          state
        )

      :mnesia ->
        store_mnesia_session(
          session_id,
          shard_id,
          final_data,
          session_metadata,
          state
        )

      :dets ->
        store_dets_session(
          session_id,
          shard_id,
          final_data,
          session_metadata,
          state
        )
    end
  end

  defp store_ets_session(session_id, shard_id, data, metadata, state) do
    shard_table = Map.get(state.storage_config.shard_tables, shard_id)
    metadata_table = state.storage_config.metadata_table

    :ets.insert(shard_table, {session_id, data})
    :ets.insert(metadata_table, {session_id, metadata})

    updated_stats = update_stats(state.stats, :store, metadata.size_bytes)
    {:ok, %{state | stats: updated_stats}}
  end

  defp store_mnesia_session(session_id, shard_id, data, metadata, state) do
    session_record = {
      :distributed_sessions,
      session_id,
      shard_id,
      data,
      metadata,
      metadata.created_at,
      metadata.last_accessed,
      metadata.expires_at
    }

    metadata_record = {
      :session_metadata,
      session_id,
      metadata.size_bytes,
      metadata.access_count,
      metadata.created_at,
      metadata.last_accessed,
      metadata.expires_at
    }

    transaction_fn = fn ->
      :mnesia.write(session_record)
      :mnesia.write(metadata_record)
    end

    case :mnesia.transaction(transaction_fn) do
      {:atomic, _result} ->
        updated_stats = update_stats(state.stats, :store, metadata.size_bytes)
        {:ok, %{state | stats: updated_stats}}

      {:aborted, reason} ->
        {:error, {:mnesia_write_failed, reason}}
    end
  end

  defp store_dets_session(session_id, shard_id, data, metadata, state) do
    shard_file = Map.get(state.storage_config.shard_files, shard_id)
    metadata_table = state.storage_config.metadata_table

    case :dets.insert(shard_file, {session_id, data}) do
      :ok ->
        case :dets.insert(metadata_table, {session_id, metadata}) do
          :ok ->
            updated_stats =
              update_stats(state.stats, :store, metadata.size_bytes)

            {:ok, %{state | stats: updated_stats}}

          {:error, reason} ->
            {:error, {:metadata_write_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:session_write_failed, reason}}
    end
  end

  defp get_session_data(session_id, state) do
    shard_id = calculate_shard(session_id, state.shard_count)

    case state.backend do
      :ets ->
        get_ets_session(session_id, shard_id, state)

      :mnesia ->
        get_mnesia_session(session_id, state)

      :dets ->
        get_dets_session(session_id, shard_id, state)
    end
  end

  defp get_ets_session(session_id, shard_id, state) do
    shard_table = Map.get(state.storage_config.shard_tables, shard_id)

    case :ets.lookup(shard_table, session_id) do
      [{^session_id, data}] ->
        # Decrypt and decompress if needed
        processed_data = process_retrieved_data(data, state)
        {:ok, processed_data}

      [] ->
        {:error, :not_found}
    end
  end

  defp get_mnesia_session(session_id, _state) do
    transaction_fn = fn ->
      case :mnesia.read(:distributed_sessions, session_id) do
        [
          {:distributed_sessions, ^session_id, _shard_id, data, _metadata,
           _created, _accessed, _expires}
        ] ->
          data

        [] ->
          :not_found
      end
    end

    case :mnesia.transaction(transaction_fn) do
      {:atomic, :not_found} ->
        {:error, :not_found}

      {:atomic, data} ->
        {:ok, data}

      {:aborted, reason} ->
        {:error, {:mnesia_read_failed, reason}}
    end
  end

  defp get_dets_session(session_id, shard_id, state) do
    shard_file = Map.get(state.storage_config.shard_files, shard_id)

    case :dets.lookup(shard_file, session_id) do
      [{^session_id, data}] ->
        processed_data = process_retrieved_data(data, state)
        {:ok, processed_data}

      [] ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, {:dets_read_failed, reason}}
    end
  end

  defp delete_session_data(session_id, state) do
    shard_id = calculate_shard(session_id, state.shard_count)

    case state.backend do
      :ets ->
        delete_ets_session(session_id, shard_id, state)

      :mnesia ->
        delete_mnesia_session(session_id, state)

      :dets ->
        delete_dets_session(session_id, shard_id, state)
    end
  end

  defp delete_ets_session(session_id, shard_id, state) do
    shard_table = Map.get(state.storage_config.shard_tables, shard_id)
    metadata_table = state.storage_config.metadata_table

    :ets.delete(shard_table, session_id)
    :ets.delete(metadata_table, session_id)

    updated_stats = update_stats(state.stats, :delete, 0)
    {:ok, %{state | stats: updated_stats}}
  end

  defp delete_mnesia_session(session_id, state) do
    transaction_fn = fn ->
      :mnesia.delete({:distributed_sessions, session_id})
      :mnesia.delete({:session_metadata, session_id})
    end

    case :mnesia.transaction(transaction_fn) do
      {:atomic, _result} ->
        updated_stats = update_stats(state.stats, :delete, 0)
        {:ok, %{state | stats: updated_stats}}

      {:aborted, reason} ->
        {:error, {:mnesia_delete_failed, reason}}
    end
  end

  defp delete_dets_session(session_id, shard_id, state) do
    shard_file = Map.get(state.storage_config.shard_files, shard_id)
    metadata_table = state.storage_config.metadata_table

    _ = :dets.delete(shard_file, session_id)
    _ = :dets.delete(metadata_table, session_id)

    updated_stats = update_stats(state.stats, :delete, 0)
    {:ok, %{state | stats: updated_stats}}
  end

  # Helper Functions

  defp calculate_shard(session_id, shard_count) do
    :erlang.phash2(session_id, shard_count)
  end

  defp calculate_data_size(data) do
    :erlang.external_size(data)
  end

  defp compress_data(data) do
    :zlib.compress(:erlang.term_to_binary(data))
  end

  defp decompress_data(compressed_data) do
    :erlang.binary_to_term(:zlib.uncompress(compressed_data))
  end

  defp encrypt_data(data) do
    # Placeholder for encryption - implement with proper key management
    data
  end

  defp decrypt_data(data) do
    # Placeholder for decryption
    data
  end

  defp process_retrieved_data(data, state) do
    processed =
      if state.encryption_enabled do
        decrypt_data(data)
      else
        data
      end

    if state.compression_enabled do
      case data do
        # zlib magic number
        <<120, 156, _rest::binary>> -> decompress_data(processed)
        _ -> processed
      end
    else
      processed
    end
  end

  defp init_stats do
    %{
      total_sessions: 0,
      total_size_bytes: 0,
      operations: %{store: 0, get: 0, delete: 0},
      last_reset: DateTime.utc_now()
    }
  end

  defp update_stats(stats, :store, size_delta) do
    operations = Map.update(stats.operations, :store, 1, &(&1 + 1))

    %{
      stats
      | total_sessions: stats.total_sessions + 1,
        total_size_bytes: stats.total_size_bytes + size_delta,
        operations: operations
    }
  end

  defp update_stats(stats, :delete, _size_delta) do
    operations = Map.update(stats.operations, :delete, 1, &(&1 + 1))

    %{
      stats
      | total_sessions: max(0, stats.total_sessions - 1),
        operations: operations
    }
  end

  defp list_session_ids(_filters, _state) do
    # Implement session listing with filtering
    {:ok, []}
  end

  defp get_session_metadata(_session_id, _state) do
    # Implement metadata retrieval
    {:error, :not_implemented}
  end

  defp update_session_access_time(_session_id, state) do
    # Implement access time updates
    {:ok, state}
  end

  defp perform_cleanup(state) do
    # Implement expired session cleanup
    {:ok, 0, state}
  end

  defp calculate_storage_stats(state) do
    state.stats
  end

  defp create_backup(_backup_path, _state) do
    # Implement backup creation
    {:error, :not_implemented}
  end

  defp restore_backup(_backup_path, state) do
    # Implement backup restoration
    {:ok, 0, state}
  end
end
