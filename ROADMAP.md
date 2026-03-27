# Raxol Roadmap

Terminal built for your Gundam. AGI-ready terminal framework for Elixir.

## Current Version: v2.2.0

### What's Done

- **Phase 1: Core Runtime** -- TEA architecture, TTY detection, ANSI input/output, render pipeline end-to-end
- **Phase 2: Widget Library** -- 23 widgets with tests and examples (exceeds original 15-widget target)
- **Phase 3: Framework Polish** -- Focus management, W3C-style event capture/bubble, style inheritance, terminal compatibility (color downsampling, Unicode width, synchronized output)
- **Phase 4: OTP Differentiators** -- Process-per-component crash isolation, hot code reload, LiveView bridge, SSH app serving
- **Phase 5.1: Hex Package** -- `mix hex.build` succeeds, optional deps trimmed, NIF compiles via elixir_make
- **Phase 5.2: Phoenix Optional** -- LiveView/web code wrapped in `Code.ensure_loaded?` guards; pure-terminal apps no longer require Phoenix
- **Phase 5.3: Developer Tooling** -- `mix raxol.new` generator (4 templates, 8 flags, interactive mode, CI, mise), `mix raxol.gen.component` scaffolder, 20 mix tasks
- **Phase 5.4: Documentation** -- Quickstart, widget gallery, architecture overview, 5 cookbook guides (TEA patterns, SSH deployment, theming, LiveView, performance)
- **Phase 5.5: Tech Debt Cleanup** -- Removed ~7,300 LOC dead code (CQRS/EventSourcing, Pipeline stubs), ETS-backed GenServers where appropriate
- **Phase 5.6: Showcase** -- Flagship demo (live BEAM dashboard), file browser example, benchmark suite vs Ratatui/Bubble Tea/Textual
- **Phase 5.7: Session Recording & Replay** -- Asciinema v2 format (.cast), `mix raxol.record` / `mix raxol.replay`, streaming player with pause/seek/speed
- **Phase 6.0: Streaming Charts** -- 7 chart modules (LineChart, ScatterChart, BarChart, Heatmap, BrailleCanvas, ChartUtils, ViewBridge), multi-series, braille rendering
- **Phase 6.1: Playground** -- Interactive widget catalog (23 demos across 7 categories), terminal app + mix task, search/filter/help overlay
- **Phase 6.2: Web Refactor** -- All LiveViews use Playground.Catalog, TEALive lifecycle integration
- **Phase 6.3: SSH Playground** -- `mix raxol.playground --ssh`, connection tracking, Fly.io TCP service
- **Time-Travel Debugging** -- Snapshot every update/2 cycle, cursor navigation, restore, export/import. Zero cost when disabled
- **Agent Framework** -- TEA-based AI agents with OTP supervision, inter-agent messaging, coordinator/worker teams, shell/async commands
- **Sensor Fusion HUD** -- Sensor behaviour, polling feeds, weighted averaging, threshold alerts, gauge/sparkline/threat/minimap widgets
- **Distributed Swarm** -- CRDTs (LWW registers, OR-sets), node monitoring, seniority-based topology election, tactical overlay sync
- **Self-Evolving Interface** -- Behavior tracking, rule-based layout recommendations, animated transitions, feedback loop
- **AI Cockpit + Streaming** -- Real AI agents analyzing codebases in multi-pane terminal dashboard. Backend.HTTP streaming (SSE) for Anthropic/OpenAI/Ollama. Pilot takeover for follow-up questions. Free tier via LLM7.io (no API key). Mock fallback for offline use.
- **libcluster Discovery** -- Automatic node discovery for Swarm via libcluster (optional dep). Strategy presets: gossip (LAN multicast), epmd (static hosts), dns (Fly.io/K8s), tailscale (mesh). NodeMonitor events auto-wire to Topology (elections) and TacticalOverlay (peer sync).
- **Tailscale Strategy** -- Custom libcluster strategy (`Raxol.Swarm.Strategy.Tailscale`). Polls `tailscale status --json`, filters by tag (ACL-gated membership), constructs BEAM node names from Tailscale IPs or MagicDNS. Zero-config encrypted mesh for multi-node swarm.

---

## Next Up

### Ship It

| Task | Description | Effort |
|------|-------------|--------|
| Publish to Hex | `mix hex.publish` -- build succeeds, docs clean, zero warnings | Small |

### AI Backend Providers

Supported now:
- **Mock** (default) -- instant offline demo, no API key
- **Proton Lumo** (`PROTON_UID=... PROTON_ACCESS_TOKEN=...`) -- zero-access encrypted AI, full U2L encryption via `Backend.Lumo`
- **Proton Lumo via lumo-tamer** (`LUMO_TAMER_URL=http://localhost:3000`) -- OpenAI-compatible proxy fallback
- **Kimi K2.5** (`KIMI_API_KEY=...`) -- Moonshot AI, $0.60/M input, 256K context, named `:kimi` provider
- **LLM7.io** (`FREE_AI=true`) -- free, OpenAI-compatible, no key needed, 40 req/min
- **Ollama** (`OLLAMA_MODEL=...`) -- free local inference, OpenAI-compatible
- **Groq** (`AI_API_KEY=... AI_BASE_URL=https://api.groq.com/openai`) -- fast free tier
- **OpenAI** (`AI_API_KEY=...`) -- GPT-4o-mini and up
- **Anthropic** (`ANTHROPIC_API_KEY=...`) -- Claude Haiku/Sonnet/Opus

Future providers:
- **LocalAI** -- self-hosted OpenAI-compatible (similar to Ollama)

### Longer Term

- Nx-backed layout learning (replace rule engine with trained model)
- Multi-node cockpit (swarm coordination across physical terminals)
- Plugin marketplace
- VS Code extension for component previews
- Burrito packaging (single standalone binary)

---

## Contributing

Want to help? See [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Versioning

- **Minor** (2.x.0): New features, framework additions
- **Patch** (2.0.x): Bug fixes, performance improvements
- **Major** (3.0.0): Breaking API changes, architectural shifts
