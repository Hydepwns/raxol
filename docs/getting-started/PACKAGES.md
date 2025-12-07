# Package Guide

> [Documentation](../README.md) > [Getting Started](QUICKSTART.md) > Packages

Modular architecture for incremental adoption. Choose the packages you need.

## Overview

Raxol is designed as a set of focused, independently releasable packages that you can mix and match based on your needs. Start with the minimal core and add features incrementally.

## Available Packages

### [raxol_core](../../apps/raxol_core/README.md)
Buffer primitives and terminal rendering core. Zero dependencies, lightweight (< 100KB).

```elixir
{:raxol_core, "~> 2.0"}
```

**Use when:**
- Building CLI tools
- Need minimal footprint
- Want zero dependencies
- Terminal buffer operations only

**Includes:**
- Buffer operations (create, write, read, clear, resize)
- Box drawing (single, double, rounded, heavy, dashed)
- Style system (colors, bold, italic, underline)
- Renderer (string output, diff rendering)

**Does NOT include:**
- Phoenix LiveView integration
- Plugin system
- Web rendering
- Enterprise features

---

### [raxol_liveview](../../apps/raxol_liveview/README.md)
Phoenix LiveView integration for browser-based terminal rendering.

```elixir
{:raxol_core, "~> 2.0"},
{:raxol_liveview, "~> 2.0"}
```

**Use when:**
- Building web applications
- Want terminal UI in browser
- Need Phoenix LiveView integration
- Require real-time updates

**Includes:**
- TerminalComponent for LiveView
- Buffer to HTML conversion
- 5 built-in themes (Nord, Dracula, Solarized, Monokai)
- Keyboard and mouse event handling
- CSS styling and theming

**Requires:**
- raxol_core
- phoenix_live_view (~> 0.20 or ~> 1.0)

---

### [raxol_plugin](../../apps/raxol_plugin/README.md)
Plugin system for extensible terminal applications.

```elixir
{:raxol_core, "~> 2.0"},
{:raxol_plugin, "~> 2.0"}
```

**Use when:**
- Building extensible applications
- Need runtime plugin loading
- Want modular architecture
- Third-party integrations

**Includes:**
- Plugin lifecycle management
- Hot reloading support
- Plugin discovery
- Example plugins (Spotify integration)

**Requires:**
- raxol_core

---

### raxol (Full Framework)
Complete terminal framework with all features. Coming soon.

```elixir
{:raxol, "~> 2.0"}  # Coming soon
```

**Use when:**
- Want all features
- Building full terminal IDE
- Need enterprise capabilities
- Don't want to manage multiple packages

**Includes:**
- All of raxol_core
- All of raxol_liveview
- All of raxol_plugin
- Enterprise features (audit logging, encryption, SAML/OIDC)
- Advanced graphics (Sixel support)
- Session continuity
- Real-time collaboration

---

## Package Comparison

| Feature | raxol_core | raxol_liveview | raxol_plugin | raxol (full) |
|---------|-----------|---------------|-------------|-------------|
| **Size** | ~100KB | ~500KB | ~200KB | ~1MB |
| **Dependencies** | None | phoenix_live_view | raxol_core | All above |
| **Buffer Operations** | ✅ | ✅ | ✅ | ✅ |
| **Box Drawing** | ✅ | ✅ | ✅ | ✅ |
| **Style System** | ✅ | ✅ | ✅ | ✅ |
| **LiveView Component** | ❌ | ✅ | ❌ | ✅ |
| **Web Themes** | ❌ | ✅ | ❌ | ✅ |
| **Plugin System** | ❌ | ❌ | ✅ | ✅ |
| **Enterprise Features** | ❌ | ❌ | ❌ | ✅ |
| **Use Case** | CLI tools | Web terminals | Extensible apps | Full framework |

## Migration Paths

### Path 1: Minimal (CLI Tools)

Start with just terminal buffers and rendering.

```elixir
# mix.exs
def deps do
  [{:raxol_core, "~> 2.0"}]
end
```

**Example:**
```elixir
alias Raxol.Core.{Buffer, Box}

Buffer.create_blank_buffer(80, 24)
|> Box.draw_box(0, 0, 80, 24, :single)
|> Buffer.write_at(10, 5, "Hello, CLI!")
|> Buffer.to_string()
|> IO.puts()
```

---

### Path 2: Web Integration

Add browser-based terminal rendering to your Phoenix app.

```elixir
# mix.exs
def deps do
  [
    {:raxol_core, "~> 2.0"},
    {:raxol_liveview, "~> 2.0"}
  ]
end
```

**Example:**
```elixir
defmodule MyAppWeb.TerminalLive do
  use MyAppWeb, :live_view

  def render(assigns) do
    ~H"""
    <.live_component
      module={Raxol.LiveView.TerminalComponent}
      id="terminal"
      buffer={@buffer}
      theme={:nord}
    />
    """
  end
end
```

See [LiveView Integration Cookbook](../cookbook/LIVEVIEW_INTEGRATION.md) for complete guide.

---

### Path 3: Extensible Architecture

Build plugin-based terminal applications.

```elixir
# mix.exs
def deps do
  [
    {:raxol_core, "~> 2.0"},
    {:raxol_plugin, "~> 2.0"}
  ]
end
```

**Example:**
```elixir
# Load and use plugins
Raxol.Plugin.Runtime.load_plugin(MyApp.SpotifyPlugin)
Raxol.Plugin.Runtime.execute_command("spotify:play")
```

See [Plugin Development Guide](../plugins/PLUGIN_DEVELOPMENT_GUIDE.md) for details.

---

### Path 4: Full Framework

Get everything in one package (coming soon).

```elixir
# mix.exs
def deps do
  [{:raxol, "~> 2.0"}]  # Coming soon
end
```

Includes all features from all packages plus enterprise capabilities.

---

## Installation Guide

### Step 1: Choose Your Packages

Based on your needs:
- **CLI tool?** → raxol_core only
- **Web terminal?** → raxol_core + raxol_liveview
- **Extensible app?** → raxol_core + raxol_plugin
- **Everything?** → raxol (when available)

### Step 2: Add to mix.exs

```elixir
# mix.exs
def deps do
  [
    # Choose your packages
    {:raxol_core, "~> 2.0"},
    {:raxol_liveview, "~> 2.0"},  # Optional
    {:raxol_plugin, "~> 2.0"}     # Optional
  ]
end
```

### Step 3: Fetch Dependencies

```bash
mix deps.get
```

### Step 4: Start Building

See respective documentation for each package:
- [Quickstart Guide](./QUICKSTART.md) - Get started quickly
- [Core Concepts](./CORE_CONCEPTS.md) - Understand the architecture
- [Migration Guide](./MIGRATION_FROM_DIY.md) - Migrate existing code

---

## Upgrading Between Packages

### Adding LiveView Support

Already using raxol_core and want to add web rendering?

```elixir
# Before
{:raxol_core, "~> 2.0"}

# After
{:raxol_core, "~> 2.0"},
{:raxol_liveview, "~> 2.0"}
```

No code changes needed to existing buffer logic. Just add LiveView component.

### Adding Plugin Support

```elixir
# Before
{:raxol_core, "~> 2.0"}

# After
{:raxol_core, "~> 2.0"},
{:raxol_plugin, "~> 2.0"}
```

Existing code continues to work. Add plugins incrementally.

### Upgrading to Full Framework

```elixir
# Before
{:raxol_core, "~> 2.0"},
{:raxol_liveview, "~> 2.0"},
{:raxol_plugin, "~> 2.0"}

# After
{:raxol, "~> 2.0"}  # Coming soon
```

All packages included, no API changes.

---

## Performance Considerations

### Package Overhead

| Package | Compile Time | Runtime Memory | Load Time |
|---------|-------------|----------------|-----------|
| raxol_core | ~5s | < 2MB | < 10ms |
| raxol_liveview | ~10s | ~5MB | ~50ms |
| raxol_plugin | ~8s | ~3MB | ~30ms |
| raxol (full) | ~20s | ~10MB | ~100ms |

*Measured on M1 Mac, cold start*

### Optimization Tips

1. **Use raxol_core only** if you don't need web/plugins (fastest)
2. **Lazy load plugins** to reduce initial startup time
3. **Configure runtime: false** for testing/docs (reduces deps)
4. **Tree shaking** - Only import what you use

---

## Package Development Status

### Current Status (October 2025)

| Package | Status | Version | Hex.pm | Documentation |
|---------|--------|---------|--------|--------------|
| raxol_core | ✅ Ready | 2.0.0 | Ready | ✅ Complete |
| raxol_liveview | ✅ Ready | 2.0.0 | Ready | ✅ Complete |
| raxol_plugin | ✅ Ready | 2.0.0 | Ready | ✅ Complete |
| raxol | 🟡 Planned | - | - | Pending |

### Publishing Timeline

All packages are ready for Hex.pm publication:
- raxol_core: Independent, zero deps
- raxol_liveview: Depends on raxol_core
- raxol_plugin: Depends on raxol_core

**Next Steps:**
1. Final review of package.exs files
2. Verify hex.pm metadata
3. Coordinate release versions
4. Publish to Hex.pm

---

## Getting Help

### Package-Specific Questions

- **raxol_core**: [Buffer API Reference](../core/BUFFER_API.md)
- **raxol_liveview**: [LiveView Integration](../cookbook/LIVEVIEW_INTEGRATION.md)
- **raxol_plugin**: [Plugin Development](../plugins/PLUGIN_DEVELOPMENT_GUIDE.md)

### General Support

- [GitHub Issues](https://github.com/Hydepwns/raxol/issues) - Bug reports and features
- [Documentation](../README.md) - Complete documentation index
- [Examples](../../examples/README.md) - Working code examples

---

## Frequently Asked Questions

### Do I need all packages?

No! Start with raxol_core and add packages as needed. They're designed for incremental adoption.

### Can I switch packages later?

Yes. All packages share the same core API. You can add or remove packages without rewriting code.

### What's the difference between raxol_liveview and raxol_web?

raxol_liveview is the new name (v2.0+). raxol_web was the v1.x name. They're the same functionality, just renamed for clarity.

### Which package should I start with?

- Building a CLI? → raxol_core
- Building a web app? → raxol_core + raxol_liveview
- Need plugins? → raxol_core + raxol_plugin
- Want everything? → Wait for raxol (full) or use all packages

### Are there version compatibility issues?

No. All packages use the same version numbering and are tested together. raxol_core 2.0 works with raxol_liveview 2.0 and raxol_plugin 2.0.

### Can I use runtime: false?

Yes! Use `{:raxol_core, "~> 2.0", runtime: false}` for:
- Documentation generation
- Testing helpers
- UI components without terminal emulator

See [README](../../README.md#components-only-mode) for details.

---

## Additional Resources

- **[Quickstart Guide](./QUICKSTART.md)** - 5/10/15 minute tutorials
- **[Core Concepts](./CORE_CONCEPTS.md)** - Understand buffers and rendering
- **[Migration Guide](./MIGRATION_FROM_DIY.md)** - Migrate from custom code
- **[API Reference](../core/BUFFER_API.md)** - Complete API documentation
- **[Cookbook](../cookbook/README.md)** - Practical recipes and patterns

---

**Ready to get started?** Choose your package(s) above and follow the [Quickstart Guide](./QUICKSTART.md).
