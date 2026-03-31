# Plugin Documentation

This directory covers plugin development for the Raxol terminal emulator.

## Guides

### [GUIDE.md](GUIDE.md) - Development Guide

Plugin development from basics to advanced: quick start, lifecycle states and transitions, event system and commands, capabilities (UI, keyboard, status line), performance, and error handling.

### [TEMPLATES.md](TEMPLATES.md) - Templates

Working templates for common plugin types: basic, UI (interactive panels), background (periodic tasks), and file system (file watching).

### [TESTING.md](TESTING.md) - Testing Guide

Testing strategies: unit and integration tests, event filtering tests, property-based testing, performance testing.

## Quick Start

1. Read [GUIDE.md](GUIDE.md) for the full lifecycle and development model
2. Pick a template from [TEMPLATES.md](TEMPLATES.md)
3. Write tests using patterns from [TESTING.md](TESTING.md)

## Example Plugins

- **[Spotify Plugin](examples/SPOTIFY.md)** - Sample plugin with OAuth, state management, and API integration

## Plugin System Architecture

### Core Components

- **[Plugin Manager](../../lib/raxol/core/runtime/plugins/plugin_manager.ex)** - Lifecycle and dependency management
- **[Plugin Behaviour](../../lib/raxol/core/runtime/plugins/plugin.ex)** - Interface all plugins must implement
- **[Plugin Reloader](../../lib/raxol/core/runtime/plugins/plugin_reloader.ex)** - Live plugin updates
- **[Plugin Registry](../../lib/raxol/core/runtime/plugins/plugin_registry.ex)** - Plugin registration and lookup

## Create a Plugin

```bash
cp lib/raxol/plugins/examples/rainbow_theme_plugin.ex lib/raxol/plugins/my_plugin.ex
MIX_ENV=test mix test test/raxol/plugins/my_plugin_test.exs
```

## Further Reading

- Study existing plugins in `lib/raxol/plugins/examples/`
- Review test patterns in `test/raxol/plugins/`
