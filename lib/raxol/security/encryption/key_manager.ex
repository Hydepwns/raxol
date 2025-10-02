defmodule Raxol.Security.Encryption.KeyManager do
  @moduledoc """
  Manages encryption keys for at-rest data encryption.

  This module provides secure key generation, storage, rotation, and retrieval
  for encrypting sensitive data. It supports multiple encryption algorithms
  and key derivation functions.

  ## Features

  - Master key encryption with key derivation
  - Data encryption keys (DEK) with automatic rotation
  - Key encryption keys (KEK) for wrapping DEKs
  - Hardware Security Module (HSM) support
  - Key versioning and migration
  - Audit logging for all key operations
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Audit.Logger, as: AuditLogger
  alias Raxol.Core.Runtime.Log

  defstruct [
    :master_key,
    :key_store,
    :active_keys,
    :key_versions,
    :rotation_schedule,
    :config,
    :hsm_client,
    :cache,
    :metrics
  ]

  @type key_id :: String.t()
  @type key_version :: pos_integer()
  @type key_type :: :master | :kek | :dek | :signing | :hmac
  @type algorithm ::
          :aes_256_gcm | :aes_256_cbc | :chacha20_poly1305 | :aes_256_ctr

  @type encryption_key :: %{
          id: key_id(),
          version: key_version(),
          type: key_type(),
          algorithm: algorithm(),
          key_material: binary(),
          created_at: DateTime.t(),
          expires_at: DateTime.t() | nil,
          metadata: map()
        }

  @default_config %{
    algorithm: :aes_256_gcm,
    key_derivation: :pbkdf2,
    iterations: 100_000,
    rotation_days: 90,
    # 5 minutes
    cache_ttl_ms: 300_000,
    use_hsm: false,
    hsm_config: nil
  }

  ## Client API

  @doc """
  Generates a new data encryption key.
  """
  def generate_dek(key_manager \\ __MODULE__, purpose, opts \\ []) do
    GenServer.call(key_manager, {:generate_dek, purpose, opts})
  end

  @doc """
  Gets an encryption key by ID and version.
  """
  def get_key(key_id, version \\ :latest, key_manager \\ __MODULE__) do
    GenServer.call(key_manager, {:get_key, key_id, version})
  end

  @doc """
  Encrypts data using the specified key.
  """
  def encrypt(key_id, plaintext, opts \\ [], key_manager \\ __MODULE__) do
    GenServer.call(key_manager, {:encrypt, key_id, plaintext, opts})
  end

  @doc """
  Decrypts data using the specified key.
  """
  def decrypt(
        key_id,
        ciphertext,
        version,
        opts \\ [],
        key_manager \\ __MODULE__
      ) do
    GenServer.call(key_manager, {:decrypt, key_id, ciphertext, version, opts})
  end

  @doc """
  Rotates a key to a new version.
  """
  def rotate_key(key_id, key_manager \\ __MODULE__) do
    GenServer.call(key_manager, {:rotate_key, key_id})
  end

  @doc """
  Re-encrypts data with a new key version.
  """
  def reencrypt(key_manager \\ __MODULE__, key_id, ciphertext, old_version) do
    GenServer.call(key_manager, {:reencrypt, key_id, ciphertext, old_version})
  end

  @doc """
  Wraps a DEK with a KEK for secure storage.
  """
  def wrap_key(key_manager \\ __MODULE__, dek, kek_id) do
    GenServer.call(key_manager, {:wrap_key, dek, kek_id})
  end

  @doc """
  Unwraps a DEK using a KEK.
  """
  def unwrap_key(key_manager \\ __MODULE__, wrapped_dek, kek_id) do
    GenServer.call(key_manager, {:unwrap_key, wrapped_dek, kek_id})
  end

  @doc """
  Gets key metadata without the actual key material.
  """
  def get_key_metadata(key_manager \\ __MODULE__, key_id) do
    GenServer.call(key_manager, {:get_key_metadata, key_id})
  end

  @doc """
  Lists all managed keys (metadata only).
  """
  def list_keys(key_manager \\ __MODULE__) do
    GenServer.call(key_manager, :list_keys)
  end

  @doc """
  Deletes a key (marks as deleted, doesn't remove).
  """
  def delete_key(key_manager \\ __MODULE__, key_id) do
    GenServer.call(key_manager, {:delete_key, key_id})
  end

  ## BaseManager Implementation

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    base_config = Keyword.get(opts, :config, %{})
    config = Map.merge(@default_config, base_config)
    # Initialize master key
    master_key = init_master_key(config)

    # Initialize key store
    key_store = init_key_store(config)

    # Initialize HSM if configured
    hsm_client = initialize_hsm_if_configured(config.use_hsm, config.hsm_config)

    state = %__MODULE__{
      master_key: master_key,
      key_store: key_store,
      active_keys: %{},
      key_versions: %{},
      rotation_schedule: init_rotation_schedule(config),
      config: config,
      hsm_client: hsm_client,
      cache: %{},
      metrics: init_metrics()
    }

    # Load existing keys
    state = load_existing_keys(state)

    # Schedule key rotation checks
    # Daily
    _ = :timer.send_interval(86_400_000, :check_key_rotation)

    # Schedule cache cleanup
    # Every minute
    _ = :timer.send_interval(60_000, :cleanup_cache)

    Log.info("Key manager initialized")
    {:ok, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:generate_dek, purpose, opts}, _from, state) do
    {:ok, key, new_state} = generate_data_encryption_key(purpose, opts, state)
    audit_key_operation(:generate, key.id, purpose)
    {:reply, {:ok, key}, new_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:get_key, key_id, version}, _from, state) do
    case retrieve_key(key_id, version, state) do
      {:ok, key, new_state} ->
        audit_key_operation(:access, key_id, version)
        {:reply, {:ok, key}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:encrypt, key_id, plaintext, opts}, _from, state) do
    case perform_encryption(key_id, plaintext, opts, state) do
      {:ok, ciphertext, new_state} ->
        audit_key_operation(:encrypt, key_id, byte_size(plaintext))
        {:reply, {:ok, ciphertext}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:decrypt, key_id, ciphertext, version, opts},
        _from,
        state
      ) do
    case perform_decryption(key_id, ciphertext, version, opts, state) do
      {:ok, plaintext, new_state} ->
        audit_key_operation(:decrypt, key_id, version)
        {:reply, {:ok, plaintext}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:rotate_key, key_id}, _from, state) do
    case rotate_encryption_key(key_id, state) do
      {:ok, new_version, new_state} ->
        audit_key_operation(:rotate, key_id, new_version)
        {:reply, {:ok, new_version}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:reencrypt, key_id, ciphertext, old_version},
        _from,
        state
      ) do
    case reencrypt_data(key_id, ciphertext, old_version, state) do
      {:ok, new_ciphertext, new_state} ->
        audit_key_operation(:reencrypt, key_id, {old_version, :latest})
        {:reply, {:ok, new_ciphertext}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:wrap_key, dek, kek_id}, _from, state) do
    case wrap_data_key(dek, kek_id, state) do
      {:ok, wrapped_key, new_state} ->
        audit_key_operation(:wrap, kek_id, dek.id)
        {:reply, {:ok, wrapped_key}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:unwrap_key, wrapped_dek, kek_id}, _from, state) do
    case unwrap_data_key(wrapped_dek, kek_id, state) do
      {:ok, dek, new_state} ->
        audit_key_operation(:unwrap, kek_id, nil)
        {:reply, {:ok, dek}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:get_key_metadata, key_id}, _from, state) do
    metadata = get_metadata(key_id, state)
    {:reply, {:ok, metadata}, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:list_keys, _from, state) do
    keys = list_all_keys(state)
    {:reply, {:ok, keys}, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:delete_key, key_id}, _from, state) do
    {:ok, new_state} = mark_key_deleted(key_id, state)
    audit_key_operation(:delete, key_id, nil)
    {:reply, :ok, new_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info(:check_key_rotation, state) do
    new_state = check_and_rotate_keys(state)
    {:noreply, new_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info(:cleanup_cache, state) do
    new_state = cleanup_expired_cache(state)
    {:noreply, new_state}
  end

  ## Private Functions

  defp init_master_key(_config) do
    # In production, this would load from secure storage or HSM
    # For now, generate a new master key
    case System.get_env("RAXOL_MASTER_KEY") do
      nil ->
        # Generate new master key
        key = :crypto.strong_rand_bytes(32)

        Log.warning("Generated new master key - should be persisted securely!")

        key

      encoded_key ->
        # Decode from environment
        Base.decode64!(encoded_key)
    end
  end

  defp init_key_store(config) do
    # Initialize persistent key storage
    storage_path = Map.get(config, :key_store_path, "priv/data/keys")
    File.mkdir_p!(storage_path)

    %{
      path: storage_path,
      backend: Map.get(config, :storage_backend, :file)
    }
  end

  defp init_hsm_client(hsm_config) do
    # Initialize HSM connection
    # This would connect to actual HSM in production
    Log.info("HSM client initialized (simulated)")
    %{connected: true, config: hsm_config}
  end

  defp init_rotation_schedule(config) do
    %{
      rotation_days: config.rotation_days,
      last_check: DateTime.utc_now()
    }
  end

  defp init_metrics do
    %{
      keys_generated: 0,
      encryptions: 0,
      decryptions: 0,
      rotations: 0,
      cache_hits: 0,
      cache_misses: 0
    }
  end

  defp generate_data_encryption_key(purpose, opts, state) do
    key_id = generate_key_id(purpose)
    algorithm = Keyword.get(opts, :algorithm, state.config.algorithm)

    key_material = generate_key_by_source(state.hsm_client, algorithm)

    key = %{
      id: key_id,
      version: 1,
      type: :dek,
      algorithm: algorithm,
      key_material: key_material,
      created_at: DateTime.utc_now(),
      expires_at: calculate_expiry(state.config.rotation_days),
      metadata: %{
        purpose: purpose,
        created_by: get_current_user()
      }
    }

    # Wrap with KEK before storing
    wrapped_key = wrap_with_master_key(key, state)

    # Store wrapped key
    store_key(wrapped_key, state)

    # Update state
    new_state = %{
      state
      | active_keys: Map.put(state.active_keys, key_id, key),
        key_versions: Map.put(state.key_versions, key_id, [1])
    }

    {:ok, sanitize_key(key), new_state}
  end

  defp retrieve_key(key_id, version, state) do
    # Check cache first
    cache_key = {key_id, version}

    case Map.get(state.cache, cache_key) do
      nil ->
        # Cache miss - load from storage
        load_and_cache_key(key_id, version, state)

      {key, expiry} ->
        # Check if cache entry is still valid
        handle_cache_entry_validity(expiry, key, state, key_id, version)

      _ ->
        # Invalid cache entry
        load_and_cache_key(key_id, version, state)
    end
  end

  defp perform_encryption(key_id, plaintext, opts, state) do
    with {:ok, key, new_state} <- retrieve_key(key_id, :latest, state),
         {:ok, ciphertext} <- encrypt_data(plaintext, key, opts) do
      encrypted_package = %{
        version: 1,
        key_id: key_id,
        key_version: key.version,
        algorithm: key.algorithm,
        ciphertext: ciphertext,
        timestamp: System.system_time(:millisecond)
      }

      new_metrics = Map.update!(new_state.metrics, :encryptions, &(&1 + 1))
      {:ok, encrypted_package, %{new_state | metrics: new_metrics}}
    end
  end

  defp perform_decryption(key_id, encrypted_package, version, opts, state) do
    actual_version = version || encrypted_package.key_version

    with {:ok, key, new_state} <- retrieve_key(key_id, actual_version, state),
         {:ok, plaintext} <-
           decrypt_data(encrypted_package.ciphertext, key, opts) do
      new_metrics = Map.update!(new_state.metrics, :decryptions, &(&1 + 1))
      {:ok, plaintext, %{new_state | metrics: new_metrics}}
    end
  end

  defp encrypt_data(plaintext, key, _opts) do
    case key.algorithm do
      :aes_256_gcm ->
        iv = :crypto.strong_rand_bytes(16)

        {ciphertext, tag} =
          :crypto.crypto_one_time_aead(
            :aes_256_gcm,
            key.key_material,
            iv,
            plaintext,
            "",
            true
          )

        {:ok, %{iv: iv, ciphertext: ciphertext, tag: tag}}

      :chacha20_poly1305 ->
        nonce = :crypto.strong_rand_bytes(12)

        {ciphertext, tag} =
          :crypto.crypto_one_time_aead(
            :chacha20_poly1305,
            key.key_material,
            nonce,
            plaintext,
            "",
            true
          )

        {:ok, %{nonce: nonce, ciphertext: ciphertext, tag: tag}}

      algorithm ->
        {:error, {:unsupported_algorithm, algorithm}}
    end
  end

  defp decrypt_data(encrypted_data, key, _opts) do
    case key.algorithm do
      :aes_256_gcm ->
        case :crypto.crypto_one_time_aead(
               :aes_256_gcm,
               key.key_material,
               encrypted_data.iv,
               encrypted_data.ciphertext,
               "",
               encrypted_data.tag,
               false
             ) do
          plaintext when is_binary(plaintext) -> {:ok, plaintext}
          :error -> {:error, :decryption_failed}
        end

      :chacha20_poly1305 ->
        case :crypto.crypto_one_time_aead(
               :chacha20_poly1305,
               key.key_material,
               encrypted_data.nonce,
               encrypted_data.ciphertext,
               "",
               encrypted_data.tag,
               false
             ) do
          plaintext when is_binary(plaintext) -> {:ok, plaintext}
          :error -> {:error, :decryption_failed}
        end

      algorithm ->
        {:error, {:unsupported_algorithm, algorithm}}
    end
  end

  defp rotate_encryption_key(key_id, state) do
    case Map.get(state.active_keys, key_id) do
      nil ->
        {:error, :key_not_found}

      current_key ->
        # Generate new key version
        new_version = current_key.version + 1
        new_key_material = generate_key_material(current_key.algorithm)

        new_key = %{
          current_key
          | version: new_version,
            key_material: new_key_material,
            created_at: DateTime.utc_now(),
            expires_at: calculate_expiry(state.config.rotation_days)
        }

        # Store new version
        wrapped_key = wrap_with_master_key(new_key, state)
        store_key_version(wrapped_key, state)

        # Update state
        versions = Map.get(state.key_versions, key_id, [])

        new_state = %{
          state
          | active_keys: Map.put(state.active_keys, key_id, new_key),
            key_versions:
              Map.put(state.key_versions, key_id, [new_version | versions]),
            metrics: Map.update!(state.metrics, :rotations, &(&1 + 1))
        }

        {:ok, new_version, new_state}
    end
  end

  defp reencrypt_data(key_id, encrypted_package, old_version, state) do
    with {:ok, old_key, state} <- retrieve_key(key_id, old_version, state),
         {:ok, plaintext} <-
           decrypt_data(encrypted_package.ciphertext, old_key, []),
         {:ok, new_key, state} <- retrieve_key(key_id, :latest, state),
         {:ok, new_ciphertext} <- encrypt_data(plaintext, new_key, []) do
      new_package =
        encrypted_package
        |> Map.put(:key_version, new_key.version)
        |> Map.put(:ciphertext, new_ciphertext)
        |> Map.put(:reencrypted_at, System.system_time(:millisecond))

      {:ok, new_package, state}
    end
  end

  defp wrap_data_key(dek, kek_id, state) do
    with {:ok, kek, new_state} <- retrieve_key(kek_id, :latest, state) do
      # Use AES-KW (Key Wrap) algorithm
      wrapped = wrap_key_material(dek.key_material, kek.key_material)

      wrapped_key = %{
        wrapped_key: wrapped,
        kek_id: kek_id,
        kek_version: kek.version,
        dek_metadata: sanitize_key(dek)
      }

      {:ok, wrapped_key, new_state}
    end
  end

  defp unwrap_data_key(wrapped_key_data, kek_id, state) do
    with {:ok, kek, new_state} <-
           retrieve_key(kek_id, wrapped_key_data.kek_version, state) do
      # Unwrap using AES-KW
      key_material =
        unwrap_key_material(wrapped_key_data.wrapped_key, kek.key_material)

      dek = Map.put(wrapped_key_data.dek_metadata, :key_material, key_material)

      {:ok, dek, new_state}
    end
  end

  defp wrap_key_material(key_material, kek) do
    # Simplified AES key wrapping
    # In production, use proper AES-KW (RFC 3394)
    iv = :crypto.strong_rand_bytes(16)

    encrypted =
      :crypto.crypto_one_time(:aes_256_cbc, kek, iv, key_material, true)

    %{iv: iv, wrapped: encrypted}
  end

  defp unwrap_key_material(wrapped_data, kek) do
    :crypto.crypto_one_time(
      :aes_256_cbc,
      kek,
      wrapped_data.iv,
      wrapped_data.wrapped,
      false
    )
  end

  defp wrap_with_master_key(key, state) do
    wrapped_material = wrap_key_material(key.key_material, state.master_key)
    %{key | key_material: wrapped_material}
  end

  defp generate_key_material(:aes_256_gcm), do: :crypto.strong_rand_bytes(32)
  defp generate_key_material(:aes_256_cbc), do: :crypto.strong_rand_bytes(32)

  defp generate_key_material(:chacha20_poly1305),
    do: :crypto.strong_rand_bytes(32)

  defp generate_key_material(:aes_256_ctr), do: :crypto.strong_rand_bytes(32)

  defp generate_key_in_hsm(algorithm, _hsm_client) do
    # Simulate HSM key generation
    Log.debug("Generating #{algorithm} key in HSM")
    :crypto.strong_rand_bytes(32)
  end

  defp generate_key_id(purpose) do
    timestamp = System.system_time(:millisecond)
    random = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    "#{purpose}_#{timestamp}_#{random}"
  end

  defp calculate_expiry(days) do
    DateTime.utc_now()
    |> DateTime.add(days * 86_400, :second)
  end

  defp get_current_user do
    # Get from user context (ensures server is started)
    Raxol.Security.UserContext.get_current_user() || "system"
  end

  defp sanitize_key(key) do
    # Remove key material from external representation
    Map.delete(key, :key_material)
  end

  defp store_key(wrapped_key, state) do
    file_path =
      Path.join(
        state.key_store.path,
        "#{wrapped_key.id}_v#{wrapped_key.version}.key"
      )

    encrypted_content = :erlang.term_to_binary(wrapped_key)
    File.write!(file_path, encrypted_content)
  end

  defp store_key_version(wrapped_key, state) do
    store_key(wrapped_key, state)
  end

  defp load_and_cache_key(key_id, version, state) do
    actual_version = resolve_key_version(version, key_id, state)

    file_path =
      Path.join(state.key_store.path, "#{key_id}_v#{actual_version}.key")

    case File.read(file_path) do
      {:ok, content} ->
        wrapped_key = :erlang.binary_to_term(content)
        # Unwrap with master key
        key_material =
          unwrap_key_material(wrapped_key.key_material, state.master_key)

        key = %{wrapped_key | key_material: key_material}

        # Cache the key
        cache_entry =
          {key, System.system_time(:millisecond) + state.config.cache_ttl_ms}

        new_cache = Map.put(state.cache, {key_id, actual_version}, cache_entry)

        new_metrics = Map.update!(state.metrics, :cache_misses, &(&1 + 1))
        new_state = %{state | cache: new_cache, metrics: new_metrics}

        {:ok, key, new_state}

      {:error, _} ->
        {:error, :key_not_found}
    end
  end

  defp load_existing_keys(state) do
    # Load key metadata from storage
    pattern = Path.join(state.key_store.path, "*.key")

    files = Path.wildcard(pattern)

    Enum.reduce(files, state, fn file, acc_state ->
      case extract_key_info(file) do
        {key_id, version} ->
          versions = Map.get(acc_state.key_versions, key_id, [])

          %{
            acc_state
            | key_versions:
                Map.put(acc_state.key_versions, key_id, [version | versions])
          }

        _ ->
          acc_state
      end
    end)
  end

  defp extract_key_info(file_path) do
    basename = Path.basename(file_path, ".key")

    case String.split(basename, "_v") do
      [key_id, version_str] ->
        {key_id, String.to_integer(version_str)}

      _ ->
        nil
    end
  end

  defp check_and_rotate_keys(state) do
    now = DateTime.utc_now()

    Enum.reduce(state.active_keys, state, fn {key_id, key}, acc_state ->
      process_key_rotation(
        should_rotate?(key, now, acc_state.config.rotation_days),
        key_id,
        acc_state
      )
    end)
  end

  defp should_rotate?(key, now, _rotation_days) do
    case key.expires_at do
      nil ->
        false

      expires_at ->
        DateTime.compare(now, expires_at) == :gt
    end
  end

  defp cleanup_expired_cache(state) do
    now = System.system_time(:millisecond)

    new_cache =
      state.cache
      |> Enum.filter(fn {_key, {_data, expiry}} -> expiry > now end)
      |> Enum.into(%{})

    %{state | cache: new_cache}
  end

  defp get_metadata(key_id, state) do
    versions = Map.get(state.key_versions, key_id, [])

    %{
      key_id: key_id,
      versions: versions,
      latest_version: List.first(versions),
      created_at: get_key_creation_time(key_id, state),
      status: :active
    }
  end

  defp get_key_creation_time(_key_id, _state) do
    # Extract from file timestamp or stored metadata
    DateTime.utc_now()
  end

  defp list_all_keys(state) do
    state.key_versions
    |> Map.keys()
    |> Enum.map(&get_metadata(&1, state))
  end

  defp mark_key_deleted(key_id, state) do
    # Don't actually delete, just mark as deleted
    new_active = Map.delete(state.active_keys, key_id)
    {:ok, %{state | active_keys: new_active}}
  end

  defp audit_key_operation(operation, key_id, details) do
    if Process.whereis(AuditLogger) do
      AuditLogger.log_security_event(
        :key_operation,
        :info,
        "Key operation: #{operation}",
        key_id: key_id,
        operation: operation,
        details: details,
        user: get_current_user()
      )
    else
      Log.debug("Audit logging skipped - audit logger not available",
        operation: operation,
        key_id: key_id
      )
    end
  end

  # Helper functions for if statement elimination

  defp initialize_hsm_if_configured(false, _config), do: nil

  defp initialize_hsm_if_configured(true, hsm_config),
    do: init_hsm_client(hsm_config)

  defp generate_key_by_source(nil, algorithm),
    do: generate_key_material(algorithm)

  defp generate_key_by_source(hsm_client, algorithm),
    do: generate_key_in_hsm(algorithm, hsm_client)

  defp handle_cache_entry_validity(expiry, key, state, key_id, version) do
    current_time = :erlang.system_time(:millisecond)
    process_cache_validity(expiry > current_time, key, state, key_id, version)
  end

  defp process_cache_validity(true, key, state, _key_id, _version) do
    # Cache hit
    new_metrics = Map.update!(state.metrics, :cache_hits, &(&1 + 1))
    {:ok, key, %{state | metrics: new_metrics}}
  end

  defp process_cache_validity(false, _key, state, key_id, version) do
    # Expired cache entry
    load_and_cache_key(key_id, version, state)
  end

  defp resolve_key_version(:latest, key_id, state) do
    Map.get(state.key_versions, key_id, [1]) |> hd()
  end

  defp resolve_key_version(version, _key_id, _state), do: version

  defp process_key_rotation(false, _key_id, acc_state), do: acc_state

  defp process_key_rotation(true, key_id, acc_state) do
    case rotate_encryption_key(key_id, acc_state) do
      {:ok, _new_version, new_state} ->
        Log.info("Automatically rotated key #{key_id}")
        new_state

      {:error, reason} ->
        Log.error("Failed to rotate key #{key_id}: #{inspect(reason)}")
        acc_state
    end
  end
end
