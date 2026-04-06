defmodule Raxol.Payments.Protocols.MPP do
  @moduledoc """
  Machine Payments Protocol client (Stripe/Tempo).

  Handles the HTTP 402 flow using the MPP challenge/credential scheme.
  The server returns `WWW-Authenticate: Payment` with a challenge; this
  module decodes it, signs a payment credential, and builds the
  `Authorization: Payment` header for the retry request.

  ## Header Flow

  1. Server -> `402` + `WWW-Authenticate: Payment <base64 challenge>`
  2. Client -> retry + `Authorization: Payment <base64 credential>`
  3. Server -> `200` + `Payment-Receipt: <base64 receipt>`

  ## Payment Methods

  MPP supports multiple payment methods per challenge. This implementation
  handles EVM-based methods (Tempo, ETH, ERC-20). Stripe (fiat) methods
  are detected but not yet implemented.
  """

  @behaviour Raxol.Payments.Protocol

  alias Raxol.Payments.Headers

  @impl true
  @spec name() :: String.t()
  def name, do: "MPP"

  @impl true
  @spec detect?(integer(), Headers.headers()) :: boolean()
  def detect?(402, headers) do
    case Headers.find(headers, "www-authenticate") do
      nil -> false
      value -> String.contains?(String.downcase(value), "payment")
    end
  end

  def detect?(_status, _headers), do: false

  @impl true
  @spec parse_challenge(Headers.headers()) :: {:ok, map()} | {:error, term()}
  def parse_challenge(headers) do
    with {:ok, auth_header} <- Headers.require(headers, "www-authenticate"),
         {:ok, challenge_data} <- extract_payment_challenge(auth_header) do
      {:ok,
       %{
         amount: challenge_data["amount"],
         currency: challenge_data["currency"] || "USDC",
         recipient: challenge_data["recipient"] || challenge_data["pay_to"],
         methods: challenge_data["methods"] || [],
         network: challenge_data["network"],
         nonce: challenge_data["nonce"],
         expires: challenge_data["expires"],
         description: challenge_data["description"],
         extra: challenge_data
       }}
    end
  end

  @impl true
  @spec build_payment(map(), module()) :: {:ok, Headers.headers()} | {:error, term()}
  def build_payment(challenge, wallet) do
    credential =
      %{
        method: select_method(challenge.methods),
        amount: challenge.amount,
        currency: challenge.currency,
        from: wallet.address(),
        to: challenge.recipient,
        network: challenge.network,
        nonce: challenge.nonce,
        timestamp: :os.system_time(:second)
      }

    case wallet.sign_message(Jason.encode!(credential)) do
      {:ok, signature} ->
        signed_credential =
          Map.put(credential, :signature, "0x" <> Base.encode16(signature, case: :lower))

        encoded = Base.encode64(Jason.encode!(signed_credential))
        {:ok, [{"authorization", "Payment " <> encoded}]}

      {:error, reason} ->
        {:error, {:sign_failed, reason}}
    end
  end

  @impl true
  @spec parse_receipt(Headers.headers()) :: {:ok, map()} | {:error, term()}
  def parse_receipt(headers) do
    case Headers.find(headers, "payment-receipt") do
      nil ->
        {:error, :no_receipt}

      encoded ->
        with {:ok, json} <- Base.decode64(encoded),
             {:ok, decoded} <- Jason.decode(json) do
          {:ok,
           %{
             tx_hash: decoded["transactionHash"] || decoded["tx_hash"],
             amount: decoded["amount"],
             method: decoded["method"],
             success: decoded["success"] != false
           }}
        end
    end
  end

  @impl true
  @spec amount(map()) :: Decimal.t()
  def amount(challenge) do
    challenge.amount
    |> to_string()
    |> Decimal.new()
  end

  # -- Private --

  defp extract_payment_challenge(auth_header) do
    case String.split(auth_header, " ", parts: 2) do
      [_scheme, encoded] ->
        with {:ok, json} <- Base.decode64(String.trim(encoded)),
             {:ok, decoded} <- Jason.decode(json) do
          {:ok, decoded}
        end

      _ ->
        {:error, :invalid_auth_header}
    end
  end

  defp select_method([]), do: "evm"

  defp select_method(methods) do
    Enum.find(methods, List.first(methods), fn method ->
      method_type = if is_map(method), do: method["type"], else: method
      method_type in ["tempo", "evm", "eth"]
    end)
    |> then(fn
      method when is_map(method) -> method["type"]
      method -> method
    end)
  end
end
