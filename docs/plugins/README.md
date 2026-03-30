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

## Development Workflow

### 1. Setup

```bash
git clone https://github.com/Hydepwns/raxol.git
cd raxol
mix deps.get
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test
```

### 2. Create a Plugin

Use an existing example as a starting point:

```bash
cp lib/raxol/plugins/examples/rainbow_theme_plugin.ex lib/raxol/plugins/my_plugin.ex
$EDITOR lib/raxol/plugins/my_plugin.ex
```

### 3. Test It

```bash
MIX_ENV=test mix test test/raxol/plugins/my_plugin_test.exs
```

### 4. Load and Run

```bash
iex -S mix
> Raxol.Core.Runtime.Plugins.PluginManager.load_plugin("my-plugin")
```

## Best Practices

**Performance** - Keep state lean. Use pattern matching over conditionals. Clean up resources in `terminate/2`. Cache expensive computations. Profile regularly.

**Security** - Only declare capabilities you need. Validate external input. Use sandboxed execution for untrusted code. Follow least-privilege principles.

**Maintainability** - Write tests. Document configuration and usage. Use descriptive error messages. Follow Elixir/OTP conventions. Maintain backward compatibility.

**UX** - Clear error messages. Support theming. Intuitive keyboard shortcuts. Test across terminal configurations.

## Getting Help

- Study existing plugins in `lib/raxol/plugins/examples/`
- Review test patterns in `test/raxol/plugins/`
- Report issues at [GitHub Issues](https://github.com/Hydepwns/raxol/issues)

## Contributing

1. Follow the development workflow above
2. Make sure all tests pass
3. Update docs as needed
4. Submit a PR with a clear description

## Version Compatibility

| Plugin API Version | Raxol Version | Status  |
| ------------------ | ------------- | ------- |
| 2.0                | 2.0+          | Current |

## License

Same license as Raxol. See [LICENSE](../../LICENSE).
