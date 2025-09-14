defmodule Raxol.Security.Encryption.KeyManagerTest do
  use ExUnit.Case, async: false
  alias Raxol.Security.Encryption.KeyManager

  setup do
    # Start Audit.Logger if not already running
    unless Process.whereis(Raxol.Audit.Logger) do
      {:ok, _audit_pid} = Raxol.Audit.Logger.start_link([])
    end

    # Start key manager for tests
    {:ok, _pid} =
      KeyManager.start_link(
        config: %{
          rotation_days: 1,
          cache_ttl_ms: 100,
          use_hsm: false
        }
      )

    on_exit(fn ->
      if Process.whereis(KeyManager) do
        GenServer.stop(KeyManager)
      end
      if Process.whereis(Raxol.Audit.Logger) do
        GenServer.stop(Raxol.Audit.Logger)
      end
    end)

    :ok
  end

  describe "generate_dek/3" do
    test "generates a new data encryption key" do
      {:ok, key} = KeyManager.generate_dek("test_purpose")

      assert key.id != nil
      assert key.version == 1
      assert key.type == :dek
      assert key.algorithm in [:aes_256_gcm, :aes_256_cbc, :chacha20_poly1305]
      # Should be sanitized
      refute Map.has_key?(key, :key_material)
      assert key.created_at != nil
      assert key.expires_at != nil
    end

    test "generates key with custom algorithm" do
      {:ok, key} =
        KeyManager.generate_dek("test", algorithm: :chacha20_poly1305)

      assert key.algorithm == :chacha20_poly1305
    end

    test "includes purpose in metadata" do
      {:ok, key} = KeyManager.generate_dek("payment_processing")
      assert key.metadata.purpose == "payment_processing"
    end
  end

  describe "get_key/3" do
    test "retrieves a key by ID" do
      {:ok, original} = KeyManager.generate_dek("test")
      {:ok, retrieved} = KeyManager.get_key(original.id)

      assert retrieved.id == original.id
      assert retrieved.version == original.version
      # Should have key material
      assert Map.has_key?(retrieved, :key_material)
    end

    test "retrieves latest version by default" do
      {:ok, key} = KeyManager.generate_dek("test")
      {:ok, _new_version} = KeyManager.rotate_key(key.id)

      {:ok, retrieved} = KeyManager.get_key(key.id, :latest)
      assert retrieved.version == 2
    end

    test "retrieves specific version" do
      {:ok, key} = KeyManager.generate_dek("test")
      {:ok, _new_version} = KeyManager.rotate_key(key.id)

      {:ok, retrieved} = KeyManager.get_key(key.id, 1)
      assert retrieved.version == 1
    end

    test "returns error for non-existent key" do
      result = KeyManager.get_key("non_existent")
      assert {:error, :key_not_found} = result
    end
  end

  describe "encrypt/4 and decrypt/5" do
    test "encrypts and decrypts data successfully" do
      {:ok, key} = KeyManager.generate_dek("test")
      plaintext = "Secret data to encrypt"

      {:ok, encrypted_package} = KeyManager.encrypt(key.id, plaintext)

      assert encrypted_package.key_id == key.id
      assert encrypted_package.key_version == 1
      assert encrypted_package.algorithm in [:aes_256_gcm, :chacha20_poly1305]
      assert Map.has_key?(encrypted_package.ciphertext, :ciphertext)

      {:ok, decrypted} = KeyManager.decrypt(key.id, encrypted_package, 1)
      assert decrypted == plaintext
    end

    test "encryption produces different ciphertext for same plaintext" do
      {:ok, key} = KeyManager.generate_dek("test")
      plaintext = "Same data"

      {:ok, encrypted1} = KeyManager.encrypt(key.id, plaintext)
      {:ok, encrypted2} = KeyManager.encrypt(key.id, plaintext)

      # Ciphertext should be different due to random IV
      assert encrypted1.ciphertext != encrypted2.ciphertext

      # But both should decrypt to same plaintext
      {:ok, decrypted1} = KeyManager.decrypt(key.id, encrypted1, 1)
      {:ok, decrypted2} = KeyManager.decrypt(key.id, encrypted2, 1)

      assert decrypted1 == plaintext
      assert decrypted2 == plaintext
    end

    test "handles binary data" do
      {:ok, key} = KeyManager.generate_dek("test")
      binary_data = :crypto.strong_rand_bytes(1024)

      {:ok, encrypted} = KeyManager.encrypt(key.id, binary_data)
      {:ok, decrypted} = KeyManager.decrypt(key.id, encrypted, 1)

      assert decrypted == binary_data
    end

    test "fails to decrypt with wrong key" do
      {:ok, key1} = KeyManager.generate_dek("test1")
      {:ok, key2} = KeyManager.generate_dek("test2")

      {:ok, encrypted} = KeyManager.encrypt(key1.id, "secret")

      # Try to decrypt with wrong key
      encrypted_with_wrong_key = %{encrypted | key_id: key2.id}
      result = KeyManager.decrypt(key2.id, encrypted_with_wrong_key, 1)

      assert {:error, :decryption_failed} = result
    end
  end

  describe "rotate_key/2" do
    test "creates a new version of a key" do
      {:ok, key} = KeyManager.generate_dek("test")
      {:ok, new_version} = KeyManager.rotate_key(key.id)

      assert new_version == 2

      # Can still retrieve both versions
      {:ok, v1} = KeyManager.get_key(key.id, 1)
      {:ok, v2} = KeyManager.get_key(key.id, 2)

      assert v1.version == 1
      assert v2.version == 2
      assert v1.key_material != v2.key_material
    end

    test "latest version is used for new encryptions" do
      {:ok, key} = KeyManager.generate_dek("test")
      {:ok, _} = KeyManager.rotate_key(key.id)

      {:ok, encrypted} = KeyManager.encrypt(key.id, "data")
      assert encrypted.key_version == 2
    end

    test "can still decrypt with old versions" do
      {:ok, key} = KeyManager.generate_dek("test")

      # Encrypt with version 1
      {:ok, encrypted_v1} = KeyManager.encrypt(key.id, "data v1")

      # Rotate key
      {:ok, _} = KeyManager.rotate_key(key.id)

      # Encrypt with version 2
      {:ok, encrypted_v2} = KeyManager.encrypt(key.id, "data v2")

      # Can decrypt both
      {:ok, decrypted_v1} = KeyManager.decrypt(key.id, encrypted_v1, 1)
      {:ok, decrypted_v2} = KeyManager.decrypt(key.id, encrypted_v2, 2)

      assert decrypted_v1 == "data v1"
      assert decrypted_v2 == "data v2"
    end
  end

  describe "reencrypt/4" do
    test "re-encrypts data with new key version" do
      {:ok, key} = KeyManager.generate_dek("test")
      plaintext = "data to reencrypt"

      # Encrypt with version 1
      {:ok, encrypted_v1} = KeyManager.encrypt(key.id, plaintext)
      assert encrypted_v1.key_version == 1

      # Rotate key
      {:ok, _} = KeyManager.rotate_key(key.id)

      # Re-encrypt with new version
      {:ok, encrypted_v2} = KeyManager.reencrypt(key.id, encrypted_v1, 1)
      assert encrypted_v2.key_version == 2

      # Decrypt and verify
      {:ok, decrypted} = KeyManager.decrypt(key.id, encrypted_v2, 2)
      assert decrypted == plaintext
    end
  end

  describe "wrap_key/3 and unwrap_key/3" do
    test "wraps and unwraps a DEK with a KEK" do
      {:ok, kek} = KeyManager.generate_dek("key_encryption_key")
      {:ok, dek} = KeyManager.generate_dek("data_key")

      # Need to get the actual key with material for wrapping
      {:ok, dek_with_material} = KeyManager.get_key(dek.id)

      {:ok, wrapped} = KeyManager.wrap_key(dek_with_material, kek.id)

      assert wrapped.kek_id == kek.id
      assert wrapped.kek_version == 1
      assert Map.has_key?(wrapped, :wrapped_key)
      assert wrapped.dek_metadata.id == dek.id

      {:ok, unwrapped} = KeyManager.unwrap_key(wrapped, kek.id)
      assert unwrapped.id == dek.id
      assert unwrapped.key_material == dek_with_material.key_material
    end
  end

  describe "get_key_metadata/2" do
    test "returns key metadata without key material" do
      {:ok, key} = KeyManager.generate_dek("test")
      {:ok, metadata} = KeyManager.get_key_metadata(key.id)

      assert metadata.key_id == key.id
      assert metadata.latest_version == 1
      assert metadata.status == :active
      assert is_list(metadata.versions)
    end
  end

  describe "list_keys/1" do
    test "lists all managed keys" do
      {:ok, key1} = KeyManager.generate_dek("test1")
      {:ok, key2} = KeyManager.generate_dek("test2")

      {:ok, keys} = KeyManager.list_keys()

      key_ids = Enum.map(keys, & &1.key_id)
      assert key1.id in key_ids
      assert key2.id in key_ids
    end
  end

  describe "delete_key/2" do
    test "marks a key as deleted" do
      {:ok, key} = KeyManager.generate_dek("test")

      :ok = KeyManager.delete_key(key.id)

      # Key should still be retrievable for decryption
      {:ok, _} = KeyManager.get_key(key.id)
    end
  end

  describe "caching" do
    test "caches retrieved keys" do
      {:ok, key} = KeyManager.generate_dek("test")

      # First retrieval - cache miss
      {:ok, _} = KeyManager.get_key(key.id)

      # Second retrieval should be from cache
      {:ok, _} = KeyManager.get_key(key.id)

      # Wait for cache to expire
      Process.sleep(150)

      # Should trigger cache miss again
      {:ok, _} = KeyManager.get_key(key.id)
    end
  end

  describe "automatic rotation" do
    test "checks for keys needing rotation" do
      {:ok, key} = KeyManager.generate_dek("test")

      # Simulate rotation check
      send(Process.whereis(KeyManager), :check_key_rotation)

      Process.sleep(100)

      # Key should not be rotated yet (just created)
      {:ok, retrieved} = KeyManager.get_key(key.id)
      assert retrieved.version == 1
    end
  end
end
