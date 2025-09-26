# Terminal Emulation

Complete VT100/ANSI terminal emulator with modern extensions.

## Quick Start

```elixir
# Start terminal
{:ok, term} = Raxol.Terminal.start(width: 80, height: 24)

# Write text and sequences
Raxol.Terminal.write(term, "Hello, \e[32mWorld\e[0m!")
Raxol.Terminal.execute(term, "ls -la")

# Handle input
Raxol.Terminal.on_input(term, fn input ->
  IO.inspect(input, label: "Got input")
end)
```

## Architecture

The terminal emulator (`Raxol.Terminal.Emulator`) provides:
- Full VT100/ANSI compliance with xterm-256color extensions
- Sixel graphics protocol support
- UTF-8 and alternate character sets
- Hardware acceleration via NIF when available

### Core Modules

- **Emulator** (`terminal/emulator.ex`) - Main state machine
- **Parser** (`terminal/ansi/parser.ex`) - 3.3μs/op ANSI parser
- **Buffer** (`terminal/buffer/`) - Screen and scrollback management
- **Window** (`terminal/window/`) - PTY and window management

## ANSI/VT100 Support

### Escape Sequences

```elixir
# Cursor movement
"\e[H"        # Home
"\e[{n}A"     # Up n lines
"\e[{r};{c}H" # Position at row;col

# Colors (16/256/RGB)
"\e[31m"      # Red foreground
"\e[48;5;{n}m"  # 256-color background
"\e[38;2;{r};{g};{b}m" # RGB foreground

# Screen control
"\e[2J"       # Clear screen
"\e[?1049h"   # Alternate buffer
"\e[?25l"     # Hide cursor
```

### Modes

```elixir
# Set modes
Raxol.Terminal.set_mode(term, :insert_mode)
Raxol.Terminal.set_mode(term, :auto_wrap)
Raxol.Terminal.set_mode(term, :bracketed_paste)

# Private modes (DEC)
Raxol.Terminal.set_private_mode(term, 1049) # Alt buffer
Raxol.Terminal.set_private_mode(term, 2004) # Bracketed paste
```

## Buffer Management

### Screen Buffer

```elixir
# Access buffer
buffer = Raxol.Terminal.get_buffer(term)
cell = Raxol.Buffer.get_cell(buffer, row: 0, col: 0)

# Cell structure
%Cell{
  char: "A",
  fg: %Color{r: 255, g: 255, b: 255},
  bg: %Color{r: 0, g: 0, b: 0},
  attrs: [:bold, :underline]
}
```

### Scrollback

```elixir
# Configure scrollback
Raxol.Terminal.set_scrollback_limit(term, 10000)

# Navigate history
Raxol.Terminal.scroll_up(term, lines: 10)
Raxol.Terminal.scroll_to_bottom(term)

# Search
results = Raxol.Terminal.search(term, "pattern", :regex)
```

## Input Handling

### Keyboard

```elixir
# Key events
%KeyEvent{
  key: :enter,        # or "a", :f1, :arrow_up, etc
  modifiers: [:ctrl], # :shift, :alt, :meta
  raw: "\r"
}

# Custom bindings
Raxol.Terminal.bind_key(term, [:ctrl, :k], fn ->
  Raxol.Terminal.clear_line(term)
end)
```

### Mouse

```elixir
# Enable mouse tracking
Raxol.Terminal.set_mouse_mode(term, :all_events)

# Mouse events
%MouseEvent{
  type: :click,       # :drag, :scroll, :release
  button: :left,      # :middle, :right, :wheel_up
  row: 10,
  col: 20,
  modifiers: []
}
```

## Process Management

### PTY Integration

```elixir
# Spawn shell
{:ok, pty} = Raxol.Terminal.spawn_shell(term, "/bin/bash")

# Run command
{:ok, output} = Raxol.Terminal.run_command(term, "ls -la")

# Send input to process
Raxol.Terminal.send_to_pty(term, "echo hello\n")
```

### Session Management

```elixir
# Save/restore state
state = Raxol.Terminal.save_state(term)
Raxol.Terminal.restore_state(term, state)

# Multiple sessions
Raxol.Terminal.create_session(term, "work")
Raxol.Terminal.switch_session(term, "work")
```

## Graphics Support

### Sixel Protocol

```elixir
# Enable Sixel
Raxol.Terminal.enable_graphics(term, :sixel)

# Display image
image_data = File.read!("image.six")
Raxol.Terminal.write(term, image_data)
```

### Unicode & Fonts

```elixir
# Box drawing
Raxol.Terminal.write(term, "┌─┬─┐")
Raxol.Terminal.write(term, "│ │ │")
Raxol.Terminal.write(term, "└─┴─┘")

# Emoji support
Raxol.Terminal.write(term, "Status: [OK]")
```

## Performance

- **Parser**: 3.3μs per operation
- **Buffer**: O(1) cell access, lazy scrollback
- **Rendering**: Damage tracking, partial updates
- **Memory**: ~2.8MB per session baseline

## Configuration

```elixir
config :raxol, :terminal,
  default_shell: "/bin/zsh",
  scrollback_limit: 10_000,
  tab_width: 8,
  auto_wrap: true,
  mouse_tracking: :normal,
  graphics: [:sixel],
  color_mode: :true_color
```

## Testing

```elixir
# Test helpers
alias Raxol.Terminal.DriverTestHelper

# Create test terminal
{:ok, term} = DriverTestHelper.create_test_terminal()

# Simulate input
DriverTestHelper.send_keys(term, "hello\e[D\e[D")

# Assert output
assert DriverTestHelper.screen_text(term) =~ "hello"
```

## See Also

- [Architecture](ARCHITECTURE.md) - System design
- [API Reference](api-reference.md) - Complete API
- [Performance Guide](PERFORMANCE_TUNING_GUIDE.md) - Optimization