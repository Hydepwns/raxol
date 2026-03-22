# Raxol Examples

Runnable examples organized by complexity.

## Quick Start

```bash
mix run examples/getting_started/counter.exs    # Simple counter (TEA basics)
mix run examples/demo.exs                       # Live BEAM dashboard
mix run examples/apps/file_browser.exs           # File browser with tree nav
mix run examples/apps/file_browser.exs -- /path  # Browse a specific directory
```

## Directory Structure

- `core/` - Raxol.Core examples (buffer, box, renderer)
- `liveview/` - Phoenix LiveView integration
- `plugins/` - Plugin development examples
- `getting_started/` - Beginner tutorials
- `scripts/` - Quick .exs examples
- `components/` - Component demos
- `apps/` - Complete applications
- `frameworks/` - Framework integrations (Svelte, React)
- `advanced/` - Advanced patterns

## Running

```bash
# Script (.exs)
elixir examples/path/to/example.exs

# Module (.ex)
mix run examples/path/to/example.ex
```

## Related

See [documentation](../docs/) for concepts and guides.
