defmodule Raxol.Payments.Xochi.Stealth do
  @moduledoc """
  ERC-5564/ERC-6538 stealth address derivation (stub).

  Will generate ephemeral keypairs per transaction and derive one-time
  addresses from a recipient's stealth meta-address, providing unlinkable
  payment destinations. This will be implemented in Phase C.
  """

  @doc "Generate a stealth address from a recipient's meta-address."
  @spec generate(String.t()) ::
          {:ok, %{address: String.t(), ephemeral_key: binary()}} | {:error, term()}
  def generate(_meta_address), do: {:error, :not_implemented}

  @doc "Scan for payments sent to stealth addresses derived from our keys."
  @spec scan(binary(), list()) :: {:ok, list()} | {:error, term()}
  def scan(_spending_key, _announcements), do: {:error, :not_implemented}
end
