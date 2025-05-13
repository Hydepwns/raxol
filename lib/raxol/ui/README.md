# Raxol UI Subsystem

- Provides reusable components, layout, theming, and rendering for terminal UIs.

## Key Modules

- `components.base` — Base component behaviour and lifecycle
- `layout` — Panels, grids, tables, and containers for UI structure
- `renderer` — Renders component trees to terminal output
- `theming.theme` — Theme definition and management
- `theming.colors` — UI color utilities and palette

## Extension Points

- Behaviours: `components.base`, `theming.theme_behaviour`
- Public APIs: `renderer`, `theming.theme`, `theming.colors`

## References

- See [ARCHITECTURE.md](../../../docs/ARCHITECTURE.md) for system overview
- See module docs for implementation details
