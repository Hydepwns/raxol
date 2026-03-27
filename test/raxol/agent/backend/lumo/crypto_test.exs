defmodule Raxol.Agent.Backend.Lumo.CryptoTest do
  use ExUnit.Case, async: true

  alias Raxol.Agent.Backend.Lumo.Crypto

  describe "generate_request_key/0" do
    test "returns 32 bytes" do
      key = Crypto.generate_request_key()
      assert byte_size(key) == 32
    end

    test "returns unique keys" do
      key1 = Crypto.generate_request_key()
      key2 = Crypto.generate_request_key()
      assert key1 != key2
    end
  end

  describe "generate_request_id/0" do
    test "returns UUID v4 format" do
      id = Crypto.generate_request_id()
      assert Regex.match?(~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/, id)
    end

    test "returns unique IDs" do
      id1 = Crypto.generate_request_id()
      id2 = Crypto.generate_request_id()
      assert id1 != id2
    end
  end

  describe "encrypt/3 and decrypt/3" do
    test "round-trips plaintext without AD" do
      key = Crypto.generate_request_key()
      plaintext = "hello, lumo"

      encrypted = Crypto.encrypt(plaintext, key)
      assert {:ok, ^plaintext} = Crypto.decrypt(encrypted, key)
    end

    test "round-trips plaintext with AD" do
      key = Crypto.generate_request_key()
      plaintext = "secret message"
      ad = "lumo.request.test-id.turn"

      encrypted = Crypto.encrypt(plaintext, key, ad)
      assert {:ok, ^plaintext} = Crypto.decrypt(encrypted, key, ad)
    end

    test "decryption fails with wrong key" do
      key1 = Crypto.generate_request_key()
      key2 = Crypto.generate_request_key()
      plaintext = "hello"

      encrypted = Crypto.encrypt(plaintext, key1)
      assert {:error, :decryption_failed} = Crypto.decrypt(encrypted, key2)
    end

    test "decryption fails with wrong AD" do
      key = Crypto.generate_request_key()
      plaintext = "hello"

      encrypted = Crypto.encrypt(plaintext, key, "correct-ad")
      assert {:error, :decryption_failed} = Crypto.decrypt(encrypted, key, "wrong-ad")
    end

    test "encrypted output is base64" do
      key = Crypto.generate_request_key()
      encrypted = Crypto.encrypt("test", key)
      assert {:ok, _} = Base.decode64(encrypted)
    end

    test "encrypted output contains IV + ciphertext + tag" do
      key = Crypto.generate_request_key()
      plaintext = "hello"
      encrypted = Crypto.encrypt(plaintext, key)
      raw = Base.decode64!(encrypted)

      # 12 (IV) + 5 (ciphertext, same as plaintext for GCM) + 16 (tag) = 33
      assert byte_size(raw) == 12 + byte_size(plaintext) + 16
    end

    test "handles empty string" do
      key = Crypto.generate_request_key()
      encrypted = Crypto.encrypt("", key, "ad")
      assert {:ok, ""} = Crypto.decrypt(encrypted, key, "ad")
    end

    test "handles unicode content" do
      key = Crypto.generate_request_key()
      plaintext = "こんにちは Lumo 🔐"
      encrypted = Crypto.encrypt(plaintext, key)
      assert {:ok, ^plaintext} = Crypto.decrypt(encrypted, key)
    end
  end

  describe "encrypt_turn_content/3" do
    test "encrypts with correct AD pattern" do
      key = Crypto.generate_request_key()
      request_id = "abc-123"
      content = "what is the meaning of life?"

      encrypted = Crypto.encrypt_turn_content(content, key, request_id)

      # Decrypt manually with the expected AD
      ad = "lumo.request.abc-123.turn"
      assert {:ok, ^content} = Crypto.decrypt(encrypted, key, ad)
    end
  end

  describe "decrypt_chunk/3" do
    test "decrypts with correct AD pattern" do
      key = Crypto.generate_request_key()
      request_id = "def-456"

      # Simulate server encrypting a response chunk
      ad = "lumo.response.def-456.chunk"
      encrypted = Crypto.encrypt("response text", key, ad)

      assert {:ok, "response text"} = Crypto.decrypt_chunk(encrypted, key, request_id)
    end
  end

  describe "encrypt_request_key/1" do
    @tag :gpg
    @tag :unix_only
    test "encrypts a 32-byte key to PGP format" do
      if Crypto.gpg_available?() do
        key = Crypto.generate_request_key()
        assert {:ok, encrypted_b64} = Crypto.encrypt_request_key(key)
        assert {:ok, encrypted_raw} = Base.decode64(encrypted_b64)
        # PGP encrypted messages start with specific tag bytes
        # Tag 1 (PKESK) or tag 3 (SKESK), new format: 0xC1 or 0x84
        assert byte_size(encrypted_raw) > 32
      else
        IO.puts("Skipping GPG test (gpg not available)")
      end
    end
  end

  describe "gpg_available?/0" do
    test "returns a boolean" do
      result = Crypto.gpg_available?()
      assert is_boolean(result)
    end
  end

  describe "lumo_pub_key/0" do
    test "returns PGP public key block" do
      key = Crypto.lumo_pub_key()
      assert String.starts_with?(key, "-----BEGIN PGP PUBLIC KEY BLOCK-----")
      assert String.contains?(key, "-----END PGP PUBLIC KEY BLOCK-----")
    end
  end
end
