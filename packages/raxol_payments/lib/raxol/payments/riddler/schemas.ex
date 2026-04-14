defmodule Raxol.Payments.Riddler.Schemas do
  @moduledoc """
  Request/response schemas for the Riddler Commerce API.

  Typed structs for quotes, orders, and status responses matching
  the Commerce API's JSON wire format (camelCase keys).
  """

  defmodule Chain do
    @moduledoc false
    @enforce_keys [:chain_name, :chain_id]
    defstruct [:chain_name, :chain_id]

    @type t :: %__MODULE__{
            chain_name: String.t(),
            chain_id: pos_integer()
          }

    @spec from_json(map()) :: t()
    def from_json(%{"chainName" => name, "chainId" => id}) do
      %__MODULE__{chain_name: name, chain_id: id}
    end
  end

  defmodule Route do
    @moduledoc false
    @enforce_keys [:from_chain_id, :to_chain_id, :from_asset, :to_asset]
    defstruct [:from_chain_id, :to_chain_id, :from_asset, :to_asset]

    @type t :: %__MODULE__{
            from_chain_id: pos_integer(),
            to_chain_id: pos_integer(),
            from_asset: String.t(),
            to_asset: String.t()
          }

    @spec from_json(map()) :: t()
    def from_json(json) do
      %__MODULE__{
        from_chain_id: json["fromChainId"],
        to_chain_id: json["toChainId"],
        from_asset: json["fromAsset"],
        to_asset: json["toAsset"]
      }
    end
  end

  defmodule QuoteRequest do
    @moduledoc false
    @enforce_keys [
      :refund_address,
      :input_token,
      :input_chain_id,
      :output_address,
      :output_token,
      :output_chain_id,
      :input_amount
    ]
    defstruct [
      :refund_address,
      :input_token,
      :input_chain_id,
      :output_address,
      :output_token,
      :output_chain_id,
      :input_amount,
      :expires,
      gasless_or_deposit_address: "deposit_address",
      fallback: "refund"
    ]

    @type t :: %__MODULE__{
            refund_address: String.t(),
            input_token: String.t(),
            input_chain_id: pos_integer(),
            output_address: String.t(),
            output_token: String.t(),
            output_chain_id: pos_integer(),
            input_amount: String.t(),
            gasless_or_deposit_address: String.t(),
            expires: integer() | nil,
            fallback: String.t()
          }

    @spec to_query(t()) :: keyword()
    def to_query(%__MODULE__{} = req) do
      params = [
        refundAddress: req.refund_address,
        inputToken: req.input_token,
        inputChainId: req.input_chain_id,
        outputAddress: req.output_address,
        outputToken: req.output_token,
        outputChainId: req.output_chain_id,
        inputAmount: req.input_amount,
        gaslessOrDepositAddress: req.gasless_or_deposit_address,
        fallback: req.fallback
      ]

      if req.expires do
        params ++ [expires: req.expires]
      else
        params ++ [expires: :os.system_time(:second) + 300]
      end
    end
  end

  defmodule QuoteResponse do
    @moduledoc false
    @enforce_keys [:quote_id, :output_amount, :quote_expires]
    defstruct [
      :quote_id,
      :output_amount,
      :quote_expires,
      :request,
      :deposit_address,
      :gasless,
      :pimlico,
      :eip712_data
    ]

    @type t :: %__MODULE__{
            quote_id: String.t(),
            output_amount: String.t(),
            quote_expires: integer(),
            request: map() | nil,
            deposit_address: map() | nil,
            gasless: map() | nil,
            pimlico: map() | nil,
            eip712_data: map() | nil
          }

    @spec from_json(map()) :: t()
    def from_json(json) do
      %__MODULE__{
        quote_id: json["quoteId"],
        output_amount: json["outputAmount"],
        quote_expires: json["quoteExpires"],
        request: json["request"],
        deposit_address: json["depositAddress"],
        gasless: json["gasless"],
        pimlico: json["pimlico"],
        eip712_data: json["eip712Data"]
      }
    end
  end

  defmodule OrderRequest do
    @moduledoc false
    @enforce_keys [:quote_id, :signed_object, :signature]
    defstruct [:order_id, :quote_id, :signed_object, :signature]

    @type t :: %__MODULE__{
            order_id: String.t() | nil,
            quote_id: String.t(),
            signed_object: String.t(),
            signature: String.t()
          }

    @spec to_json(t()) :: map()
    def to_json(%__MODULE__{} = req) do
      base = %{
        "quoteId" => req.quote_id,
        "signedObject" => req.signed_object,
        "signature" => req.signature
      }

      if req.order_id do
        Map.put(base, "orderId", req.order_id)
      else
        base
      end
    end
  end

  defmodule OrderStatus do
    @moduledoc false
    @enforce_keys [:order_id, :status]
    defstruct [
      :order_id,
      :quote_id,
      :status,
      :input_chain_id,
      :output_chain_id,
      :input_amount,
      :output_amount,
      :refund_address,
      :input_transaction,
      :output_transaction,
      :error_reason,
      :created_at_ms,
      :updated_at_ms
    ]

    @type status ::
            :pending
            | :received
            | :forwarding
            | :settling
            | :completed
            | :failed
            | :settlement_failed
            | :refunded
            | :awaiting_deposit
            | :expired

    @type t :: %__MODULE__{
            order_id: String.t(),
            quote_id: String.t() | nil,
            status: status(),
            input_chain_id: pos_integer() | nil,
            output_chain_id: pos_integer() | nil,
            input_amount: String.t() | nil,
            output_amount: String.t() | nil,
            refund_address: String.t() | nil,
            input_transaction: String.t() | nil,
            output_transaction: String.t() | nil,
            error_reason: String.t() | nil,
            created_at_ms: integer() | nil,
            updated_at_ms: integer() | nil
          }

    @spec from_json(map()) :: t()
    def from_json(json) do
      %__MODULE__{
        order_id: json["orderId"],
        quote_id: json["quoteId"],
        status: parse_status(json["status"]),
        input_chain_id: json["inputChainId"],
        output_chain_id: json["outputChainId"],
        input_amount: json["inputAmount"],
        output_amount: json["outputAmount"],
        refund_address: json["refundAddress"],
        input_transaction: json["inputTransaction"],
        output_transaction: json["outputTransaction"],
        error_reason: json["errorReason"],
        created_at_ms: json["createdAtMs"],
        updated_at_ms: json["updatedAtMs"]
      }
    end

    @terminal_statuses [:completed, :failed, :settlement_failed, :refunded, :expired]

    @spec terminal?(t()) :: boolean()
    def terminal?(%__MODULE__{status: s}), do: s in @terminal_statuses

    defp parse_status("pending"), do: :pending
    defp parse_status("received"), do: :received
    defp parse_status("forwarding"), do: :forwarding
    defp parse_status("settling"), do: :settling
    defp parse_status("completed"), do: :completed
    defp parse_status("failed"), do: :failed
    defp parse_status("settlement_failed"), do: :settlement_failed
    defp parse_status("refunded"), do: :refunded
    defp parse_status("awaiting_deposit"), do: :awaiting_deposit
    defp parse_status("expired"), do: :expired
    defp parse_status(_other), do: :unknown
  end
end
