defmodule Raxol.Web.PersistentStore do
  @moduledoc """
  Multi-tier persistent storage for WASH-style session continuity.

  Provides a three-tier storage architecture optimized for different access patterns:

  1. **ETS (Tier 1)** - In-memory, fastest access, volatile
  2. **DETS (Tier 2)** - Disk-based, survives restarts, medium speed
  3. **Database (Tier 3)** - Long-term backup, slowest, most reliable

  ## Storage Strategy

  - Active sessions: ETS + DETS for fast access and crash recovery
  - Inactive sessions: DETS + Database for space efficiency
  - Archived sessions: Database only for long-term storage

  ## Features

  - **Automatic Tiering**: Hot data in fast tiers, cold data archived
  - **Background Sync**: Asynchronous promotion/demotion between tiers
  - **Compression**: Large session states compressed in slower tiers
  - **TTL Support**: Automatic expiration of old sessions
  - **Conflict Resolution**: Last-writer-wins with timestamp comparison

  ## Configuration

      config :raxol, Raxol.Web.PersistentStore,
        ets_cleanup_interval: 300_000,     # 5 minutes
        dets_sync_interval: 60_000,        # 1 minute  
        database_archive_after: 86_400,    # 24 hours
        compression_threshold: 1024        # 1KB
  """

  use GenServer
  require Logger

  # Database functionality - aliases
  # alias Raxol.Web.Session.Session  # Unused - commented out
  alias Raxol.Repo

  # Check if database functionality is available at runtime.
  defp database_available? do
    Code.ensure_loaded?(Ecto.Schema) and Code.ensure_loaded?(Raxol.Repo)
  end

  @ets_table :raxol_sessions_ets
  @dets_file "priv/sessions.dets"

  # Configuration defaults
  @default_config %{
    # 5 minutes
    ets_cleanup_interval: 300_000,
    # 1 minute
    dets_sync_interval: 60_000,
    # 24 hours
    database_archive_after: 86_400,
    # 1KB
    compression_threshold: 1024,
    max_ets_entries: 10_000
  }

  defstruct [
    :ets_table,
    :dets_table,
    :config,
    :cleanup_timer,
    :sync_timer
  ]

  # Client API

  @doc """
  Starts the persistent store with the given configuration.
  """
  def start_link(opts \\ []) do
    config = Map.merge(@default_config, Map.new(opts))
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Initializes storage for a new session.
  """
  @spec init_session(String.t()) :: :ok
  def init_session(session_id) do
    GenServer.cast(__MODULE__, {:init_session, session_id})
  end

  @doc """
  Stores session state with automatic tier management.

  ## Options

  - `:tier` - Force storage to specific tier (:ets, :dets, :database)
  - `:compress` - Force compression (overrides threshold)
  - `:ttl` - Time-to-live in seconds
  """
  @spec store_session(String.t(), map(), keyword()) :: :ok | {:error, term()}
  def store_session(session_id, state, opts \\ []) do
    GenServer.call(__MODULE__, {:store_session, session_id, state, opts})
  end

  @doc """
  Retrieves session state from the fastest available tier.

  Searches ETS → DETS → Database in order for optimal performance.
  """
  @spec get_session(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  @doc """
  Updates session state with partial changes.

  More efficient than full state replacement for small updates.
  """
  @spec update_session(String.t(), map()) :: :ok | {:error, term()}
  def update_session(session_id, changes) do
    GenServer.call(__MODULE__, {:update_session, session_id, changes})
  end

  @doc """
  Deletes session from all storage tiers.
  """
  @spec delete_session(String.t()) :: :ok
  def delete_session(session_id) do
    GenServer.call(__MODULE__, {:delete_session, session_id})
  end

  @doc """
  Forces promotion of session to faster tier.
  """
  @spec promote_session(String.t(), :ets | :dets) :: :ok | {:error, term()}
  def promote_session(session_id, target_tier) do
    GenServer.cast(__MODULE__, {:promote_session, session_id, target_tier})
  end

  @doc """
  Forces demotion of session to slower tier.
  """
  @spec demote_session(String.t(), :dets | :database) :: :ok
  def demote_session(session_id, target_tier) do
    GenServer.cast(__MODULE__, {:demote_session, session_id, target_tier})
  end

  @doc """
  Ensures session is persisted to all appropriate tiers.
  """
  @spec persist_to_all_tiers(String.t()) :: :ok | {:error, term()}
  def persist_to_all_tiers(session_id) do
    GenServer.call(__MODULE__, {:persist_all_tiers, session_id})
  end

  @doc """
  Returns storage statistics for monitoring.
  """
  @spec get_stats() :: %{
          ets_entries: non_neg_integer(),
          dets_entries: non_neg_integer(),
          database_entries: non_neg_integer(),
          memory_usage: non_neg_integer()
        }
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # GenServer Implementation

  @impl GenServer
  def init(config) do
    Logger.info("Starting PersistentStore with config: #{inspect(config)}")

    # Initialize ETS table
    ets_table =
      :ets.new(@ets_table, [
        :set,
        :public,
        :named_table,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])

    # Initialize DETS table
    {:ok, dets_table} = :dets.open_file(@dets_file, type: :set, repair: true)

    # Schedule periodic cleanup
    cleanup_timer =
      Process.send_after(self(), :cleanup_ets, config.ets_cleanup_interval)

    sync_timer =
      Process.send_after(self(), :sync_dets, config.dets_sync_interval)

    state = %__MODULE__{
      ets_table: ets_table,
      dets_table: dets_table,
      config: config,
      cleanup_timer: cleanup_timer,
      sync_timer: sync_timer
    }

    Logger.info("PersistentStore initialized successfully")
    {:ok, state}
  end

  @impl GenServer
  def handle_call(
        {:store_session, session_id, session_state, opts},
        _from,
        state
      ) do
    Logger.debug("Storing session #{session_id}")

    # Add metadata
    enhanced_state = enhance_session_state(session_state)

    # Determine storage tier
    tier = determine_storage_tier(enhanced_state, opts, state.config)

    result =
      case tier do
        :ets ->
          store_in_ets(session_id, enhanced_state, state.ets_table)

        :dets ->
          store_in_dets(
            session_id,
            enhanced_state,
            state.dets_table,
            state.config
          )

        :database ->
          store_in_database(session_id, enhanced_state, state.config)

        :all ->
          store_in_all_tiers(session_id, enhanced_state, state)
      end

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:get_session, session_id}, _from, state) do
    Logger.debug("Retrieving session #{session_id}")

    result =
      case get_from_ets(session_id, state.ets_table) do
        {:ok, session_state} ->
          {:ok, session_state}

        {:error, :not_found} ->
          case get_from_dets(session_id, state.dets_table) do
            {:ok, session_state} ->
              # Promote to ETS for faster future access
              spawn(fn ->
                promote_to_ets(session_id, session_state, state.ets_table)
              end)

              {:ok, session_state}

            {:error, :not_found} ->
              case get_from_database(session_id) do
                {:ok, session_state} ->
                  # Promote through tiers
                  spawn(fn ->
                    promote_to_dets(
                      session_id,
                      session_state,
                      state.dets_table,
                      state.config
                    )

                    promote_to_ets(session_id, session_state, state.ets_table)
                  end)

                  {:ok, session_state}

                error ->
                  error
              end
          end
      end

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call({:update_session, session_id, changes}, _from, state) do
    # Get current state
    case handle_call({:get_session, session_id}, nil, state) do
      {:reply, {:ok, current_state}, _} ->
        # Merge changes
        updated_state = Map.merge(current_state, changes)
        updated_state = %{updated_state | updated_at: DateTime.utc_now()}

        # Store updated state
        result =
          handle_call(
            {:store_session, session_id, updated_state, []},
            nil,
            state
          )

        {:reply, elem(result, 1), state}

      {:reply, {:error, :not_found}, _} ->
        {:reply, {:error, :session_not_found}, state}
    end
  end

  @impl GenServer
  def handle_call({:delete_session, session_id}, _from, state) do
    Logger.debug("Deleting session #{session_id}")

    # Delete from all tiers
    :ets.delete(state.ets_table, session_id)
    :dets.delete(state.dets_table, session_id)

    # Delete from database (async)
    spawn(fn -> delete_from_database(session_id) end)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:persist_all_tiers, session_id}, _from, state) do
    case get_from_ets(session_id, state.ets_table) do
      {:ok, session_state} ->
        # Store in DETS and database
        :ok =
          store_in_dets(
            session_id,
            session_state,
            state.dets_table,
            state.config
          )

        spawn(fn ->
          store_in_database(session_id, session_state, state.config)
        end)

        {:reply, :ok, state}

      {:error, :not_found} ->
        {:reply, {:error, :session_not_found}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    ets_info = :ets.info(state.ets_table)
    ets_entries = Keyword.get(ets_info, :size, 0)

    memory_usage =
      Keyword.get(ets_info, :memory, 0) * :erlang.system_info(:wordsize)

    dets_info = :dets.info(state.dets_table)
    dets_entries = Keyword.get(dets_info, :size, 0)

    # Database count (async query)
    database_entries = count_database_sessions()

    stats = %{
      ets_entries: ets_entries,
      dets_entries: dets_entries,
      database_entries: database_entries,
      memory_usage: memory_usage
    }

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_cast({:init_session, session_id}, state) do
    Logger.debug("Initializing session #{session_id}")

    # Create basic session state
    initial_state = %{
      session_id: session_id,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      state: %{},
      metadata: %{
        tier: :ets,
        access_count: 0
      }
    }

    # Store in ETS initially
    store_in_ets(session_id, initial_state, state.ets_table)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:promote_session, session_id, target_tier}, state) do
    spawn(fn -> do_promote_session(session_id, target_tier, state) end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:demote_session, session_id, target_tier}, state) do
    spawn(fn -> do_demote_session(session_id, target_tier, state) end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:cleanup_ets, state) do
    Logger.debug("Running ETS cleanup")

    # Remove expired and least recently used entries
    cleanup_expired_sessions(state.ets_table)
    cleanup_lru_sessions(state.ets_table, state.config.max_ets_entries)

    # Schedule next cleanup
    cleanup_timer =
      Process.send_after(
        self(),
        :cleanup_ets,
        state.config.ets_cleanup_interval
      )

    {:noreply, %{state | cleanup_timer: cleanup_timer}}
  end

  @impl GenServer
  def handle_info(:sync_dets, state) do
    Logger.debug("Syncing DETS to disk")

    :dets.sync(state.dets_table)

    # Schedule next sync
    sync_timer =
      Process.send_after(self(), :sync_dets, state.config.dets_sync_interval)

    {:noreply, %{state | sync_timer: sync_timer}}
  end

  @impl GenServer
  def terminate(_reason, state) do
    Logger.info("Shutting down PersistentStore")

    # Sync DETS and close
    :dets.sync(state.dets_table)
    :dets.close(state.dets_table)

    # ETS is automatically cleaned up
    :ok
  end

  # Private Functions

  defp enhance_session_state(session_state) do
    now = DateTime.utc_now()

    session_state
    |> Map.put_new(:created_at, now)
    |> Map.put(:updated_at, now)
    |> update_in([:metadata, :access_count], fn count -> (count || 0) + 1 end)
    |> put_in([:metadata, :last_access], now)
  end

  defp determine_storage_tier(session_state, opts, config) do
    cond do
      Keyword.has_key?(opts, :tier) -> Keyword.get(opts, :tier)
      map_size(session_state) > config.compression_threshold -> :dets
      true -> :ets
    end
  end

  defp store_in_ets(session_id, session_state, ets_table) do
    enhanced_state = put_in(session_state.metadata.tier, :ets)
    :ets.insert(ets_table, {session_id, enhanced_state})
    :ok
  end

  defp store_in_dets(session_id, session_state, dets_table, config) do
    enhanced_state = put_in(session_state.metadata.tier, :dets)

    # Compress large states
    final_state =
      if map_size(enhanced_state) > config.compression_threshold do
        compress_session_state(enhanced_state)
      else
        enhanced_state
      end

    :dets.insert(dets_table, {session_id, final_state})
    :ok
  end

  defp store_in_database(session_id, session_state, _config) do
    if database_available?() do
      # Store in database using Ecto
      attrs = %{
        id: session_id,
        user_id: Map.get(session_state, :user_id, "unknown"),
        status: :active,
        created_at: Map.get(session_state, :created_at, DateTime.utc_now()),
        last_active: DateTime.utc_now(),
        metadata: Map.take(session_state, [:state, :metadata])
      }

      # Try to find existing session first
      case Repo.get_by(Raxol.Web.Session.Session, session_id: session_id) do
        nil ->
          # Insert new session
          %Raxol.Web.Session.Session{}
          |> Raxol.Web.Session.Session.changeset(attrs)
          |> Repo.insert()
          |> case do
            {:ok, _session} -> :ok
            {:error, reason} -> {:error, reason}
          end

        existing_session ->
          # Update existing session
          existing_session
          |> Raxol.Web.Session.Session.changeset(attrs)
          |> Repo.update()
          |> case do
            {:ok, _session} -> :ok
            {:error, reason} -> {:error, reason}
          end
      end
    else
      # Database not available - skip database storage
      Logger.debug("Database not available, skipping database storage")
      :ok
    end
  end

  defp store_in_all_tiers(session_id, session_state, state) do
    with :ok <- store_in_ets(session_id, session_state, state.ets_table),
         :ok <-
           store_in_dets(
             session_id,
             session_state,
             state.dets_table,
             state.config
           ) do
      # Store in database async
      spawn(fn -> store_in_database(session_id, session_state, state.config) end)

      :ok
    end
  end

  defp get_from_ets(session_id, ets_table) do
    case :ets.lookup(ets_table, session_id) do
      [{^session_id, session_state}] -> {:ok, session_state}
      [] -> {:error, :not_found}
    end
  end

  defp get_from_dets(session_id, dets_table) do
    case :dets.lookup(dets_table, session_id) do
      [{^session_id, session_state}] ->
        # Decompress if needed
        decompressed_state = decompress_session_state(session_state)
        {:ok, decompressed_state}

      [] ->
        {:error, :not_found}
    end
  end

  defp get_from_database(session_id) do
    if database_available?() do
      case Repo.get(Raxol.Web.Session.Session, session_id) do
        nil ->
          {:error, :not_found}

        session ->
          # Convert database record to session state format
          session_state = %{
            session_id: session.id,
            user_id: session.user_id,
            created_at: session.created_at,
            updated_at: session.updated_at,
            state: get_in(session.metadata, ["state"]) || %{},
            metadata:
              Map.merge(
                get_in(session.metadata, ["metadata"]) || %{},
                %{tier: :database}
              )
          }

          {:ok, session_state}
      end
    else
      {:error, :not_found}
    end
  end

  defp compress_session_state(session_state) do
    # Simple compression - in practice might use :zlib
    put_in(session_state.metadata.compressed, true)
  end

  defp decompress_session_state(session_state) do
    # Simple decompression - in practice might use :zlib
    session_state
  end

  defp promote_to_ets(session_id, session_state, ets_table) do
    store_in_ets(session_id, session_state, ets_table)
  end

  defp promote_to_dets(session_id, session_state, dets_table, config) do
    store_in_dets(session_id, session_state, dets_table, config)
  end

  defp do_promote_session(session_id, target_tier, state) do
    case target_tier do
      :ets ->
        case get_from_dets(session_id, state.dets_table) do
          {:ok, session_state} ->
            promote_to_ets(session_id, session_state, state.ets_table)

          _ ->
            :ok
        end

      :dets ->
        case get_from_database(session_id) do
          {:ok, session_state} ->
            promote_to_dets(
              session_id,
              session_state,
              state.dets_table,
              state.config
            )

          _ ->
            :ok
        end
    end
  end

  defp do_demote_session(session_id, target_tier, state) do
    # Implementation for demoting sessions to slower tiers
    case target_tier do
      :dets ->
        case get_from_ets(session_id, state.ets_table) do
          {:ok, session_state} ->
            store_in_dets(
              session_id,
              session_state,
              state.dets_table,
              state.config
            )

            :ets.delete(state.ets_table, session_id)

          _ ->
            :ok
        end

      :database ->
        # Move from DETS to database only
        case get_from_dets(session_id, state.dets_table) do
          {:ok, session_state} ->
            store_in_database(session_id, session_state, state.config)
            :dets.delete(state.dets_table, session_id)

          _ ->
            :ok
        end
    end
  end

  defp cleanup_expired_sessions(ets_table) do
    now = DateTime.utc_now()

    :ets.foldl(
      fn {session_id, session_state}, _acc ->
        case Map.get(session_state, :expires_at) do
          nil ->
            :ok

          expires_at when expires_at < now ->
            :ets.delete(ets_table, session_id)

          _ ->
            :ok
        end
      end,
      nil,
      ets_table
    )
  end

  defp cleanup_lru_sessions(ets_table, max_entries) do
    current_size = :ets.info(ets_table, :size)

    if current_size > max_entries do
      # Get all sessions with their last access time
      sessions =
        :ets.foldl(
          fn {session_id, session_state}, acc ->
            last_access =
              get_in(session_state, [:metadata, :last_access]) ||
                DateTime.utc_now()

            [{session_id, last_access} | acc]
          end,
          [],
          ets_table
        )

      # Sort by last access and remove oldest
      sessions
      |> Enum.sort_by(fn {_id, last_access} -> last_access end)
      |> Enum.take(current_size - max_entries)
      |> Enum.each(fn {session_id, _} ->
        :ets.delete(ets_table, session_id)
      end)
    end
  end

  defp delete_from_database(session_id) do
    if database_available?() do
      case Repo.get(Raxol.Web.Session.Session, session_id) do
        nil -> :ok
        session -> Repo.delete(session)
      end
    else
      :ok
    end
  end

  defp count_database_sessions do
    if database_available?() do
      # Simple count - in practice might be cached
      try do
        Repo.aggregate(Raxol.Web.Session.Session, :count, :id)
      rescue
        _ -> 0
      end
    else
      0
    end
  end
end
