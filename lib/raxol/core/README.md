# Raxol Core Subsystem

- Coordinates application lifecycle, events, plugins, and core runtime logic.

## Key Modules

- `Runtime.Application` — Main app behaviour (init, update, view, subscriptions)
- `Events.Manager` — Event registration, dispatch, and subscription
- `Runtime.Plugins.Manager` — Plugin discovery, loading, lifecycle, dependencies
- `ColorSystem` — Centralized color/theme management
- `UXRefinement` — Focus, keyboard navigation, accessibility, hints

## Extension Points

- Behaviours: `Runtime.Application`, `Runtime.EventSource`, `Plugins.Plugin`, `Plugins.Loader.Behaviour`, `Plugins.LifecycleHelper.Behaviour`
- Public APIs: `Runtime.Plugins.API`, `Events.Subscription`

## References

- See [ARCHITECTURE.md](../../../docs/ARCHITECTURE.md) for system overview
- See module docs for implementation details
