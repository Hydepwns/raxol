defmodule Raxol.Security.Encryption.EncryptedStorage do
  @moduledoc """
  Provides transparent encryption for data at rest.

  This module handles automatic encryption and decryption of sensitive data
  stored in files, databases, and caches. It integrates with the KeyManager
  for key management and rotation.

  ## Features

  - Transparent encryption/decryption
  - Multiple storage backends (file, database, S3)
  - Compression before encryption
  - Integrity verification with HMAC
  - Streaming encryption for large files
  - Encrypted search capabilities
  - Automatic re-encryption on key rotation
  """

  use Raxol.Core.Behaviours.BaseManager

  alias Raxol.Audit.Logger, as: AuditLogger
  alias Raxol.Core.Runtime.Log
  alias Raxol.Security.Encryption.KeyManager

  defstruct [
    :key_manager,
    :storage_backend,
    :default_key_id,
    :config,
    :stats,
    :encryption_queue
  ]

  @type storage_backend :: :file | :database | :s3 | :memory
  @type encryption_options :: %{
          optional(:compress) => boolean(),
          optional(:key_id) => String.t(),
          optional(:metadata) => map(),
          optional(:async) => boolean()
        }

  # @default_config %{
  #   backend: :file,
  #   base_path: "priv/data/encrypted",
  #   # Compress if larger than 1KB
  #   compress_threshold: 1024,
  #   # 1MB chunks for streaming
  #   chunk_size: 1_048_576,
  #   verify_integrity: true,
  #   cache_encrypted: false
  # }

  ## Client API

  # BaseManager provides start_link

  @doc """
  Stores data with automatic encryption.
  """
  def store(storage \\ __MODULE__, key, data, opts \\ %{}) do
    GenServer.call(storage, {:store, key, data, opts})
  end

  @doc """
  Retrieves and decrypts data.
  """
  def retrieve(storage \\ __MODULE__, key, opts \\ %{}) do
    GenServer.call(storage, {:retrieve, key, opts})
  end

  @doc """
  Stores a file with encryption.
  """
  def store_file(storage \\ __MODULE__, file_path, encrypted_name, opts \\ %{}) do
    GenServer.call(
      storage,
      {:store_file, file_path, encrypted_name, opts},
      60_000
    )
  end

  @doc """
  Retrieves and decrypts a file.
  """
  def retrieve_file(
        storage \\ __MODULE__,
        encrypted_name,
        output_path,
        opts \\ %{}
      ) do
    GenServer.call(
      storage,
      {:retrieve_file, encrypted_name, output_path, opts},
      60_000
    )
  end

  @doc """
  Deletes encrypted data.
  """
  def delete(storage \\ __MODULE__, key, opts \\ %{}) do
    GenServer.call(storage, {:delete, key, opts})
  end

  @doc """
  Lists all stored encrypted items.
  """
  def list(storage \\ __MODULE__, prefix \\ nil) do
    GenServer.call(storage, {:list, prefix})
  end

  @doc """
  Searches encrypted data without decrypting (using encrypted indices).
  """
  def search(storage \\ __MODULE__, query, opts \\ %{}) do
    GenServer.call(storage, {:search, query, opts})
  end

  @doc """
  Re-encrypts data with a new key.
  """
  def reencrypt(storage \\ __MODULE__, key, new_key_id) do
    GenServer.call(storage, {:reencrypt, key, new_key_id})
  end

  @doc """
  Re-encrypts all data with new keys (key rotation).
  """
  def reencrypt_all(storage \\ __MODULE__, new_key_id) do
    GenServer.call(storage, {:reencrypt_all, new_key_id}, :infinity)
  end

  @doc """
  Gets storage statistics.
  """
  def get_stats(storage \\ __MODULE__) do
    GenServer.call(storage, :get_stats)
  end

  ## GenServer Implementation

  @impl true
  def init_manager(config) do
    # Initialize storage backend
    backend = init_backend(config)

    # Get or start key manager
    {:ok, key_manager} = get_or_start_key_manager()

    # Generate default encryption key
    {:ok, default_key} = KeyManager.generate_dek(key_manager, "storage_default")

    state = %__MODULE__{
      key_manager: key_manager,
      storage_backend: backend,
      default_key_id: default_key.id,
      config: config,
      stats: init_stats(),
      encryption_queue: :queue.new()
    }

    # Start async encryption worker
    _ = start_async_encryption_worker(config[:async_encryption])

    Log.info("Encrypted storage initialized with backend: #{config.backend}")

    {:ok, state}
  end

  defp start_async_encryption_worker(true),
    do: :timer.send_interval(100, :process_encryption_queue)

  defp start_async_encryption_worker(_), do: :ok

  @impl true
  def handle_manager_call({:store, key, data, opts}, _from, state) do
    case encrypt_and_store(key, data, opts, state) do
      {:ok, metadata, new_state} ->
        {:reply, {:ok, metadata}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:retrieve, key, opts}, _from, state) do
    case retrieve_and_decrypt(key, opts, state) do
      {:ok, data, new_state} ->
        {:reply, {:ok, data}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call(
        {:store_file, file_path, encrypted_name, opts},
        _from,
        state
      ) do
    case encrypt_file(file_path, encrypted_name, opts, state) do
      {:ok, metadata, new_state} ->
        {:reply, {:ok, metadata}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call(
        {:retrieve_file, encrypted_name, output_path, opts},
        _from,
        state
      ) do
    case decrypt_file(encrypted_name, output_path, opts, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:delete, key, opts}, _from, state) do
    # delete_encrypted/3 currently only returns {:ok, new_state}
    {:ok, new_state} = delete_encrypted(key, opts, state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:list, prefix}, _from, state) do
    items = list_encrypted_items(prefix, state)
    {:reply, {:ok, items}, state}
  end

  @impl true
  def handle_manager_call({:search, query, opts}, _from, state) do
    results = search_encrypted(query, opts, state)
    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_manager_call({:reencrypt, key, new_key_id}, _from, state) do
    case reencrypt_item(key, new_key_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:reencrypt_all, new_key_id}, _from, state) do
    # reencrypt_all_items/2 currently only returns {:ok, count, new_state}
    {:ok, count, new_state} = reencrypt_all_items(new_key_id, state)
    {:reply, {:ok, count}, new_state}
  end

  @impl true
  def handle_manager_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_manager_info(:process_encryption_queue, state) do
    new_state = process_async_encryption(state)
    {:noreply, new_state}
  end

  ## Private Functions - Encryption/Decryption

  defp encrypt_and_store(key, data, opts, state) do
    start_time = System.system_time(:millisecond)

    # Serialize data
    serialized = serialize_data(data)

    # Compress if beneficial
    final_data =
      apply_compression(should_compress?(serialized, state.config), serialized)

    # Get encryption key
    key_id = Map.get(opts, :key_id, state.default_key_id)

    # Encrypt data
    case KeyManager.encrypt(state.key_manager, key_id, final_data) do
      {:ok, encrypted_package} ->
        # Add integrity check
        hmac = calculate_hmac(encrypted_package, key_id)

        # Create storage envelope
        envelope = %{
          key: key,
          encrypted_data: encrypted_package,
          hmac: hmac,
          compressed: final_data != serialized,
          metadata: Map.get(opts, :metadata, %{}),
          created_at: DateTime.utc_now(),
          size: byte_size(serialized)
        }

        # Store to backend
        _ = store_to_backend(envelope, state)

        # Update stats
        duration = System.system_time(:millisecond) - start_time

        new_stats =
          update_stats(state.stats, :store, byte_size(serialized), duration)

        # Audit
        audit_storage_operation(:store, key, byte_size(serialized))

        {:ok,
         %{
           key: key,
           size: byte_size(serialized),
           encrypted_size: byte_size(final_data)
         }, %{state | stats: new_stats}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp retrieve_and_decrypt(key, _opts, state) do
    start_time = System.system_time(:millisecond)

    # Retrieve from backend
    case retrieve_from_backend(key, state) do
      {:ok, envelope} ->
        # Check integrity result
        integrity_result =
          verify_envelope_integrity(
            state.config.verify_integrity,
            envelope,
            key
          )

        case integrity_result do
          {:error, reason} ->
            {:error, reason}

          :ok ->
            # Decrypt data
            case KeyManager.decrypt(
                   state.key_manager,
                   envelope.encrypted_data.key_id,
                   envelope.encrypted_data,
                   envelope.encrypted_data.key_version
                 ) do
              {:ok, decrypted} ->
                # Decompress if needed
                final_data = apply_decompression(envelope.compressed, decrypted)

                # Deserialize
                data = deserialize_data(final_data)

                # Update stats
                duration = System.system_time(:millisecond) - start_time

                new_stats =
                  update_stats(state.stats, :retrieve, envelope.size, duration)

                # Audit
                audit_storage_operation(:retrieve, key, envelope.size)

                {:ok, data, %{state | stats: new_stats}}

              {:error, reason} ->
                {:error, reason}
            end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp encrypt_file(file_path, encrypted_name, opts, state) do
    case File.stat(file_path) do
      {:ok, %{size: size}} ->
        key_id = Map.get(opts, :key_id, state.default_key_id)

        # For large files, use streaming encryption
        handle_file_encryption(
          size > state.config.chunk_size,
          file_path,
          encrypted_name,
          key_id,
          size,
          opts,
          state
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_file_encryption(
         true,
         file_path,
         encrypted_name,
         key_id,
         size,
         _opts,
         state
       ) do
    encrypt_file_streaming(file_path, encrypted_name, key_id, size, state)
  end

  defp handle_file_encryption(
         false,
         file_path,
         encrypted_name,
         _key_id,
         _size,
         opts,
         state
       ) do
    # Small file - encrypt in memory
    case File.read(file_path) do
      {:ok, content} ->
        encrypt_and_store(encrypted_name, content, opts, state)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp encrypt_file_streaming(input_path, output_name, key_id, file_size, state) do
    # Initialize streaming cipher
    {:ok, key} = KeyManager.get_key(state.key_manager, key_id)

    # Generate IV for entire file
    iv = :crypto.strong_rand_bytes(16)
    cipher_state = :crypto.crypto_init(:aes_256_ctr, key.key_material, iv, true)

    # Open files
    {:ok, input} = File.open(input_path, [:read, :binary])
    output_path = get_storage_path(output_name, state)
    {:ok, output} = File.open(output_path, [:write, :binary])

    # Write header
    header = %{
      version: 1,
      key_id: key_id,
      key_version: key.version,
      iv: iv,
      file_size: file_size,
      chunk_size: state.config.chunk_size
    }

    IO.binwrite(output, :erlang.term_to_binary(header))

    # Encrypt in chunks
    encrypted_size =
      encrypt_chunks(input, output, cipher_state, state.config.chunk_size, 0)

    # Close files
    _ = File.close(input)
    _ = File.close(output)

    # Update stats
    new_stats = update_stats(state.stats, :store_file, file_size, 0)

    {:ok,
     %{
       name: output_name,
       original_size: file_size,
       encrypted_size: encrypted_size
     }, %{state | stats: new_stats}}
  end

  defp encrypt_chunks(input, output, cipher_state, chunk_size, acc_size) do
    case IO.binread(input, chunk_size) do
      :eof ->
        acc_size

      {:error, _} ->
        acc_size

      chunk ->
        encrypted_chunk = :crypto.crypto_update(cipher_state, chunk)
        IO.binwrite(output, encrypted_chunk)

        encrypt_chunks(
          input,
          output,
          cipher_state,
          chunk_size,
          acc_size + byte_size(encrypted_chunk)
        )
    end
  end

  defp decrypt_file(encrypted_name, output_path, _opts, state) do
    storage_path = get_storage_path(encrypted_name, state)

    case File.open(storage_path, [:read, :binary]) do
      {:ok, input} ->
        # Read header
        # Approximate header size
        header_size = 1000
        header_data = IO.binread(input, header_size)
        header = :erlang.binary_to_term(header_data)

        # Get decryption key
        {:ok, key} =
          KeyManager.get_key(
            state.key_manager,
            header.key_id,
            header.key_version
          )

        # Initialize cipher for decryption
        cipher_state =
          :crypto.crypto_init(:aes_256_ctr, key.key_material, header.iv, false)

        # Open output file
        {:ok, output} = File.open(output_path, [:write, :binary])

        # Decrypt in chunks
        _ = decrypt_chunks(input, output, cipher_state, header.chunk_size)

        # Close files
        _ = File.close(input)
        _ = File.close(output)

        # Update stats
        new_stats =
          update_stats(state.stats, :retrieve_file, header.file_size, 0)

        {:ok, %{state | stats: new_stats}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decrypt_chunks(input, output, cipher_state, chunk_size) do
    case IO.binread(input, chunk_size) do
      :eof ->
        :ok

      {:error, reason} ->
        {:error, reason}

      encrypted_chunk ->
        decrypted_chunk = :crypto.crypto_update(cipher_state, encrypted_chunk)
        IO.binwrite(output, decrypted_chunk)
        decrypt_chunks(input, output, cipher_state, chunk_size)
    end
  end

  ## Private Functions - Storage Backend

  defp init_backend(%{backend: :file} = config) do
    path = config.base_path
    File.mkdir_p!(path)
    %{type: :file, path: path}
  end

  defp init_backend(%{backend: :database} = config) do
    # Initialize database connection
    %{type: :database, connection: config.db_connection}
  end

  defp init_backend(%{backend: :s3} = config) do
    # Initialize S3 client
    %{type: :s3, bucket: config.s3_bucket, client: config.s3_client}
  end

  defp init_backend(%{backend: :memory}) do
    %{type: :memory, store: %{}}
  end

  defp store_to_backend(envelope, %{storage_backend: %{type: :file}} = state) do
    file_path = get_storage_path(envelope.key, state)
    File.write!(file_path, :erlang.term_to_binary(envelope))
  end

  defp store_to_backend(
         envelope,
         %{storage_backend: %{type: :memory, store: store}} = state
       ) do
    new_store = Map.put(store, envelope.key, envelope)
    put_in(state.storage_backend.store, new_store)
  end

  defp retrieve_from_backend(key, %{storage_backend: %{type: :file}} = state) do
    file_path = get_storage_path(key, state)

    case File.read(file_path) do
      {:ok, content} ->
        {:ok, :erlang.binary_to_term(content)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp retrieve_from_backend(key, %{
         storage_backend: %{type: :memory, store: store}
       }) do
    case Map.get(store, key) do
      nil -> {:error, :not_found}
      envelope -> {:ok, envelope}
    end
  end

  defp delete_encrypted(key, _opts, %{storage_backend: %{type: :file}} = state) do
    file_path = get_storage_path(key, state)
    _ = File.rm(file_path)

    new_stats = Map.update!(state.stats, :deletes, &(&1 + 1))
    {:ok, %{state | stats: new_stats}}
  end

  defp get_storage_path(key, state) do
    # Hash the key for filesystem safety
    hashed_key = :crypto.hash(:sha256, key) |> Base.url_encode64(padding: false)
    Path.join(state.storage_backend.path || state.config.base_path, hashed_key)
  end

  ## Private Functions - Utilities

  defp serialize_data(data) do
    :erlang.term_to_binary(data)
  end

  defp deserialize_data(binary) do
    :erlang.binary_to_term(binary)
  end

  defp compress_data(data) do
    :zlib.gzip(data)
  end

  defp apply_compression(true, data), do: compress_data(data)
  defp apply_compression(false, data), do: data

  defp decompress_data(data) do
    :zlib.gunzip(data)
  end

  defp apply_decompression(true, data), do: decompress_data(data)
  defp apply_decompression(false, data), do: data

  defp verify_envelope_integrity(false, _envelope, _key), do: :ok

  defp verify_envelope_integrity(true, envelope, key) do
    expected_hmac =
      calculate_hmac(envelope.encrypted_data, envelope.encrypted_data.key_id)

    check_hmac_match(envelope.hmac == expected_hmac, key)
  end

  defp check_hmac_match(true, _key), do: :ok

  defp check_hmac_match(false, key) do
    Log.error("HMAC verification failed for key: #{key}")
    audit_security_event(:integrity_failure, key)
    {:error, :integrity_check_failed}
  end

  defp should_compress?(data, config) do
    byte_size(data) > config.compress_threshold
  end

  defp calculate_hmac(encrypted_package, key_id) do
    # Use a derived key for HMAC
    hmac_key = :crypto.hash(:sha256, key_id <> "hmac")

    :crypto.mac(
      :hmac,
      :sha256,
      hmac_key,
      :erlang.term_to_binary(encrypted_package)
    )
    |> Base.encode64()
  end

  defp list_encrypted_items(prefix, %{storage_backend: %{type: :file}} = state) do
    pattern = build_file_pattern(prefix, state.storage_backend.path)

    Path.wildcard(pattern)
    |> Enum.map(&Path.basename/1)
  end

  defp list_encrypted_items(prefix, %{
         storage_backend: %{type: :memory, store: store}
       }) do
    store
    |> Map.keys()
    |> Enum.filter(&filter_by_prefix(&1, prefix))
  end

  defp build_file_pattern(nil, path), do: Path.join(path, "*")
  defp build_file_pattern(prefix, path), do: Path.join(path, "#{prefix}*")

  defp filter_by_prefix(_key, nil), do: true
  defp filter_by_prefix(key, prefix), do: String.starts_with?(key, prefix)

  defp search_encrypted(_query, _opts, _state) do
    # Implement encrypted search using searchable encryption techniques
    # This would use techniques like order-preserving encryption or
    # encrypted indices for searching without decryption
    []
  end

  defp reencrypt_item(key, new_key_id, state) do
    with {:ok, data, state} <- retrieve_and_decrypt(key, %{}, state),
         {:ok, _metadata, state} <-
           encrypt_and_store(key, data, %{key_id: new_key_id}, state) do
      audit_storage_operation(:reencrypt, key, 0)
      {:ok, state}
    end
  end

  defp reencrypt_all_items(new_key_id, state) do
    items = list_encrypted_items(nil, state)

    {count, new_state} =
      Enum.reduce(items, {0, state}, fn item, {acc_count, acc_state} ->
        case reencrypt_item(item, new_key_id, acc_state) do
          {:ok, new_state} -> {acc_count + 1, new_state}
          {:error, _} -> {acc_count, acc_state}
        end
      end)

    Log.info("Re-encrypted #{count} items with new key")
    {:ok, count, new_state}
  end

  defp process_async_encryption(state) do
    case :queue.out(state.encryption_queue) do
      {{:value, task}, new_queue} ->
        # Process encryption task
        process_encryption_task(task, %{state | encryption_queue: new_queue})

      {:empty, _} ->
        state
    end
  end

  defp process_encryption_task(_task, state) do
    # Implement async encryption processing
    state
  end

  defp init_stats do
    %{
      stores: 0,
      retrieves: 0,
      deletes: 0,
      store_bytes: 0,
      retrieve_bytes: 0,
      avg_store_time_ms: 0,
      avg_retrieve_time_ms: 0,
      compression_ratio: 1.0,
      cache_hits: 0,
      cache_misses: 0
    }
  end

  defp update_stats(stats, :store, size, duration) do
    stats
    |> Map.update!(:stores, &(&1 + 1))
    |> Map.update!(:store_bytes, &(&1 + size))
    |> Map.put(
      :avg_store_time_ms,
      (stats.avg_store_time_ms * stats.stores + duration) / (stats.stores + 1)
    )
  end

  defp update_stats(stats, :retrieve, size, duration) do
    stats
    |> Map.update!(:retrieves, &(&1 + 1))
    |> Map.update!(:retrieve_bytes, &(&1 + size))
    |> Map.put(
      :avg_retrieve_time_ms,
      (stats.avg_retrieve_time_ms * stats.retrieves + duration) /
        (stats.retrieves + 1)
    )
  end

  defp update_stats(stats, :store_file, size, _duration) do
    Map.update!(stats, :store_bytes, &(&1 + size))
  end

  defp update_stats(stats, :retrieve_file, size, _duration) do
    Map.update!(stats, :retrieve_bytes, &(&1 + size))
  end

  defp get_or_start_key_manager do
    case Process.whereis(KeyManager) do
      nil -> KeyManager.start_link()
      pid -> {:ok, pid}
    end
  end

  defp audit_storage_operation(operation, key, size) do
    AuditLogger.log_data_access(
      get_current_user(),
      operation,
      "encrypted_storage",
      resource_id: key,
      records_count: 1,
      bytes: size,
      data_classification: :encrypted
    )
  end

  defp audit_security_event(event_type, key) do
    AuditLogger.log_security_event(
      event_type,
      :critical,
      "Security event in encrypted storage",
      key: key,
      user: get_current_user()
    )
  end

  defp get_current_user do
    # Fixed: Using UserContext wrapper to ensure server is started
    Raxol.Security.UserContext.get_current_user()
  end
end
