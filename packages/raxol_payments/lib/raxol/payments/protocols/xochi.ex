defmodule Raxol.Payments.Protocols.Xochi do
  @moduledoc """
  Xochi private execution protocol (stub).

  Provides private payments using stealth addresses (ERC-5564/ERC-6538)
  and ZKSAR compliance. KYC-tiered access controls fee rates and
  privacy depth.

  This will be implemented in Phase C of the payments roadmap.
  """

  @behaviour Raxol.Payments.Protocol

  @impl true
  @spec name() :: String.t()
  def name, do: "Xochi"

  @impl true
  @spec detect?(integer(), [{String.t(), String.t()}]) :: boolean()
  def detect?(_status, _headers), do: false

  @impl true
  @spec parse_challenge([{String.t(), String.t()}]) :: {:error, :not_a_402_protocol}
  def parse_challenge(_headers), do: {:error, :not_a_402_protocol}

  @impl true
  @spec build_payment(map(), module()) :: {:error, :not_implemented}
  def build_payment(_challenge, _wallet), do: {:error, :not_implemented}

  @impl true
  @spec parse_receipt([{String.t(), String.t()}]) :: {:error, :not_implemented}
  def parse_receipt(_headers), do: {:error, :not_implemented}

  @impl true
  @spec amount(map()) :: Decimal.t()
  def amount(_challenge), do: Decimal.new(0)
end
