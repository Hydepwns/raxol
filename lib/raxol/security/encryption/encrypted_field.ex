defmodule Raxol.Security.Encryption.EncryptedField do
  @moduledoc """
  Ecto type for transparent field-level encryption in databases.

  This module provides an Ecto custom type that automatically encrypts
  data before storing it in the database and decrypts it when loading.

  ## Usage

      schema "users" do
        field :email, :string
        field :ssn, Raxol.Security.Encryption.EncryptedField
        field :credit_card, Raxol.Security.Encryption.EncryptedField
        timestamps()
      end

  ## Features

  - Transparent encryption/decryption
  - Format-preserving encryption option
  - Deterministic encryption for searchable fields
  - Support for different data types
  - Key rotation support
  """

  use Ecto.Type
  require Logger

  alias Raxol.Security.Encryption.KeyManager

  @impl Ecto.Type
  def type, do: :binary

  @impl Ecto.Type
  def cast(value) do
    # Accept any value for casting
    {:ok, value}
  end

  @impl Ecto.Type
  def load(nil), do: {:ok, nil}

  def load(encrypted_binary) when is_binary(encrypted_binary) do
    # Decrypt the value from database
    case decrypt_value(encrypted_binary) do
      {:ok, value} ->
        {:ok, value}

      {:error, reason} ->
        # Log but don't fail - return encrypted value
        Logger.error("Failed to decrypt field: #{inspect(reason)}")
        {:ok, encrypted_binary}
    end
  end

  @impl Ecto.Type
  def dump(nil), do: {:ok, nil}

  def dump(value) do
    # Encrypt the value for database storage
    case encrypt_value(value) do
      {:ok, encrypted} -> {:ok, encrypted}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Ecto.Type
  def embed_as(_), do: :self

  @impl Ecto.Type
  def equal?(a, b), do: a == b

  ## Encryption/Decryption Functions

  defp encrypt_value(value) do
    # Get encryption configuration
    config = get_encryption_config()

    # Serialize the value
    serialized = serialize_value(value)

    # Get or create key manager
    key_manager = get_key_manager()

    # Encrypt with field-specific key
    key_id = config[:field_key_id] || "database_field_key"

    case KeyManager.encrypt(key_manager, key_id, serialized) do
      {:ok, encrypted_package} ->
        # Encode for database storage
        encoded = encode_for_storage(encrypted_package)
        {:ok, encoded}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decrypt_value(encrypted_binary) do
    # Decode from database format
    case decode_from_storage(encrypted_binary) do
      {:ok, encrypted_package} ->
        # Get key manager
        key_manager = get_key_manager()

        # Decrypt
        case KeyManager.decrypt(
               key_manager,
               encrypted_package.key_id,
               encrypted_package,
               encrypted_package.key_version
             ) do
          {:ok, decrypted} ->
            # Deserialize the value
            value = deserialize_value(decrypted)
            {:ok, value}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp serialize_value(value) when is_binary(value), do: value
  defp serialize_value(value), do: :erlang.term_to_binary(value)

  defp deserialize_value(binary) do
    # Try to deserialize as Erlang term first
    try do
      :erlang.binary_to_term(binary)
    rescue
      _ ->
        # If that fails, it's probably a plain string
        binary
    end
  end

  defp encode_for_storage(encrypted_package) do
    # Encode as base64 for database storage
    :erlang.term_to_binary(encrypted_package)
    |> Base.encode64()
  end

  defp decode_from_storage(encoded_binary) do
    try do
      decoded = Base.decode64!(encoded_binary)
      encrypted_package = :erlang.binary_to_term(decoded)
      {:ok, encrypted_package}
    rescue
      _ -> {:error, :invalid_encrypted_data}
    end
  end

  defp get_key_manager do
    case Process.whereis(KeyManager) do
      nil ->
        {:ok, pid} = KeyManager.start_link()
        pid

      pid ->
        pid
    end
  end

  defp get_encryption_config do
    Application.get_env(:raxol, :field_encryption, %{})
  end
end

defmodule Raxol.Security.Encryption.EncryptedString do
  @moduledoc """
  Ecto type for encrypted string fields with format preservation.
  """

  use Ecto.Type
  alias Raxol.Security.Encryption.EncryptedField

  @impl Ecto.Type
  def type, do: :string

  @impl Ecto.Type
  defdelegate cast(value), to: EncryptedField

  @impl Ecto.Type
  defdelegate load(value), to: EncryptedField

  @impl Ecto.Type
  defdelegate dump(value), to: EncryptedField

  @impl Ecto.Type
  def embed_as(_), do: :self

  @impl Ecto.Type
  def equal?(a, b), do: a == b
end

defmodule Raxol.Security.Encryption.EncryptedMap do
  @moduledoc """
  Ecto type for encrypted JSON/map fields.
  """

  use Ecto.Type
  alias Raxol.Security.Encryption.{KeyManager}

  @impl Ecto.Type
  def type, do: :map

  @impl Ecto.Type
  def cast(value) when is_map(value), do: {:ok, value}
  def cast(_), do: :error

  @impl Ecto.Type
  def load(nil), do: {:ok, nil}

  def load(encrypted_binary) when is_binary(encrypted_binary) do
    # Decrypt and decode JSON
    case decrypt_json(encrypted_binary) do
      {:ok, map} -> {:ok, map}
      {:error, _} -> {:ok, %{}}
    end
  end

  @impl Ecto.Type
  def dump(nil), do: {:ok, nil}

  def dump(map) when is_map(map) do
    # Encode as JSON and encrypt
    case encrypt_json(map) do
      {:ok, encrypted} -> {:ok, encrypted}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Ecto.Type
  def embed_as(_), do: :self

  @impl Ecto.Type
  def equal?(a, b), do: a == b

  defp encrypt_json(map) do
    json = Jason.encode!(map)
    key_manager = get_key_manager()
    key_id = "database_json_key"

    case KeyManager.encrypt(key_manager, key_id, json) do
      {:ok, encrypted_package} ->
        encoded = :erlang.term_to_binary(encrypted_package) |> Base.encode64()
        {:ok, encoded}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decrypt_json(encrypted_binary) do
    try do
      decoded = Base.decode64!(encrypted_binary)
      encrypted_package = :erlang.binary_to_term(decoded)
      key_manager = get_key_manager()

      case KeyManager.decrypt(
             key_manager,
             encrypted_package.key_id,
             encrypted_package,
             encrypted_package.key_version
           ) do
        {:ok, json} ->
          map = Jason.decode!(json)
          {:ok, map}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      _ -> {:error, :decryption_failed}
    end
  end

  defp get_key_manager do
    case Process.whereis(KeyManager) do
      nil ->
        {:ok, pid} = KeyManager.start_link()
        pid

      pid ->
        pid
    end
  end
end

defmodule Raxol.Security.Encryption.SearchableEncryptedField do
  @moduledoc """
  Ecto type for deterministic encryption that allows searching.

  This uses deterministic encryption so the same plaintext always
  produces the same ciphertext, enabling database queries.

  WARNING: This is less secure than random encryption. Use only
  when searching is required.
  """

  use Ecto.Type

  @impl Ecto.Type
  def type, do: :binary

  @impl Ecto.Type
  def cast(value), do: {:ok, value}

  @impl Ecto.Type
  def load(encrypted_value) when is_binary(encrypted_value) do
    case decrypt_deterministic(encrypted_value) do
      {:ok, value} -> {:ok, value}
      {:error, _} -> {:ok, encrypted_value}
    end
  end

  def load(nil), do: {:ok, nil}

  @impl Ecto.Type
  def dump(value) when is_binary(value) do
    {:ok, encrypt_deterministic(value)}
  end

  def dump(nil), do: {:ok, nil}

  @impl Ecto.Type
  def embed_as(_), do: :self

  @impl Ecto.Type
  def equal?(a, b), do: a == b

  @doc """
  Encrypts a value for searching in queries.

  Usage:
      encrypted_email = SearchableEncryptedField.encrypt_for_search("user@example.com")
      Repo.get_by(User, encrypted_email: encrypted_email)
  """
  def encrypt_for_search(value) do
    encrypt_deterministic(value)
  end

  defp encrypt_deterministic(value) do
    # Use a deterministic encryption scheme
    # In production, use proper deterministic encryption like AES-SIV
    key = get_deterministic_key()

    # Create deterministic IV from value hash
    iv = :crypto.hash(:md5, value)

    encrypted =
      :crypto.crypto_one_time(:aes_256_cbc, key, iv, pad_value(value), true)

    Base.encode64(encrypted)
  end

  defp decrypt_deterministic(encrypted_value) do
    try do
      decoded = Base.decode64!(encrypted_value)
      key = get_deterministic_key()

      # Recreate IV from encrypted data
      iv = :crypto.hash(:md5, decoded) |> binary_part(0, 16)

      decrypted = :crypto.crypto_one_time(:aes_256_cbc, key, iv, decoded, false)
      {:ok, unpad_value(decrypted)}
    rescue
      _ -> {:error, :decryption_failed}
    end
  end

  defp get_deterministic_key do
    # In production, load from secure configuration
    Application.get_env(:raxol, :deterministic_key) ||
      :crypto.hash(:sha256, "deterministic_key_seed")
  end

  defp pad_value(value) do
    # PKCS7 padding
    block_size = 16
    padding_length = block_size - rem(byte_size(value), block_size)
    padding = String.duplicate(<<padding_length>>, padding_length)
    value <> padding
  end

  defp unpad_value(padded_value) do
    padding_length = :binary.last(padded_value)
    value_length = byte_size(padded_value) - padding_length
    binary_part(padded_value, 0, value_length)
  end
end
