# Raxol Roadmap

Planned features and direction for Raxol.

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

---

## Next Up

### Ship It

| Task | Description | Effort |
|------|-------------|--------|
| Publish to Hex | `mix hex.publish` -- build succeeds, docs clean, zero warnings | Small |

### Longer Term

- VS Code extension for component previews
- Plugin marketplace
- Session recording & replay (see IDEAS.md)
- Time-travel debugging (see IDEAS.md)
- Collaborative sessions (see IDEAS.md)

---

## Contributing

Want to help? See [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Versioning

- **Minor** (2.x.0): New features, framework additions
- **Patch** (2.0.x): Bug fixes, performance improvements
- **Major** (3.0.0): Breaking API changes, architectural shifts
