defmodule Raxol.Payments.Protocols.Riddler do
  @moduledoc """
  Riddler cross-chain intent solver protocol (stub).

  Unlike x402/MPP, Riddler is not a 402-triggered protocol. It uses an
  explicit quote -> sign -> order -> poll flow via the Riddler Commerce API.

  This will be implemented in Phase B of the payments roadmap.
  """

  @behaviour Raxol.Payments.Protocol

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
  @spec build_payment(map(), module()) :: {:error, :not_implemented}
  def build_payment(_challenge, _wallet), do: {:error, :not_implemented}

  @impl true
  @spec parse_receipt([{String.t(), String.t()}]) :: {:error, :not_implemented}
  def parse_receipt(_headers), do: {:error, :not_implemented}

  @impl true
  @spec amount(map()) :: Decimal.t()
  def amount(_challenge), do: Decimal.new(0)
end
