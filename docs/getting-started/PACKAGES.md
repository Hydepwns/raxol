# Package Guide

Raxol is split into focused packages you can mix and match. Start with the core and add features as you need them.

## Available Packages

### raxol_core

Buffer primitives and terminal rendering core. Zero dependencies, lightweight (< 100KB).

```elixir
{:raxol_core, "~> 2.0"}
```

Use when you're building CLI tools, want zero dependencies, or only need buffer operations.

Includes buffer operations, box drawing, the style system, and the renderer. Does not include LiveView integration, the plugin system, or web rendering.

---

### raxol_liveview

Phoenix LiveView integration for browser-based terminal rendering.

```elixir
{:raxol_core, "~> 2.0"},
{:raxol_liveview, "~> 2.0"}
```

Use when you're building web applications with terminal UI in the browser.

Includes TerminalComponent for LiveView, buffer-to-HTML conversion, 5 built-in themes (Nord, Dracula, Solarized, Monokai), keyboard/mouse event handling, and CSS styling.

Requires raxol_core and phoenix_live_view (~> 0.20 or ~> 1.0).

---

### raxol_plugin

Plugin system for extensible terminal applications.

```elixir
{:raxol_core, "~> 2.0"},
{:raxol_plugin, "~> 2.0"}
```

Use when you need runtime plugin loading, modular architecture, or third-party integrations.

Includes plugin lifecycle management, hot reloading, and plugin discovery. Requires raxol_core.

---

### raxol (full framework)

Everything in one package. Not yet published.

```elixir
{:raxol, "~> 2.0"}  # Coming soon
```

Includes all of the above plus enterprise features.

---

## Comparison

| Feature | raxol_core | raxol_liveview | raxol_plugin | raxol (full) |
|---------|-----------|---------------|-------------|-------------|
| **Size** | ~100KB | ~500KB | ~200KB | ~1MB |
| **Dependencies** | None | phoenix_live_view | raxol_core | All above |
| **Buffer Operations** | yes | yes | yes | yes |
| **LiveView Component** | no | yes | no | yes |
| **Plugin System** | no | no | yes | yes |
| **Use Case** | CLI tools | Web terminals | Extensible apps | Full framework |

## Migration Paths

### CLI Tools (minimal)

```elixir
def deps do
  [{:raxol_core, "~> 2.0"}]
end
```

```elixir
alias Raxol.Core.{Buffer, Box}

Buffer.create_blank_buffer(80, 24)
|> Box.draw_box(0, 0, 80, 24, :single)
|> Buffer.write_at(10, 5, "Hello, CLI!")
|> Buffer.to_string()
|> IO.puts()
```

### Web Integration

```elixir
def deps do
  [
    {:raxol_core, "~> 2.0"},
    {:raxol_liveview, "~> 2.0"}
  ]
end
```

No code changes needed to existing buffer logic -- just add the LiveView component. See [LiveView Integration Cookbook](../cookbook/LIVEVIEW_INTEGRATION.md).

### Extensible Architecture

```elixir
def deps do
  [
    {:raxol_core, "~> 2.0"},
    {:raxol_plugin, "~> 2.0"}
  ]
end
```

Existing code continues to work. Add plugins incrementally. See `examples/plugins/` for details.

---

## Upgrading Between Packages

Adding a new package never requires changes to existing code. The APIs are additive.

```elixir
# Start with core
{:raxol_core, "~> 2.0"}

# Add LiveView later
{:raxol_core, "~> 2.0"},
{:raxol_liveview, "~> 2.0"}

# Add plugins later
{:raxol_core, "~> 2.0"},
{:raxol_liveview, "~> 2.0"},
{:raxol_plugin, "~> 2.0"}
```

All packages share the same version numbering and are tested together.

---

## FAQ

**Do I need all packages?** No. Start with raxol_core and add packages as needed.

**Can I switch packages later?** Yes. All packages share the same core API. You can add or remove packages without rewriting code.

**Which package should I start with?** Building a CLI? raxol_core. Building a web app? raxol_core + raxol_liveview. Need plugins? raxol_core + raxol_plugin.

---

## More Info

- [Quickstart Guide](./QUICKSTART.md) - 5/10/15 minute tutorials
- [Core Concepts](./CORE_CONCEPTS.md) - Buffers and rendering
- [Migration Guide](./MIGRATION_FROM_DIY.md) - Migrating from custom code
- [API Reference](../core/BUFFER_API.md) - Complete API docs
