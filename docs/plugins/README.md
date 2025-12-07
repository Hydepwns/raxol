# Raxol Plugin Documentation

Welcome to the comprehensive documentation for developing plugins in the Raxol terminal emulator. This directory contains everything you need to create powerful, efficient, and well-tested plugins.

## Documentation

### [GUIDE.md](GUIDE.md) - Complete Development Guide
Plugin development from basics to advanced:
- Quick start with basic structure
- Lifecycle states and transitions
- Event system and commands
- Capabilities (UI, keyboard, status line)
- Performance and error handling

### [TEMPLATES.md](TEMPLATES.md) - Ready-to-Use Templates
Complete working templates:
- Basic Plugin (simple functionality)
- UI Plugin (interactive panels)
- Background Plugin (periodic tasks)
- File System Plugin (file watching)

### [TESTING.md](TESTING.md) - Testing Guide
Testing strategies and patterns:
- Unit and integration tests
- Event filtering tests
- Property-based testing
- Performance testing

## Quick Start

1. **Read the Guide**: [GUIDE.md](GUIDE.md) - Complete lifecycle and development
2. **Choose a Template**: [TEMPLATES.md](TEMPLATES.md) - Working examples
3. **Test Thoroughly**: [TESTING.md](TESTING.md) - Testing patterns

## Existing Plugin Examples

The Raxol codebase includes several fully-implemented example plugins:

### Core Examples (lib/raxol/plugins/examples/)
- **[Command Palette Plugin](../../lib/raxol/plugins/examples/command_palette_plugin.ex)**: VS Code-style command execution with fuzzy search
- **[Status Line Plugin](../../lib/raxol/plugins/examples/status_line_plugin.ex)**: System info, git status, and customizable status bar
- **[File Browser Plugin](../../lib/raxol/plugins/examples/file_browser_plugin.ex)**: Tree-style navigation with file operations
- **[Terminal Multiplexer Plugin](../../lib/raxol/plugins/examples/terminal_multiplexer_plugin.ex)**: tmux-like panes and window management
- **[Git Integration Plugin](../../lib/raxol/plugins/examples/git_integration_plugin.ex)**: Advanced git operations and visualization
- **[Rainbow Theme Plugin](../../lib/raxol/plugins/examples/rainbow_theme_plugin.ex)**: Colorful theme demonstration

## Plugin System Architecture

### Plugin System v2.0 Features
- **Hot Reload**: Update plugins without restarting the terminal
- **Dependency Management**: Version-aware dependency resolution
- **Sandboxed Execution**: Secure execution for untrusted plugins
- **Marketplace Integration**: Install and manage plugins from the official marketplace
- **Performance Monitoring**: Built-in metrics and resource isolation
- **State Persistence**: Plugin state survives hot reloads

### Core Components
- **[Plugin Manager](../../lib/raxol/plugins/plugin_system_v2.ex)**: Manages plugin lifecycle and dependencies
- **[Plugin Behaviour](../../lib/raxol/core/runtime/plugins/plugin.ex)**: Defines the interface all plugins must implement
- **[Dependency Resolver](../../lib/raxol/plugins/dependency_resolver_v2.ex)**: Resolves and validates plugin dependencies
- **[Hot Reload Manager](../../lib/raxol/plugins/hot_reload_manager.ex)**: Enables live plugin updates
- **[Marketplace Client](../../lib/raxol/plugins/marketplace_client.ex)**: Interfaces with the plugin marketplace

## Development Workflow

### 1. Development Setup
```bash
# Clone the repository
git clone https://github.com/raxol-io/raxol.git
cd raxol

# Set up dependencies
mix deps.get

# Run tests to ensure everything works
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test
```

### 2. Plugin Creation
```bash
# Create new plugin from template
cp docs/plugins/templates/basic_plugin_template.ex lib/raxol/plugins/my_plugin.ex

# Edit the plugin to implement your functionality
$EDITOR lib/raxol/plugins/my_plugin.ex
```

### 3. Testing
```bash
# Create test file
cp docs/plugins/templates/plugin_test_template.exs test/raxol/plugins/my_plugin_test.exs

# Run tests
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test test/raxol/plugins/my_plugin_test.exs
```

### 4. Integration
```bash
# Load plugin in development
iex -S mix
> Raxol.Plugins.PluginSystemV2.load_plugin("my-plugin")

# Test hot reload
> Raxol.Plugins.PluginSystemV2.hot_reload_plugin("my-plugin")
```

## Best Practices

### Performance
- Keep plugin state lean and efficient
- Use pattern matching instead of imperative conditionals
- Implement proper resource cleanup in `terminate/2`
- Cache expensive computations appropriately
- Profile plugin performance regularly

### Security
- Declare only required capabilities in manifest
- Validate all external input
- Use sandboxed execution for untrusted code
- Never expose secrets or sensitive data
- Follow least-privilege principles

### Maintainability
- Write comprehensive tests for all functionality
- Document plugin configuration and usage
- Use descriptive error messages
- Follow Elixir/OTP conventions
- Maintain backward compatibility when possible

### User Experience
- Provide clear error messages and feedback
- Support theming and customization
- Implement intuitive keyboard shortcuts
- Include helpful documentation and examples
- Test with different terminal configurations

## Community and Support

### Getting Help
- **Documentation**: This directory contains comprehensive guides
- **Examples**: Study the existing plugins in `lib/raxol/plugins/examples/`
- **Tests**: Review test patterns in `test/raxol/plugins/`
- **Issues**: Report problems at [GitHub Issues](https://github.com/raxol-io/raxol/issues)

### Contributing
1. Follow the development workflow above
2. Ensure all tests pass
3. Update documentation as needed
4. Submit a pull request with clear description
5. Participate in code review process

### Plugin Marketplace
- **Publishing**: Use `mix raxol.plugin.publish` to share your plugins
- **Discovery**: Browse available plugins at [raxol.io/plugins](https://raxol.io/plugins)
- **Installation**: Install plugins with `mix raxol.plugin.install <plugin-name>`

## Version Compatibility

| Plugin API Version | Raxol Version | Status |
|-------------------|---------------|--------|
| 2.0 | 1.5+ | Current |
| 1.0 | 1.0-1.4 | Legacy |

## License

Plugin documentation and examples are released under the same license as Raxol. See [LICENSE](../../LICENSE) for details.

---

**Happy Plugin Development!**

The Raxol plugin system is designed to be powerful, flexible, and developer-friendly. Whether you're building a simple utility or a complex integration, these docs will guide you through creating amazing terminal experiences.