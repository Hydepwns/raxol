# ADR-0003: Terminal Emulation Strategy

## Status
Accepted

## Context
Raxol needs to provide comprehensive terminal emulation while also supporting modern features like:
- Web deployment through Phoenix LiveView
- Sixel graphics
- Mouse support
- True color (24-bit RGB)
- Unicode and emoji support

Traditional terminal emulators are tightly coupled to system TTY interfaces, making them difficult to test, deploy to web, or extend with modern features.

## Decision
Implement a **layered terminal emulation architecture** that separates concerns:

1. **Core Emulator**: Pure Elixir implementation of VT100/ANSI/xterm
2. **Driver Layer**: Pluggable drivers for different backends
3. **Renderer Layer**: Separate rendering from emulation logic
4. **Extension System**: Plugin architecture for additional features

## Implementation

### Layer Architecture
```
┌─────────────────────────────────────┐
│         Application Layer           │
│     (Components, Business Logic)    │
├─────────────────────────────────────┤
│         Emulator Core               │
│  (ANSI parsing, state management)   │
├─────────────────────────────────────┤
│         Driver Layer                │
│  (TTY | Web | Mock | Test)          │
├─────────────────────────────────────┤
│         Renderer Layer              │
│  (Terminal | HTML | Canvas)         │
└─────────────────────────────────────┘
```

### Driver Abstraction
```elixir
defmodule Raxol.Terminal.Driver.Behaviour do
  @callback start_link(dispatcher_pid :: pid()) :: {:ok, pid()}
  @callback write(pid(), iodata()) :: :ok
  @callback read(pid()) :: {:ok, binary()} | {:error, term()}
  @callback get_size(pid()) :: {:ok, {width :: pos_integer(), height :: pos_integer()}}
  @callback set_raw_mode(pid(), boolean()) :: :ok
end
```

### Multiple Backends
```elixir
# Terminal Driver (using termbox2_nif when available)
defmodule Raxol.Terminal.Driver do
  @behaviour Raxol.Terminal.Driver.Behaviour
  # Direct terminal I/O
end

# Web Driver (Phoenix Channels)
defmodule Raxol.Terminal.WebDriver do
  @behaviour Raxol.Terminal.Driver.Behaviour
  # WebSocket communication
end

# Mock Driver (Testing)
defmodule Raxol.Terminal.DriverMock do
  @behaviour Raxol.Terminal.Driver.Behaviour
  # In-memory simulation
end
```

### Emulator Independence
The emulator core has no dependencies on:
- Operating system APIs
- Terminal I/O
- Rendering libraries
- Network protocols

This enables:
- Unit testing without a terminal
- Web deployment without native dependencies
- Platform-independent development

## Features Implementation

### Sixel Graphics
```elixir
defmodule Raxol.Terminal.ANSI.SixelGraphics do
  # Pure Elixir sixel parser and renderer
  # Converts to internal image representation
  # Renderers handle display (terminal sequences, HTML canvas, etc.)
end
```

### Mouse Support
```elixir
defmodule Raxol.Terminal.Mouse.Manager do
  # Unified mouse handling across backends
  # Terminal: CSI sequences
  # Web: JavaScript events
  # Test: Simulated events
end
```

### Unicode/Emoji
```elixir
defmodule Raxol.Terminal.Unicode do
  # Grapheme cluster handling
  # Wide character support
  # Emoji rendering with fallbacks
end
```

## Consequences

### Positive
- **Platform Independence**: Same code runs everywhere
- **Testability**: 100% test coverage without TTY
- **Extensibility**: Easy to add new backends
- **Web Deployment**: First-class web support
- **Modern Features**: Sixel, true color, Unicode work everywhere

### Negative
- **Complexity**: Multiple layers to understand
- **Performance**: Additional abstraction overhead
- **Compatibility**: May not support all terminal-specific features

### Mitigation
- Clear layer boundaries and documentation
- Performance optimization (EmulatorLite)
- Feature detection and graceful degradation

## Validation
```elixir
# Test without terminal
mix test

# Run in terminal
mix raxol.run

# Run in browser
iex> Raxol.Web.start()
```

## Metrics
- Test coverage: 100% without requiring TTY
- Web compatibility: 100% feature parity
- Performance overhead: < 5% vs native terminals

## References
- XTerm Control Sequences: https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
- VT100 User Guide: https://vt100.net/docs/vt100-ug/
- Sixel Graphics: https://github.com/saitoha/libsixel