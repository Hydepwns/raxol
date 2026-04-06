defmodule Raxol.Payments.Xochi.Client do
  @moduledoc """
  Client for the Xochi private execution protocol (stub).

  Will handle private intent submission, ZKSAR attestation attachment,
  and KYC-tiered access. This will be implemented in Phase C.
  """

  @doc "Submit a private intent."
  @spec submit_intent(map()) :: {:ok, map()} | {:error, term()}
  def submit_intent(_params), do: {:error, :not_implemented}

  @doc "Attach ZKSAR attestation to an intent."
  @spec attach_attestation(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def attach_attestation(_intent_id, _attestation), do: {:error, :not_implemented}

  @doc "Get intent status."
  @spec get_status(String.t()) :: {:ok, map()} | {:error, term()}
  def get_status(_intent_id), do: {:error, :not_implemented}
end
