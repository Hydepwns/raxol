defmodule Raxol.Payments.Wallet do
  @moduledoc """
  Behaviour for wallet implementations providing signing and identity.

  Wallets handle private key storage and signing operations. Two
  implementations are provided:

  - `Raxol.Payments.Wallets.Env` -- loads key from environment variable
  - `Raxol.Payments.Wallets.Op` -- loads key from 1Password via `op` CLI

  ## Implementing a Custom Wallet

      defmodule MyWallet do
        @behaviour Raxol.Payments.Wallet

        @impl true
        def address, do: "0x..."

        @impl true
        def chain_id, do: 8453

        @impl true
        def sign_message(message) do
          # Sign raw message bytes
          {:ok, signature_bytes}
        end

        @impl true
        def sign_typed_data(domain, types, message) do
          # Sign EIP-712 structured data
          {:ok, signature_bytes}
        end
      end
  """

  @type signature :: binary()

  @doc "Return the wallet's hex-encoded address (0x-prefixed)."
  @callback address() :: String.t()

  @doc "Return the chain ID this wallet is configured for."
  @callback chain_id() :: pos_integer()

  @doc "Sign a raw message (keccak256 hash + secp256k1 signature)."
  @callback sign_message(message :: binary()) ::
              {:ok, signature()} | {:error, term()}

  @doc """
  Sign EIP-712 typed structured data.

  Used by x402 (ERC-3009 transferWithAuthorization) and other protocols
  that require typed data signatures.
  """
  @callback sign_typed_data(
              domain :: map(),
              types :: map(),
              message :: map()
            ) :: {:ok, signature()} | {:error, term()}
end
