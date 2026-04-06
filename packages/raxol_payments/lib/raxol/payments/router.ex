defmodule Raxol.Payments.Router do
  @moduledoc """
  Selects the optimal payment protocol based on transfer requirements.

  ## Routing Logic

      Same-chain + HTTP 402 detected -> x402 or MPP (auto-pay plugin)
      Cross-chain transfer          -> Xochi (agent-facing, cash-positive)
      Explicit privacy request      -> Xochi with stealth/shielded settlement
      Direct solver access          -> Riddler (internal, not default)

  Xochi is the default for cross-chain because it's the revenue-positive
  path with tier-based fees. Riddler Commerce is B2B (Coinbase/Shopify)
  and not intended for agent use.
  """

  @type privacy :: :public | :stealth | :shielded | :auto

  @doc """
  Select the best protocol for a payment.

  Returns a protocol atom: `:x402`, `:mpp`, `:xochi`, or `:riddler`.

  ## Options

  - `:cross_chain` -- true if source and dest chains differ (default: false)
  - `:privacy` -- `:public`, `:stealth`, `:shielded`, or `:auto` (default: `:auto`)
  - `:protocol` -- force a specific protocol (overrides routing)
  """
  @spec select(keyword()) :: atom()
  def select(opts \\ []) do
    case Keyword.get(opts, :protocol) do
      nil -> auto_select(opts)
      forced -> forced
    end
  end

  defp auto_select(opts) do
    select_protocol(
      Keyword.get(opts, :privacy, :auto),
      Keyword.get(opts, :cross_chain, false)
    )
  end

  defp select_protocol(privacy, _cross_chain) when privacy in [:stealth, :shielded], do: :xochi
  defp select_protocol(_privacy, true), do: :xochi
  defp select_protocol(_privacy, _cross_chain), do: :x402
end
