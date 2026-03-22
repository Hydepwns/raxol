# Raxol Roadmap

Planned features and direction for Raxol.

## Current Version: v2.2.0

### What's Done

- **Phase 1: Core Runtime** -- TEA architecture, TTY detection, ANSI input/output, render pipeline end-to-end
- **Phase 2: Widget Library** -- 23 widgets with tests and examples (exceeds original 15-widget target)
- **Phase 3: Framework Polish** -- Focus management, W3C-style event capture/bubble, style inheritance, terminal compatibility (color downsampling, Unicode width, synchronized output)
- **Phase 4: OTP Differentiators** -- Process-per-component crash isolation, hot code reload, LiveView bridge, SSH app serving
- **Phase 5.1: Hex Package** -- `mix hex.build` succeeds, optional deps trimmed, NIF compiles via elixir_make

### Known Tech Debt

- CQRS/EventSourcing entangled with terminal core (too coupled to remove without core rewrite)
- Phoenix is a required dep (used in 24 files for LiveView bridge) -- should be optional for pure-terminal users
- Render pipeline has two paths: Rendering.Engine (live) and Pipeline GenServer (stage 5 stubs)
- 27% of core modules are GenServers; many could be pure functions + ETS

---

## Next Up

### Ecosystem & Adoption

These are the highest-impact items for getting real users.

| Task | Description | Effort |
|------|-------------|--------|
| `mix raxol.new` generator | Scaffold a working TEA app with one command | Medium |
| HexDocs | Widget gallery, architecture overview, TEA tutorial | Medium |
| Make Phoenix optional | Wrap LiveView/web code in `Code.ensure_loaded?` guards | Large |
| Publish to Hex | `mix hex.publish` once docs and deps are clean | Small |

### Developer Experience

| Task | Description | Effort |
|------|-------------|--------|
| Simplify state | Convert unnecessary GenServers to pure functions + ETS | Large |
| Fuzzy command matching | Suggest corrections for mix task typos | Small |
| Error experience | Wire up error suggestions to terminal output | Small |
| Debugging guide | Document production debugging workflow | Small |

### Framework Improvements

| Task | Description | Effort |
|------|-------------|--------|
| Unify theme system | Single source of truth for terminal + LiveView themes | Medium |
| File browser example | End-to-end app using Tree + Viewport + Modal widgets | Medium |
| Render pipeline cleanup | Remove Pipeline GenServer stubs or wire stage 5 | Medium |
| CQRS decoupling | Untangle EventSourcing from terminal core | Large |

### Longer Term

- Benchmark suite comparing against Ratatui/Bubble Tea/Textual
- VS Code extension for component previews
- Plugin marketplace
- Multi-session collaboration (CRDT-based state sync)

---

## Contributing

Want to help? See [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Version Naming

- **Minor versions** (2.x.0): New features, framework additions
- **Patch versions** (2.0.x): Bug fixes, performance improvements
- **Major versions** (3.0.0): Breaking API changes, architectural shifts

## Timeline

This roadmap is aspirational. Actual release dates depend on community contributions, prioritization, and available time.
