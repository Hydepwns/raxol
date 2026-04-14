defmodule Raxol.Payments.Wallets.Env do
  @moduledoc """
  Wallet that loads a private key from an environment variable.

  The key must be hex-encoded (with or without 0x prefix). The address
  is derived from the public key at module load time.

  ## Configuration

      # Set the env var
      export RAXOL_WALLET_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

      # Use in agent config
      wallet = Raxol.Payments.Wallets.Env

  ## Custom Env Var

      # Override at compile time
      defmodule MyWallet do
        use Raxol.Payments.Wallets.Env, env_var: "MY_WALLET_KEY"
      end
  """

  @behaviour Raxol.Payments.Wallet

  @default_env_var "RAXOL_WALLET_KEY"
  @default_chain_id 8453

  defmacro __using__(opts) do
    env_var = Keyword.get(opts, :env_var, @default_env_var)
    chain = Keyword.get(opts, :chain_id, @default_chain_id)

    quote do
      @behaviour Raxol.Payments.Wallet

      @impl true
      def address do
        Raxol.Payments.Wallets.Env.address(unquote(env_var))
      end

      @impl true
      def chain_id, do: unquote(chain)

      @impl true
      def sign_message(message) do
        Raxol.Payments.Wallets.Env.sign_message(message, unquote(env_var))
      end

      @impl true
      def sign_typed_data(domain, types, message) do
        Raxol.Payments.Wallets.Env.sign_typed_data(domain, types, message, unquote(env_var))
      end
    end
  end

  @impl true
  def address, do: address(@default_env_var)

  @impl true
  def chain_id, do: @default_chain_id

  @impl true
  def sign_message(message), do: sign_message(message, @default_env_var)

  @impl true
  def sign_typed_data(domain, types, message) do
    sign_typed_data(domain, types, message, @default_env_var)
  end

  @doc false
  @spec address(String.t()) :: String.t()
  def address(env_var) do
    with {:ok, privkey} <- load_key(env_var),
         {:ok, pubkey} <- ExSecp256k1.create_public_key(privkey) do
      derive_address(pubkey)
    else
      {:error, reason} -> raise "Failed to derive address: #{inspect(reason)}"
    end
  end

  @doc false
  @spec sign_message(binary(), String.t()) :: {:ok, binary()} | {:error, term()}
  def sign_message(message, env_var) do
    with {:ok, privkey} <- load_key(env_var) do
      hash = ExKeccak.hash_256(message)

      case ExSecp256k1.sign(hash, privkey) do
        {:ok, {r, s, v}} ->
          {:ok, <<r::binary-size(32), s::binary-size(32), v::8>>}

        {:error, reason} ->
          {:error, {:sign_failed, reason}}
      end
    end
  end

  @doc false
  @spec sign_typed_data(map(), map(), map(), String.t()) ::
          {:ok, binary()} | {:error, term()}
  def sign_typed_data(domain, types, message, env_var) do
    with {:ok, privkey} <- load_key(env_var),
         {:ok, hash} <- eip712_hash(domain, types, message) do
      case ExSecp256k1.sign(hash, privkey) do
        {:ok, {r, s, v}} ->
          {:ok, <<r::binary-size(32), s::binary-size(32), v::8>>}

        {:error, reason} ->
          {:error, {:sign_failed, reason}}
      end
    end
  end

  # -- Private --

  defp load_key(env_var) do
    case System.get_env(env_var) do
      nil ->
        {:error, {:env_not_set, env_var}}

      hex_key ->
        hex_key
        |> String.trim_leading("0x")
        |> Base.decode16(case: :mixed)
        |> case do
          {:ok, key} when byte_size(key) == 32 -> {:ok, key}
          {:ok, key} -> {:error, {:invalid_key_length, byte_size(key)}}
          :error -> {:error, :invalid_hex}
        end
    end
  end

  defp derive_address(pubkey) do
    # Drop the 04 prefix byte (uncompressed public key marker)
    <<_prefix::8, key_bytes::binary>> = pubkey
    <<_first_12::binary-size(12), address_bytes::binary-size(20)>> = ExKeccak.hash_256(key_bytes)
    "0x" <> Base.encode16(address_bytes, case: :lower)
  end

  @doc false
  @spec eip712_hash(map(), map(), map()) :: {:ok, binary()} | {:error, term()}
  def eip712_hash(domain, types, message) do
    with {:ok, domain_separator} <-
           hash_struct("EIP712Domain", domain, eip712_domain_types(domain)),
         {:ok, message_hash} <- hash_struct(primary_type(types), message, types) do
      {:ok, ExKeccak.hash_256(<<0x19, 0x01, domain_separator::binary, message_hash::binary>>)}
    end
  end

  defp eip712_domain_types(domain) do
    fields =
      [
        if(Map.has_key?(domain, :name), do: {"name", "string"}),
        if(Map.has_key?(domain, :version), do: {"version", "string"}),
        if(Map.has_key?(domain, :chainId) || Map.has_key?(domain, :chain_id),
          do: {"chainId", "uint256"}
        ),
        if(Map.has_key?(domain, :verifyingContract) || Map.has_key?(domain, :verifying_contract),
          do: {"verifyingContract", "address"}
        )
      ]
      |> Enum.reject(&is_nil/1)

    %{"EIP712Domain" => fields}
  end

  defp primary_type(types) do
    types
    |> Map.keys()
    |> List.first()
  end

  # EIP-712: hashStruct(s) = keccak256(typeHash || encodeData(s))
  # where typeHash = keccak256(encodeType(s)) and encodeType returns the string.
  defp hash_struct(type_name, data, types) do
    type_hash = encode_type(type_name, types)

    case encode_data(type_name, data, types) do
      {:error, _} = err -> err
      encoded_data -> {:ok, ExKeccak.hash_256(<<type_hash::binary, encoded_data::binary>>)}
    end
  end

  defp encode_type(type_name, types) do
    fields = Map.get(types, type_name, [])

    type_string =
      type_name <>
        "(" <>
        (fields
         |> Enum.map(fn {name, type} -> "#{type} #{name}" end)
         |> Enum.join(",")) <>
        ")"

    ExKeccak.hash_256(type_string)
  end

  defp encode_data(type_name, data, types) do
    fields = Map.get(types, type_name, [])

    fields
    |> Enum.reduce_while(<<>>, fn {name, type}, acc ->
      value = Map.get(data, name) || safe_atom_get(data, name)

      case encode_value(type, value) do
        {:ok, encoded} -> {:cont, <<acc::binary, encoded::binary>>}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  # Look up a string key as an existing atom. Returns nil if the atom
  # doesn't exist, avoiding atom table exhaustion from external input.
  defp safe_atom_get(data, name) do
    Map.get(data, String.to_existing_atom(name))
  rescue
    ArgumentError -> nil
  end

  defp encode_value("address", value) when is_binary(value) do
    hex = String.trim_leading(value, "0x")

    case Base.decode16(hex, case: :mixed) do
      {:ok, bytes} when byte_size(bytes) == 20 ->
        {:ok, pad_left(bytes, 32)}

      {:ok, bytes} ->
        {:error, {:invalid_address_length, byte_size(bytes)}}

      :error ->
        {:error, {:invalid_hex, "address"}}
    end
  end

  defp encode_value("uint256", value) when is_integer(value) do
    {:ok, <<value::unsigned-big-256>>}
  end

  defp encode_value("uint256", value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, <<int::unsigned-big-256>>}
      _ -> {:error, {:invalid_uint256, value}}
    end
  end

  defp encode_value("bytes32", value) when is_binary(value) do
    hex = String.trim_leading(value, "0x")

    case Base.decode16(hex, case: :mixed) do
      {:ok, bytes} -> {:ok, pad_right(bytes, 32)}
      :error -> {:error, {:invalid_hex, "bytes32"}}
    end
  end

  defp encode_value("string", value) when is_binary(value) do
    {:ok, ExKeccak.hash_256(value)}
  end

  defp encode_value("bool", true), do: {:ok, <<1::unsigned-big-256>>}
  defp encode_value("bool", false), do: {:ok, <<0::unsigned-big-256>>}

  defp encode_value(_type, nil), do: {:ok, <<0::unsigned-big-256>>}

  defp encode_value(_type, value) when is_binary(value) do
    {:ok, pad_left(value, 32)}
  end

  defp pad_left(bytes, size) do
    padding = size - byte_size(bytes)

    if padding > 0 do
      <<0::size(padding * 8), bytes::binary>>
    else
      binary_part(bytes, byte_size(bytes) - size, size)
    end
  end

  defp pad_right(bytes, size) do
    padding = size - byte_size(bytes)

    if padding > 0 do
      <<bytes::binary, 0::size(padding * 8)>>
    else
      binary_part(bytes, 0, size)
    end
  end
end
