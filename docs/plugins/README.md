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

The codebase includes several working examples in `lib/raxol/plugins/examples/`:

- **[Command Palette](../../lib/raxol/plugins/examples/command_palette_plugin.ex)** - VS Code-style command execution with fuzzy search
- **[Status Line](../../lib/raxol/plugins/examples/status_line_plugin.ex)** - System info, git status, customizable status bar
- **[File Browser](../../lib/raxol/plugins/examples/file_browser_plugin.ex)** - Tree-style navigation with file operations
- **[Terminal Multiplexer](../../lib/raxol/plugins/examples/terminal_multiplexer_plugin.ex)** - tmux-like panes and window management
- **[Git Integration](../../lib/raxol/plugins/examples/git_integration_plugin.ex)** - Git operations and visualization
- **[Rainbow Theme](../../lib/raxol/plugins/examples/rainbow_theme_plugin.ex)** - Theme demonstration

## Plugin System Architecture

### v2.0 Features
- Hot reload without restarting the terminal
- Version-aware dependency resolution
- Sandboxed execution for untrusted plugins
- Marketplace integration for installing and managing plugins
- Built-in performance monitoring and resource isolation
- State persistence across hot reloads

### Core Components
- **[Plugin Manager](../../lib/raxol/plugins/plugin_system_v2.ex)** - Lifecycle and dependency management
- **[Plugin Behaviour](../../lib/raxol/core/runtime/plugins/plugin.ex)** - Interface all plugins must implement
- **[Dependency Resolver](../../lib/raxol/plugins/dependency_resolver_v2.ex)** - Dependency validation
- **[Hot Reload Manager](../../lib/raxol/plugins/hot_reload_manager.ex)** - Live plugin updates
- **[Marketplace Client](../../lib/raxol/plugins/marketplace_client.ex)** - Plugin marketplace interface

## Development Workflow

### 1. Setup
```bash
git clone https://github.com/raxol-io/raxol.git
cd raxol
mix deps.get
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test
```

### 2. Create a Plugin
```bash
cp docs/plugins/templates/basic_plugin_template.ex lib/raxol/plugins/my_plugin.ex
$EDITOR lib/raxol/plugins/my_plugin.ex
```

### 3. Test It
```bash
cp docs/plugins/templates/plugin_test_template.exs test/raxol/plugins/my_plugin_test.exs
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test test/raxol/plugins/my_plugin_test.exs
```

### 4. Load and Run
```bash
iex -S mix
> Raxol.Plugins.PluginSystemV2.load_plugin("my-plugin")
> Raxol.Plugins.PluginSystemV2.hot_reload_plugin("my-plugin")
```

## Best Practices

**Performance** - Keep state lean. Use pattern matching over conditionals. Clean up resources in `terminate/2`. Cache expensive computations. Profile regularly.

**Security** - Only declare capabilities you need. Validate external input. Use sandboxed execution for untrusted code. Follow least-privilege principles.

**Maintainability** - Write tests. Document configuration and usage. Use descriptive error messages. Follow Elixir/OTP conventions. Maintain backward compatibility.

**UX** - Clear error messages. Support theming. Intuitive keyboard shortcuts. Test across terminal configurations.

## Getting Help

- Study existing plugins in `lib/raxol/plugins/examples/`
- Review test patterns in `test/raxol/plugins/`
- Report issues at [GitHub Issues](https://github.com/raxol-io/raxol/issues)

## Contributing

1. Follow the development workflow above
2. Make sure all tests pass
3. Update docs as needed
4. Submit a PR with a clear description

## Plugin Marketplace

- Publish with `mix raxol.plugin.publish`
- Browse at [raxol.io/plugins](https://raxol.io/plugins)
- Install with `mix raxol.plugin.install <plugin-name>`

## Version Compatibility

| Plugin API Version | Raxol Version | Status |
|-------------------|---------------|--------|
| 2.0 | 1.5+ | Current |
| 1.0 | 1.0-1.4 | Legacy |

## License

Same license as Raxol. See [LICENSE](../../LICENSE).
