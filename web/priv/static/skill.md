# Raxol Agent Skill

> Multi-surface runtime for Elixir on OTP. One TEA module renders to terminal, browser, SSH, MCP, Telegram, and watch surfaces.

## What You Can Do With Raxol

### Build Agents
Raxol agents are TEA (The Elm Architecture) apps supervised by OTP. They crash-isolate, hot-reload, and stream from any LLM backend (Anthropic, OpenAI, Ollama, Groq, Kimi, Lumo).

```elixir
# Add to mix.exs
{:raxol_agent, "~> 2.4"}

# Define an agent
defmodule MyAgent do
  use Raxol.Agent

  def init(_ctx), do: %{results: []}

  def update({:agent_message, _from, {:analyze, file}}, model) do
    {model, [shell("wc -l #{file}")]}
  end

  def update({:command_result, {:shell_result, %{output: out}}}, model) do
    {%{model | results: [out | model.results]}, []}
  end
end

# Start it
{:ok, _} = Raxol.Agent.Session.start_link(app_module: MyAgent, id: :my_agent)
```

### Agent Teams
Coordinate multiple agents with supervisors:

```elixir
Raxol.Agent.Team.start_link(
  team_id: :review_team,
  coordinator: {CodeReviewAgent, id: :reviewer},
  workers: [{TestRunnerAgent, id: :tester}]
)
```

### Agent Payments (raxol_payments)
Agents that can pay for things autonomously:
- **x402**: HTTP 402 micropayments (Coinbase, EIP-712/ERC-3009)
- **MPP**: Stripe/Tempo machine payments
- **Xochi**: Cross-chain intent settlement (stealth addresses, PXE shielded)
- Spending controls: per-request/session/lifetime limits via SpendingPolicy + Ledger

### MCP Tools
Raxol auto-derives MCP tools from the widget tree. Each interactive widget exposes semantic actions.

```bash
# Start MCP server (stdio, ~18ms startup)
mix mcp.server
```

Six built-in tools: `raxol_start`, `raxol_screenshot`, `raxol_send_key`, `raxol_get_model`, `raxol_stop`, `raxol_list`.

### Try It Now

```bash
# SSH (zero install)
ssh -p 2222 playground@raxol.io

# Interactive playground (30 demos, 8 categories)
mix raxol.playground

# Web
# https://raxol.io/playground
```

## Architecture at a Glance

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

## Key Patterns

**TEA Model**: `init/1` -> model, `update/2` -> `{model, commands}`, `view/1` -> element tree.

**Agent Commands**:
- `shell("cmd")` -- Port-based shell execution
- `async(fn)` -- Async with streaming sender callback
- `send_agent(target, payload)` -- Inter-agent messaging via Registry

**Agent Strategies**:
- `Strategy.Direct` -- Sequential action execution
- `Strategy.ReAct` -- LLM reasoning loop with tool use

**Headless Sessions**: `Raxol.Headless.start(MyApp)` runs TEA apps without a terminal. `screenshot/1` reads the virtual buffer. `send_key/3` injects events.

**View DSL**: Use `text("string")` not `text(content: "string")`. Use style attrs (`fg: :cyan, style: [:bold]`), never raw ANSI codes.

## Links

- Docs: https://hexdocs.pm/raxol
- GitHub: https://github.com/DROOdotFOO/raxol
- Hex: https://hex.pm/packages/raxol
- Playground: https://raxol.io/playground
- SSH: `ssh -p 2222 playground@raxol.io`

## Agent Integration

To give an AI agent access to Raxol's MCP tools, add to your MCP config:

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

The agent can then start headless TEA apps, take screenshots, send keys, and read model state -- enabling full autonomous UI interaction.

---

*Made by [axol.io](https://axol.io). 8,000+ tests across 12 packages.*
