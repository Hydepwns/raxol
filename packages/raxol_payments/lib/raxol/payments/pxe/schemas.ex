defmodule Raxol.Payments.Pxe.Schemas do
  @moduledoc """
  Request/response schemas for the pxe-bridge JSON-RPC API.

  pxe-bridge wraps Aztec's Private eXecution Environment, letting EVM
  solvers create shielded notes on Aztec L2 without understanding
  Aztec's privacy model.

  ## RPC Methods

  - `aztec_createNote` -- create a shielded token note for a recipient
  - `aztec_getVersion` -- return connected Aztec node version
  """

  defmodule CreateNoteParams do
    @moduledoc false
    @enforce_keys [:recipient, :token, :amount, :chain_id]
    defstruct [:recipient, :token, :amount, :chain_id]

    @type t :: %__MODULE__{
            recipient: String.t(),
            token: String.t(),
            amount: String.t(),
            chain_id: pos_integer()
          }

    @aztec_address_re ~r/\A0x[0-9a-fA-F]{64}\z/

    @spec validate(t()) :: :ok | {:error, term()}
    def validate(%__MODULE__{} = p) do
      cond do
        not Regex.match?(@aztec_address_re, p.recipient) ->
          {:error, {:invalid_recipient, "must be 0x + 64 hex chars"}}

        not Regex.match?(@aztec_address_re, p.token) ->
          {:error, {:invalid_token, "must be 0x + 64 hex chars"}}

        not valid_amount?(p.amount) ->
          {:error, {:invalid_amount, "must be non-negative integer string"}}

        p.chain_id < 1 ->
          {:error, {:invalid_chain_id, "must be positive"}}

        true ->
          :ok
      end
    end

    @spec to_json(t()) :: map()
    def to_json(%__MODULE__{} = p) do
      %{
        "recipient" => p.recipient,
        "token" => p.token,
        "amount" => p.amount,
        "chainId" => p.chain_id
      }
    end

    defp valid_amount?(s) when is_binary(s) do
      Regex.match?(~r/\A(0|[1-9]\d{0,77})\z/, s)
    end

    defp valid_amount?(_), do: false
  end

  defmodule CreateNoteResult do
    @moduledoc false
    @enforce_keys [:note_commitment, :nullifier_hash, :l2_tx_hash]
    defstruct [:note_commitment, :nullifier_hash, :l2_tx_hash]

    @type t :: %__MODULE__{
            note_commitment: String.t(),
            nullifier_hash: String.t(),
            l2_tx_hash: String.t()
          }

    @spec from_json(map()) :: t()
    def from_json(json) do
      %__MODULE__{
        note_commitment: json["noteCommitment"],
        nullifier_hash: json["nullifierHash"],
        l2_tx_hash: json["l2TxHash"]
      }
    end
  end

  defmodule HealthStatus do
    @moduledoc false
    defstruct [:status, :version]

    @type t :: %__MODULE__{
            status: :ok | :starting | :error,
            version: String.t() | nil
          }

    @spec from_json(map()) :: t()
    def from_json(json) do
      %__MODULE__{
        status: parse_status(json["status"]),
        version: json["version"]
      }
    end

    defp parse_status("ok"), do: :ok
    defp parse_status("starting"), do: :starting
    defp parse_status(_), do: :error
  end
end
