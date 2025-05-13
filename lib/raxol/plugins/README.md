# Raxol Plugins Subsystem

- Provides modular, extensible plugins for application features and integration.

## Key Modules

- `plugin` — Plugin behaviour and lifecycle
- `plugin_manager` — Plugin discovery, loading, and management
- `lifecycle` — Plugin lifecycle events and transitions
- `event_handler` — Plugin event handling and dispatch
- `theme_plugin` — Theme extension via plugins

## Extension Points

- Behaviours: `plugin`
- Public APIs: `plugin_manager`, `event_handler`, `theme_plugin`

## References

- See [ARCHITECTURE.md](../../../docs/ARCHITECTURE.md) for system overview
- See module docs for implementation details
