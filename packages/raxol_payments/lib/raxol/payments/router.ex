defmodule Raxol.Payments.Router do
  @moduledoc """
  Selects the optimal payment protocol based on configuration and KYC tier.

  Routes payment requests to the appropriate protocol based on:
  - KYC verification level (verified, basic, none)
  - Privacy preference (private, public, auto)
  - Cross-chain requirements
  - Cost optimization

  ## Routing Logic (planned)

      KYC Verified + wants privacy -> Xochi (stealth addresses, ZKSAR)
      KYC Verified + wants best rate -> Public chain (lowest fees)
      No KYC + wants privacy -> Xochi (limited, higher fees)
      No KYC + public -> x402/MPP direct (cheapest, fully transparent)
      Cross-chain needed -> Riddler (any of the above as settlement)

  This module is a stub. Full routing will be implemented in Phase C.
  """

  @type kyc_tier :: :verified | :basic | :none
  @type privacy :: :private | :public | :auto

  @doc """
  Select the best protocol for a payment based on configuration.

  Returns a protocol atom (:x402, :mpp, :riddler, :xochi).
  """
  @spec select(keyword()) :: atom()
  def select(opts \\ []) do
    _kyc = Keyword.get(opts, :kyc_tier, :none)
    _privacy = Keyword.get(opts, :privacy, :auto)
    _cross_chain = Keyword.get(opts, :cross_chain, false)

    # Phase A: always use x402 or mpp
    :x402
  end
end
