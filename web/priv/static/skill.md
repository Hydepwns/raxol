---
name: raxol-onboarding
description: >
  Raxol agent onboarding for external developers and AI agents.
  TRIGGER when: agent fetches raxol.io/skill.md, user asks about getting
  started with Raxol agents, user wants to add Raxol to a new project,
  or agent needs to understand Raxol capabilities for tool selection.
  DO NOT TRIGGER when: already working inside a Raxol codebase (use the
  full raxol skill instead), debugging specific Raxol internals, or
  working with other TUI frameworks.
metadata:
  author: droo
  version: "1.0.0"
  tags: raxol, agents, onboarding, mcp, elixir, otp, tui
---

# Raxol

Multi-surface runtime for Elixir on OTP. One TEA module renders to terminal, browser (LiveView), SSH, MCP, Telegram, and watch surfaces. 12 packages, 8,000+ tests.

## Quick Start

```bash
# Zero install -- try it now
ssh -p 2222 playground@raxol.io

# Or add to your project
mix new my_app && cd my_app
```

```elixir
# mix.exs deps
{:raxol, "~> 2.4"}         # Full framework
{:raxol_agent, "~> 2.4"}   # Agent framework only
```

## What You Get

- **TEA apps** -- `init/1`, `update/2`, `view/1` with OTP supervision
- **AI agents** -- TEA apps where input comes from LLMs, crash-isolated
- **Agent teams** -- Supervisor groups with coordinator/worker roles
- **6 surfaces** -- Terminal, Browser (LiveView), SSH, MCP, Telegram, Watch
- **Agent payments** -- x402, MPP, Xochi cross-chain, stealth addresses
- **MCP tools** -- Auto-derived from widget tree, 6 built-in headless tools
- **Distributed swarm** -- CRDTs, gossip/DNS/Tailscale discovery

## See Also

- `raxol` skill -- Full framework internals (TEA agents, process agents, orchestration)
- `droo-stack` -- General Elixir patterns (pipes, pattern matching, ExUnit)
- `claude-api` -- Anthropic SDK integration

## Build an Agent

```elixir
# Correct: always return {model, commands} from update/2
defmodule MyAgent do
  use Raxol.Agent

  def init(_ctx), do: %{results: []}

  def update({:agent_message, _from, {:analyze, file}}, model) do
    {model, [shell("wc -l #{file}")]}
  end

  def update({:command_result, {:shell_result, %{output: out}}}, model) do
    {%{model | results: [out | model.results]}, []}
  end

  def update(_msg, model), do: {model, []}
end

# Start it
{:ok, _} = Raxol.Agent.Session.start_link(app_module: MyAgent, id: :my_agent)
```

```elixir
# Incorrect: returning bare model crashes the runtime
def update(:some_msg, model), do: model
# Correct: always return {model, commands} tuple
def update(:some_msg, model), do: {model, []}
```

## Agent Teams

```elixir
# Correct: coordinator + workers under one supervisor
Raxol.Agent.Team.start_link(
  team_id: :review_team,
  coordinator: {CodeReviewAgent, id: :reviewer},
  workers: [{TestRunnerAgent, id: :tester}]
)
```

## Agent Commands

| Command | What It Does | Return Shape |
|---------|-------------|-------------|
| `shell("cmd")` | Port-based shell execution | `{:shell_result, %{output: str, exit_status: int}}` |
| `async(fn)` | Async with streaming callback | `{:async_result, result}` |
| `send_agent(id, payload)` | Inter-agent message via Registry | Arrives as `{:agent_message, from, payload}` |

## Agent Strategies

| Strategy | When to Use |
|----------|------------|
| `Strategy.Direct` | Sequential action execution, deterministic pipelines |
| `Strategy.ReAct` | LLM reasoning loop with tool use, autonomous agents |

## MCP Integration

```bash
# Start MCP server (stdio, ~18ms startup)
mix mcp.server
```

Six built-in tools: `raxol_start`, `raxol_screenshot`, `raxol_send_key`, `raxol_get_model`, `raxol_stop`, `raxol_list`.

```json
{
  "mcpServers": {
    "raxol": {
      "command": "mix",
      "args": ["mcp.server"],
      "cwd": "/path/to/your/raxol/app"
    }
  }
}
```

## Agent Payments (raxol_payments)

Agents that can pay for things autonomously:

| Protocol | Route | Gasless |
|----------|-------|---------|
| x402 | HTTP 402 micropayments (EIP-712/ERC-3009) | No |
| MPP | Stripe/Tempo machine payments | Yes |
| Xochi | Cross-chain intent settlement | Yes |

Spending controls: per-request/session/lifetime limits via `SpendingPolicy` + `Ledger`.

## Headless Sessions

```elixir
# Correct: start headless, interact programmatically
{:ok, session} = Raxol.Headless.start(MyApp)
html = Raxol.Headless.screenshot(session)
Raxol.Headless.send_key(session, :tab)
model = Raxol.Headless.get_model(session)
```

```elixir
# Incorrect: using string for special keys
Raxol.Headless.send_key(session, "tab")
# Correct: atoms for special keys, strings for characters
Raxol.Headless.send_key(session, :tab)
Raxol.Headless.send_key(session, "q")
```

## Common Pitfalls

| Mistake | Why It Fails | Fix |
|---------|-------------|-----|
| Returning bare `model` from `update/2` | Runtime expects `{model, commands}` tuple | Always return `{model, Command.none()}` or `{model, []}` |
| Not replying to `{:call, pid, ref, msg}` | Caller blocks until timeout | `send(pid, {:agent_reply, ref, reply})` |
| `send_agent` for sync request-reply | Creates deadlock if both agents call each other | Use async `send_agent/2`, break cycles |
| String keys for special keys in `send_key` | Sends literal character, not the key event | Use atoms: `:tab`, `:enter`, `:escape` |
| Using real LLM backends in tests | Flaky, slow, costs money | Always use `Backend.Mock` in tests |
| `view/1` returning complex tree for headless agent | Wastes cycles rendering to nothing | Return `nil` from `view/1` for headless agents |

## Packages

| Package | What It Does | Tests |
|---------|-------------|-------|
| raxol | Main runtime: TEA, rendering, layout, widgets, effects | 3,700+ |
| raxol_core | Behaviours, events, config, accessibility, plugins | 730 |
| raxol_terminal | VT100/ANSI emulation, screen buffer, termbox2 NIF | 1,928 |
| raxol_agent | AI agent framework, teams, strategies, streaming | 401 |
| raxol_mcp | MCP server, client, registry, tool derivation | 263 |
| raxol_payments | x402/MPP/Xochi, wallets, spending controls | 347 |
| raxol_sensor | Sensor fusion (zero deps) | 55 |
| raxol_liveview | LiveView bridge, TerminalBridge, TEALive | 50 |
| raxol_plugin | Plugin SDK, generator, testing utils | 50 |
| raxol_speech | TTS/STT, voice commands (Bumblebee/Whisper) | 28 |
| raxol_telegram | Telegram bot surface, per-chat sessions | 34 |
| raxol_watch | APNS/FCM push, glanceable summaries | 34 |

## Key Conventions

- All agents auto-register in `Raxol.Agent.Registry` by `:id`
- Always return `{model, commands}` from `update/2`, never bare `model`
- `view/1` returning `nil` = headless (no rendering overhead)
- Use `text("string")` not `text(content: "string")` in the View DSL
- Use style attrs (`fg: :cyan, style: [:bold]`), never raw ANSI codes
- Use `Backend.Mock` in tests, never real HTTP backends

## Links

- Docs: https://hexdocs.pm/raxol
- GitHub: https://github.com/DROOdotFOO/raxol
- Hex: https://hex.pm/packages/raxol
- Playground: https://raxol.io/playground
- SSH: `ssh -p 2222 playground@raxol.io`
- Skill (this file): https://raxol.io/skill.md
