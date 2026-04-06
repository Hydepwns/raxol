defmodule Raxol.Payments.Protocols.Riddler do
  @moduledoc """
  Riddler cross-chain intent solver protocol.

  Unlike x402/MPP, Riddler is not a 402-triggered protocol. It uses an
  explicit quote -> sign -> order -> poll flow via the Riddler Commerce API.

  The Protocol behaviour callbacks (`detect?/2`, `parse_challenge/1`, etc.)
  return stub values since Riddler is invoked directly, not via HTTP 402.

  ## Usage

      config = %{base_url: "https://riddler.example.com", api_key: "..."}
      wallet = MyWallet

      {:ok, quote} = Riddler.quote(config, %QuoteRequest{...})
      {:ok, order} = Riddler.submit_order(config, quote, wallet)
      {:ok, status} = Riddler.poll_status(config, order["orderId"])
  """

  @behaviour Raxol.Payments.Protocol

  alias Raxol.Payments.Riddler.Client
  alias Raxol.Payments.Riddler.Schemas.{QuoteRequest, QuoteResponse, OrderRequest, OrderStatus}

  @default_poll_interval_ms 2_000
  @default_poll_timeout_ms 120_000

  # -- Protocol behaviour (stubs -- Riddler is not a 402 protocol) --

  @impl true
  @spec name() :: String.t()
  def name, do: "Riddler"

  @impl true
  @spec detect?(integer(), [{String.t(), String.t()}]) :: boolean()
  def detect?(_status, _headers), do: false

  @impl true
  @spec parse_challenge([{String.t(), String.t()}]) :: {:error, :not_a_402_protocol}
  def parse_challenge(_headers), do: {:error, :not_a_402_protocol}

  @impl true
  @spec build_payment(map(), module()) :: {:error, :not_a_402_protocol}
  def build_payment(_challenge, _wallet), do: {:error, :not_a_402_protocol}

  @impl true
  @spec parse_receipt([{String.t(), String.t()}]) :: {:error, :not_a_402_protocol}
  def parse_receipt(_headers), do: {:error, :not_a_402_protocol}

  @impl true
  @spec amount(map()) :: Decimal.t()
  def amount(%{output_amount: amt}) when is_binary(amt), do: Decimal.new(amt)
  def amount(_challenge), do: Decimal.new(0)

  # -- Direct API --

  @doc """
  Request a cross-chain transfer quote from Riddler.
  """
  @spec get_quote(Client.config(), QuoteRequest.t()) ::
          {:ok, QuoteResponse.t()} | {:error, term()}
  def get_quote(config, %QuoteRequest{} = request) do
    Client.get_quote(config, request)
  end

  @doc """
  Sign and submit an order for a given quote.

  Builds an ERC-3009 ReceiveWithAuthorization message from the quote's
  gasless parameters and signs it with the provided wallet.
  """
  @spec submit_order(Client.config(), QuoteResponse.t(), module()) ::
          {:ok, map()} | {:error, term()}
  def submit_order(config, %QuoteResponse{} = quote_resp, wallet) do
    with {:ok, {signed_object, signature}} <- sign_quote(quote_resp, wallet) do
      order = %OrderRequest{
        quote_id: quote_resp.quote_id,
        signed_object: signed_object,
        signature: signature
      }

      Client.submit_order(config, order)
    end
  end

  @doc """
  Poll order status until terminal (completed/failed/refunded) or timeout.

  Returns `{:ok, %OrderStatus{}}` when a terminal state is reached,
  or `{:error, :timeout}` if `timeout_ms` elapses.

  ## Options

  - `:interval_ms` -- poll interval (default: #{@default_poll_interval_ms}ms)
  - `:timeout_ms` -- max wait time (default: #{@default_poll_timeout_ms}ms)
  """
  @spec poll_status(Client.config(), String.t(), keyword()) ::
          {:ok, OrderStatus.t()} | {:error, term()}
  def poll_status(config, order_id, opts \\ []) do
    interval = Keyword.get(opts, :interval_ms, @default_poll_interval_ms)
    timeout = Keyword.get(opts, :timeout_ms, @default_poll_timeout_ms)
    deadline = System.monotonic_time(:millisecond) + timeout

    do_poll(config, order_id, interval, deadline)
  end

  # -- Private --

  defp do_poll(config, order_id, interval, deadline) do
    case Client.get_status(config, order_id) do
      {:ok, %OrderStatus{} = status} ->
        if OrderStatus.terminal?(status) do
          {:ok, status}
        else
          now = System.monotonic_time(:millisecond)

          if now + interval > deadline do
            {:error, :timeout}
          else
            Process.sleep(interval)
            do_poll(config, order_id, interval, deadline)
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp sign_quote(%QuoteResponse{gasless: %{"type" => "erc3009"} = gasless}, wallet) do
    sign_erc3009(gasless, wallet)
  end

  defp sign_quote(%QuoteResponse{gasless: %{"type" => "permit2"} = gasless}, wallet) do
    sign_permit2(gasless, wallet)
  end

  defp sign_quote(%QuoteResponse{deposit_address: %{"address" => _}}, _wallet) do
    # Deposit address flow: no signing needed, user sends funds directly
    {:error, :deposit_address_flow}
  end

  defp sign_quote(_quote_resp, _wallet) do
    {:error, :unsupported_quote_type}
  end

  defp sign_erc3009(gasless, wallet) do
    domain = %{
      name: "USD Coin",
      version: "2",
      chainId: wallet.chain_id(),
      verifyingContract: usdc_address(wallet.chain_id())
    }

    types = %{
      "ReceiveWithAuthorization" => [
        {"from", "address"},
        {"to", "address"},
        {"value", "uint256"},
        {"validAfter", "uint256"},
        {"validBefore", "uint256"},
        {"nonce", "bytes32"}
      ]
    }

    now = :os.system_time(:second)

    message = %{
      from: wallet.address(),
      to: gasless["to"],
      value: gasless["value"] || 0,
      validAfter: 0,
      validBefore: now + 3600,
      nonce: gasless["nonce"] || generate_nonce()
    }

    # Encode message as ABI-packed hex for signedObject
    signed_object = encode_erc3009(message)

    case wallet.sign_typed_data(domain, types, message) do
      {:ok, sig_bytes} ->
        signature = "0x" <> Base.encode16(sig_bytes, case: :lower)
        {:ok, {signed_object, signature}}

      {:error, reason} ->
        {:error, {:sign_failed, reason}}
    end
  end

  defp sign_permit2(gasless, wallet) do
    domain = %{
      name: "Permit2",
      chainId: wallet.chain_id(),
      verifyingContract: permit2_address()
    }

    types = %{
      "PermitTransferFrom" => [
        {"permitted", "TokenPermissions"},
        {"spender", "address"},
        {"nonce", "uint256"},
        {"deadline", "uint256"}
      ],
      "TokenPermissions" => [
        {"token", "address"},
        {"amount", "uint256"}
      ]
    }

    now = :os.system_time(:second)

    message = %{
      permitted: %{
        token: usdc_address(wallet.chain_id()),
        amount: gasless["value"] || 0
      },
      spender: gasless["to"],
      nonce: gasless["nonce"] || 0,
      deadline: now + 3600
    }

    signed_object = encode_permit2(message, gasless["orderId"])

    case wallet.sign_typed_data(domain, types, message) do
      {:ok, sig_bytes} ->
        signature = "0x" <> Base.encode16(sig_bytes, case: :lower)
        {:ok, {signed_object, signature}}

      {:error, reason} ->
        {:error, {:sign_failed, reason}}
    end
  end

  defp encode_erc3009(message) do
    # ABI-encode the ReceiveWithAuthorization fields as hex
    fields = [
      pad_address(message.from),
      pad_address(message.to),
      pad_uint256(message.value),
      pad_uint256(message.validAfter),
      pad_uint256(message.validBefore),
      pad_bytes32(message.nonce)
    ]

    "0x" <> Enum.join(fields)
  end

  defp encode_permit2(message, order_id) do
    fields = [
      pad_address(message.permitted.token),
      pad_uint256(message.permitted.amount),
      pad_address(message.spender),
      pad_uint256(message.nonce),
      pad_uint256(message.deadline),
      pad_bytes32(order_id || "0x" <> String.duplicate("0", 64))
    ]

    "0x" <> Enum.join(fields)
  end

  defp pad_address(addr) when is_binary(addr) do
    addr
    |> String.replace_leading("0x", "")
    |> String.downcase()
    |> String.pad_leading(64, "0")
  end

  defp pad_uint256(val) when is_integer(val) do
    val
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(64, "0")
  end

  defp pad_uint256(val) when is_binary(val) do
    val
    |> String.replace_leading("0x", "")
    |> String.downcase()
    |> String.pad_leading(64, "0")
  end

  defp pad_bytes32(val) when is_binary(val) do
    val
    |> String.replace_leading("0x", "")
    |> String.downcase()
    |> String.pad_trailing(64, "0")
  end

  defp generate_nonce do
    "0x" <> (:crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower))
  end

  # Canonical USDC addresses per chain
  defp usdc_address(8453), do: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
  defp usdc_address(1), do: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
  defp usdc_address(42161), do: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"
  defp usdc_address(10), do: "0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85"
  defp usdc_address(137), do: "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359"
  defp usdc_address(_), do: "0x0000000000000000000000000000000000000000"

  # Canonical Permit2 address (same on all EVM chains)
  defp permit2_address, do: "0x000000000022D473030F116dDEE9F6B43aC78BA3"
end
