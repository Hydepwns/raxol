defmodule Raxol.Crypto do
  @moduledoc """
  Cryptographic utilities for Raxol.

  Provides encryption, decryption, and key derivation functions
  using industry-standard algorithms.

  ## Example

      key = Raxol.Crypto.derive_key(password, salt, iterations: 100_000)
      encrypted = Raxol.Crypto.encrypt(plaintext, key)
      decrypted = Raxol.Crypto.decrypt(encrypted, key)
  """

  @iv_size 16
  @tag_size 16

  @doc """
  Encrypt plaintext using AES-256-GCM.

  ## Example

      encrypted = Raxol.Crypto.encrypt("secret data", key)
  """
  @spec encrypt(binary(), binary()) :: binary()
  def encrypt(plaintext, key)
      when is_binary(plaintext) and byte_size(key) == 32 do
    iv = :crypto.strong_rand_bytes(@iv_size)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(
        :aes_256_gcm,
        key,
        iv,
        plaintext,
        <<>>,
        @tag_size,
        true
      )

    iv <> tag <> ciphertext
  end

  def encrypt(plaintext, key) when is_binary(plaintext) do
    # Derive a proper key if the provided one isn't the right size
    proper_key = derive_key(key, "raxol_salt", length: 32)
    encrypt(plaintext, proper_key)
  end

  @doc """
  Decrypt ciphertext encrypted with AES-256-GCM.

  ## Example

      {:ok, plaintext} = Raxol.Crypto.decrypt(encrypted, key)
  """
  @spec decrypt(binary(), binary()) ::
          {:ok, binary()} | {:error, :decryption_failed}
  def decrypt(ciphertext, key)
      when is_binary(ciphertext) and byte_size(key) == 32 and
             byte_size(ciphertext) > @iv_size + @tag_size do
    <<iv::binary-size(@iv_size), tag::binary-size(@tag_size),
      encrypted::binary>> = ciphertext

    case :crypto.crypto_one_time_aead(
           :aes_256_gcm,
           key,
           iv,
           encrypted,
           <<>>,
           tag,
           false
         ) do
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
      :error -> {:error, :decryption_failed}
    end
  end

  def decrypt(ciphertext, key) when is_binary(ciphertext) and is_binary(key) do
    proper_key = derive_key(key, "raxol_salt", length: 32)
    decrypt(ciphertext, proper_key)
  end

  def decrypt(_, _), do: {:error, :decryption_failed}

  @doc """
  Derive a cryptographic key from a password using PBKDF2.

  ## Options

    - `:iterations` - Number of PBKDF2 iterations (default: 100_000)
    - `:length` - Output key length in bytes (default: 32)
    - `:hash` - Hash algorithm (default: :sha256)

  ## Example

      key = Raxol.Crypto.derive_key(password, salt,
        iterations: 100_000,
        length: 32
      )
  """
  @spec derive_key(binary(), binary(), keyword()) :: binary()
  def derive_key(password, salt, opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 100_000)
    length = Keyword.get(opts, :length, 32)
    hash = Keyword.get(opts, :hash, :sha256)

    :crypto.pbkdf2_hmac(hash, password, salt, iterations, length)
  end

  @doc """
  Generate a random key of the specified length.

  ## Example

      key = Raxol.Crypto.generate_key(32)
  """
  @spec generate_key(pos_integer()) :: binary()
  def generate_key(length \\ 32) do
    :crypto.strong_rand_bytes(length)
  end

  @doc """
  Hash data using SHA-256.

  ## Example

      hash = Raxol.Crypto.hash("data to hash")
  """
  @spec hash(binary()) :: binary()
  def hash(data) when is_binary(data) do
    :crypto.hash(:sha256, data)
  end

  @doc """
  Generate a secure random token.

  ## Example

      token = Raxol.Crypto.random_token(32)
  """
  @spec random_token(pos_integer()) :: String.t()
  def random_token(length \\ 32) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, length)
  end

  @doc """
  Securely compare two binaries in constant time.

  Prevents timing attacks when comparing secrets.
  """
  @spec secure_compare(binary(), binary()) :: boolean()
  def secure_compare(a, b) when is_binary(a) and is_binary(b) do
    byte_size(a) == byte_size(b) and :crypto.hash_equals(a, b)
  end

  def secure_compare(_, _), do: false
end
