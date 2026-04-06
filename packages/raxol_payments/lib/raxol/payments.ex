defmodule Raxol.Payments do
  @moduledoc """
  Autonomous payment capabilities for Raxol agents.

  Provides transparent HTTP 402 auto-pay (x402 and MPP protocols), wallet
  management, spending controls, and agent actions for explicit payments.

  ## Protocol Stack

  - **x402** (Coinbase): EIP-712 signed ERC-3009 transfers, facilitator-mediated
  - **MPP** (Stripe/Tempo): multi-method (Stripe fiat, Tempo stablecoins, EVM)
  - **Riddler**: cross-chain intents via solver network (planned)
  - **Xochi**: private execution with ZKSAR compliance (planned)

  ## Quick Start

      # Configure a wallet
      wallet = Raxol.Payments.Wallets.Env.new()

      # Attach auto-pay to an agent's backend opts
      backend_opts = [
        api_key: "sk-...",
        req_plugins: [
          {Raxol.Payments.Req.AutoPay, wallet: wallet, protocols: [:x402, :mpp]}
        ]
      ]
  """
end
