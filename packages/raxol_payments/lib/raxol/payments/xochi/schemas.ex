defmodule Raxol.Payments.Xochi.Schemas do
  @moduledoc """
  Request/response schemas for the Xochi intent API.

  Typed structs matching the Xochi API wire format (camelCase JSON).
  Xochi is the cash-positive agent-facing protocol -- Riddler solves
  intents behind the scenes.
  """

  defmodule QuoteRequest do
    @moduledoc false
    @enforce_keys [
      :wallet,
      :from_chain_id,
      :to_chain_id,
      :from_token,
      :to_token,
      :from_amount,
      :settlement_preference
    ]
    defstruct [
      :wallet,
      :from_chain_id,
      :to_chain_id,
      :from_token,
      :to_token,
      :from_amount,
      :trust_score,
      settlement_preference: "public",
      deadline: nil,
      slippage_bps: 50,
      gasless: false
    ]

    @type settlement :: String.t()

    @type t :: %__MODULE__{
            wallet: String.t(),
            from_chain_id: pos_integer(),
            to_chain_id: pos_integer(),
            from_token: String.t(),
            to_token: String.t(),
            from_amount: String.t(),
            settlement_preference: settlement(),
            deadline: integer() | nil,
            slippage_bps: non_neg_integer(),
            trust_score: non_neg_integer() | nil,
            gasless: boolean()
          }

    @spec to_json(t()) :: map()
    def to_json(%__MODULE__{} = req) do
      base = %{
        "wallet" => req.wallet,
        "from_chain_id" => req.from_chain_id,
        "to_chain_id" => req.to_chain_id,
        "from_token" => req.from_token,
        "to_token" => req.to_token,
        "from_amount" => req.from_amount,
        "settlement_preference" => req.settlement_preference,
        "deadline" => req.deadline || :os.system_time(:second) + 300,
        "slippage_bps" => req.slippage_bps,
        "gasless" => req.gasless
      }

      if req.trust_score do
        Map.put(base, "trust_score", req.trust_score)
      else
        base
      end
    end
  end

  defmodule QuoteResponse do
    @moduledoc false
    @enforce_keys [:intent_id, :quote_id]
    defstruct [
      :intent_id,
      :quote_id,
      :to_amount,
      :min_to_amount,
      :xochi_fee,
      :xochi_fee_rate,
      :estimated_gas_cost,
      :expiry,
      :eip712_data,
      :error,
      can_solve: false,
      gasless: false,
      gasless_fee: nil,
      settlement_options: []
    ]

    @type t :: %__MODULE__{
            intent_id: String.t(),
            quote_id: String.t(),
            can_solve: boolean(),
            to_amount: String.t() | nil,
            min_to_amount: String.t() | nil,
            xochi_fee: String.t() | nil,
            xochi_fee_rate: String.t() | nil,
            estimated_gas_cost: String.t() | nil,
            expiry: String.t() | nil,
            gasless: boolean(),
            gasless_fee: String.t() | nil,
            eip712_data: map() | nil,
            settlement_options: [map()],
            error: String.t() | nil
          }

    @spec from_json(map()) :: t()
    def from_json(json) do
      %__MODULE__{
        intent_id: json["intentId"],
        quote_id: json["quoteId"],
        can_solve: json["canSolve"] || false,
        to_amount: json["toAmount"],
        min_to_amount: json["minToAmount"],
        xochi_fee: json["xochiFee"],
        xochi_fee_rate: json["xochiFeeRate"],
        estimated_gas_cost: json["estimatedGasCost"],
        expiry: json["expiry"],
        gasless: json["gasless"] || false,
        gasless_fee: json["gaslessFee"],
        eip712_data: json["eip712Data"],
        settlement_options: json["settlementOptions"] || [],
        error: json["error"]
      }
    end
  end

  defmodule ExecuteRequest do
    @moduledoc false
    @enforce_keys [:intent_id, :quote_id, :signature, :nonce]
    defstruct [:intent_id, :quote_id, :signature, :nonce, :pull_signature, :aztec_proof]

    @type t :: %__MODULE__{
            intent_id: String.t(),
            quote_id: String.t(),
            signature: String.t(),
            nonce: non_neg_integer(),
            pull_signature: String.t() | nil,
            aztec_proof: String.t() | nil
          }

    @spec to_json(t()) :: map()
    def to_json(%__MODULE__{} = req) do
      base = %{
        "intent_id" => req.intent_id,
        "quote_id" => req.quote_id,
        "signature" => req.signature,
        "nonce" => req.nonce
      }

      base
      |> maybe_put("pull_signature", req.pull_signature)
      |> maybe_put("aztec_proof", req.aztec_proof)
    end

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, val), do: Map.put(map, key, val)
  end

  defmodule ExecuteResponse do
    @moduledoc false
    @enforce_keys [:intent_id, :status]
    defstruct [
      :intent_id,
      :status,
      :tx_hash,
      :note_commitment,
      :stealth_address,
      :ephemeral_pub_key,
      :view_tag,
      :error,
      success: false
    ]

    @type t :: %__MODULE__{
            success: boolean(),
            intent_id: String.t(),
            status: atom(),
            tx_hash: String.t() | nil,
            note_commitment: String.t() | nil,
            stealth_address: String.t() | nil,
            ephemeral_pub_key: String.t() | nil,
            view_tag: integer() | nil,
            error: String.t() | nil
          }

    @spec from_json(map()) :: t()
    def from_json(json) do
      %__MODULE__{
        success: json["success"] || false,
        intent_id: json["intentId"],
        status: parse_status(json["status"]),
        tx_hash: json["txHash"],
        note_commitment: json["noteCommitment"],
        stealth_address: json["stealthAddress"],
        ephemeral_pub_key: json["ephemeralPubKey"],
        view_tag: json["viewTag"],
        error: json["error"]
      }
    end

    defp parse_status(nil), do: :unknown
    defp parse_status(s) when is_binary(s), do: String.to_atom(s)
  end

  defmodule IntentStatus do
    @moduledoc false
    @enforce_keys [:intent_id, :status]
    defstruct [
      :intent_id,
      :status,
      :tx_hash,
      :receiving_tx_hash,
      :error,
      :updated_at,
      :substatus,
      :substatus_message,
      terminal: false
    ]

    @type status ::
            :idle
            | :pending
            | :quoting
            | :quoted
            | :signing
            | :executing
            | :bridging
            | :settling
            | :completed
            | :failed
            | :expired

    @type t :: %__MODULE__{
            intent_id: String.t(),
            status: status(),
            tx_hash: String.t() | nil,
            receiving_tx_hash: String.t() | nil,
            error: String.t() | nil,
            updated_at: String.t() | nil,
            substatus: String.t() | nil,
            substatus_message: String.t() | nil,
            terminal: boolean()
          }

    @terminal_statuses [:completed, :failed, :expired]

    @spec from_json(map()) :: t()
    def from_json(json) do
      status = parse_status(json["status"])

      %__MODULE__{
        intent_id: json["intentId"],
        status: status,
        tx_hash: json["txHash"],
        receiving_tx_hash: json["receivingTxHash"],
        error: json["error"],
        updated_at: json["updatedAt"],
        substatus: json["substatus"],
        substatus_message: json["substatusMessage"],
        terminal: json["terminal"] || status in @terminal_statuses
      }
    end

    @spec terminal?(t()) :: boolean()
    def terminal?(%__MODULE__{terminal: t}), do: t

    defp parse_status(nil), do: :unknown
    defp parse_status(s) when is_binary(s), do: String.to_atom(s)
  end
end
