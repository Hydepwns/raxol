# Agentic Commerce

Agents that can pay for things. `raxol_payments` gives any Raxol agent autonomous payment capabilities -- balance checks, quotes, transfers, spending limits -- across chains and protocols.

## How It Works

An agent returns payment commands from `update/2` the same way it returns shell or async commands. The `SpendingHook` intercepts commands before execution, checks them against the `SpendingPolicy`, and the `Ledger` tracks what's been spent.

```
Agent update/2 returns command
    |
    v
SpendingHook checks SpendingPolicy (per-request / session / lifetime limits)
    |
    v
Router.select/1 picks protocol based on context:
    same-chain HTTP 402 --> x402 or MPP (auto-pay)
    cross-chain         --> Xochi (intent-based settlement)
    privacy             --> Xochi (stealth/shielded)
    |
    v
Wallet signs the transaction (EIP-712)
    |
    v
Ledger records the spend
```

## Wallet Backends

Two wallet implementations behind the `Raxol.Payments.Wallet` behaviour:

- `Wallets.Env` -- private key from an environment variable. Simple, good for dev and CI.
- `Wallets.Op` -- private key fetched from 1Password via a GenServer. No plaintext key on disk.

Both expose `address/1`, `sign/2`, and `balance/2`.

## Protocols

### x402 (Coinbase)

Handles HTTP 402 Payment Required responses. The server says "pay me X to address Y," the wallet signs an EIP-712 authorization (ERC-3009 `transferWithAuthorization`), and the signed payload goes back in the retry header. All transparent to the agent.

### MPP (Machine Payments Protocol)

Stripe/Tempo's protocol for machine-to-machine payments. Same HTTP 402 flow, different wire format. The `AutoPay` Req plugin handles both x402 and MPP automatically -- just add it as a response step.

### Xochi

Intent-based cross-chain settlement. The agent says "I want to pay 10 USDC on Base to address X on Arbitrum," Xochi quotes a fee (0.10-0.30% depending on tier), the wallet signs the intent, and Riddler's solver network handles the actual cross-chain execution.

Flow: `get_quote/2` -> `execute/3` (wallet signs EIP-712 intent) -> `poll_status/3`.

Xochi is the default for cross-chain and privacy (stealth addresses, shielded transfers). It's cash-positive by design -- the protocol takes a fee, the agent pays it, done.

### Riddler (direct solver -- B2B only)

Direct access to Riddler's Commerce API for bulk/institutional flows. Cash-negative for the protocol (solver subsidizes execution), so don't use it for agent payments. It exists for B2B integrations where the business relationship justifies the economics.

## Spending Controls

Three layers of limits in `SpendingPolicy`:

- **Per-request**: max amount for a single transaction
- **Per-session**: rolling total within one agent session
- **Lifetime**: hard cap across all sessions

The `Ledger` is an ETS-backed GenServer that tracks cumulative spend. `SpendingHook` implements the `CommandHook` behaviour from raxol_agent -- it runs before every command and can deny execution if limits would be exceeded.

## Agent Actions

Five actions registered via the `Raxol.Agent.Action` behaviour, callable by LLMs:

| Action | What it does |
|--------|-------------|
| `payment_get_balance` | Check wallet balance on a given chain |
| `payment_get_quote` | Get a price quote for a transfer (fees, route) |
| `payment_transfer` | Execute a payment |
| `payment_spending_status` | Current spend vs limits |
| `payment_list_history` | Transaction history for this session |

## AutoPay (Req Plugin)

`Raxol.Payments.Req.AutoPay` is a Req response step. Add it to any Req client and HTTP 402 responses get handled transparently:

```elixir
client = Req.new(base_url: "https://api.example.com")
  |> Raxol.Payments.Req.AutoPay.attach(wallet: my_wallet)

# If the server returns 402, AutoPay signs and retries automatically
{:ok, response} = Req.get(client, url: "/expensive-endpoint")
```

## Package Details

Standalone package at `packages/raxol_payments/`. Depends on `raxol_agent` at compile time only (`runtime: false`) for the Action macro and CommandHook behaviour. Runtime deps: `req`, `ex_secp256k1`, `ex_keccak`, `jason`, `decimal`.

94 tests, 0 failures.

## See Also

- [Agent Framework](AGENT_FRAMEWORK.md) -- how agents work (TEA, sessions, teams, commands)
- [Distributed Swarm](DISTRIBUTED_SWARM.md) -- multi-node agent coordination
