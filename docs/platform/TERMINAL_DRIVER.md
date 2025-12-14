# Terminal Driver Architecture

Raxol uses a hybrid terminal backend approach that provides optimal cross-platform
support with automatic fallback from native NIFs to pure Elixir.

## Overview

```
+-------------------+
|   Driver.ex       |  Automatic backend selection
+-------------------+
         |
    [compile-time check: @termbox2_available]
         |
    +----+----+
    |         |
    v         v
+-------+  +-----------+
|termbox|  |IOTerminal |  Pure Elixir fallback
|2_nif  |  |(OTP 28+)  |
+-------+  +-----------+
```

## How Fallback Works

### Compile-Time Detection

At compile time, `Driver.ex` checks if the termbox2_nif module is available:

```elixir
# lib/raxol/terminal/driver.ex:25
@termbox2_available Code.ensure_loaded?(:termbox2_nif)
```

This module attribute is baked into the compiled BEAM bytecode, ensuring zero
runtime overhead for the detection.

### Runtime Backend Selection

When `Driver` initializes, it chooses the appropriate backend:

```elixir
# With termbox2_nif available (Unix/macOS):
{_result, io_terminal_state} =
  if @termbox2_available do
    {apply(:termbox2_nif, :tb_init, []), nil}
  else
    init_io_terminal()  # Falls back to pure Elixir
  end
```

All subsequent operations (getting terminal size, setting cursor, etc.) use
the same pattern:

```elixir
defp get_termbox_width do
  if @termbox2_available do
    :termbox2_nif.tb_width()
  else
    case IOTerminal.get_terminal_size() do
      {:ok, {width, _height}} -> width
      _ -> 80
    end
  end
end
```

## Platform Support Matrix

| Platform       | Primary Backend | Fallback           | Performance |
|----------------|----------------|--------------------|-------------|
| Linux          | termbox2_nif   | IOTerminal         | ~50us/frame |
| macOS          | termbox2_nif   | IOTerminal         | ~50us/frame |
| Windows 10+    | IOTerminal     | (primary)          | ~500us/frame|
| FreeBSD/OpenBSD| termbox2_nif   | IOTerminal         | ~50us/frame |
| CI/Docker      | IOTerminal     | (no TTY detection) | N/A         |

## IOTerminal (Pure Elixir Backend)

When the NIF is unavailable, `IOTerminal` provides full terminal support using:

- **OTP 28+ raw mode**: `shell:start_interactive/1` for reading keypresses
- **IO.ANSI**: Escape sequences for colors and cursor control
- **:io module**: Terminal configuration via `:io.setopts/1`

### Features Supported

| Feature              | termbox2_nif | IOTerminal |
|---------------------|--------------|------------|
| Cursor positioning  | Yes          | Yes        |
| 256-color support   | Yes          | Yes        |
| Terminal size       | Yes          | Yes        |
| Hide/show cursor    | Yes          | Yes        |
| Clear screen        | Yes          | Yes        |
| Raw key input       | Yes          | Yes*       |
| Mouse events        | Yes          | Limited**  |
| Window title        | Yes          | Yes        |

*Key input in IOTerminal uses `IO.getn/2` which may buffer differently.
**Mouse support depends on terminal emulator ANSI support.

### Example IOTerminal Usage

```elixir
# Direct IOTerminal usage (internal)
{:ok, state} = Raxol.Terminal.IOTerminal.init()

# Clear and position cursor
:ok = IOTerminal.clear_screen()
:ok = IOTerminal.set_cursor(10, 5)

# Write colored text
:ok = IOTerminal.print_string(10, 5, "Hello", 46, 0)  # Green on black

# Get terminal size
{:ok, {width, height}} = IOTerminal.get_terminal_size()

# Cleanup
:ok = IOTerminal.shutdown()
```

## TTY Detection

The driver also detects whether it's running in a real TTY:

```elixir
# From Raxol.Terminal.TerminalUtils
def real_tty? do
  case :io.getopts(:standard_io) do
    {:ok, opts} -> Keyword.get(opts, :terminal, false)
    _ -> false
  end
end
```

This prevents terminal initialization in:
- CI/CD pipelines
- Docker containers without TTY
- IEx sessions piped from scripts

## Graceful Degradation

When no TTY is available, features degrade gracefully:

```elixir
case {Mix.env(), real_tty?()} do
  {:test, _} ->
    # Test mode - use mock terminal
    {:ok, state}

  {_, true} ->
    # Real TTY - initialize backend
    init_terminal_backend()

  {_, false} ->
    # No TTY - log warning, continue without terminal
    Log.warning("Not attached to a TTY. Terminal features disabled.")
    {:ok, state}
end
```

## Forcing Backend Selection

For testing or specific use cases, you can force a backend:

```elixir
# In config/test.exs
config :raxol, :terminal_backend, :io_terminal

# In runtime code
Application.put_env(:raxol, :terminal_backend, :io_terminal)
```

## Troubleshooting

### NIF Not Loading

If termbox2_nif fails to load:

1. Check compilation requirements:
   ```bash
   gcc --version  # Must be installed
   make --version # Must be installed
   ```

2. Verify TMPDIR is set (macOS nix-shell issue):
   ```bash
   export TMPDIR=/tmp
   mix compile
   ```

3. Check NIF build output:
   ```bash
   ls -la _build/dev/lib/termbox2_nif/priv/
   # Should contain termbox2_nif.so
   ```

### IOTerminal Issues

If IOTerminal has problems:

1. **No color output**: Ensure ANSI is enabled:
   ```elixir
   Application.put_env(:elixir, :ansi_enabled, true)
   ```

2. **Windows issues**: Ensure Windows 10+ and VT100 support enabled:
   - Run `reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1`

3. **Raw mode not working**: Requires OTP 28+. Check version:
   ```bash
   elixir --version
   ```

### Checking Current Backend

```elixir
# In IEx
iex> Code.ensure_loaded?(:termbox2_nif)
true  # Using NIF
false # Using IOTerminal

# At runtime
iex> Raxol.Terminal.Driver.backend()
:termbox2_nif
# or
:io_terminal
```

## Performance Considerations

| Operation          | termbox2_nif | IOTerminal | Notes |
|--------------------|--------------|------------|-------|
| Initialize         | ~1ms         | ~2ms       |       |
| Set cell           | ~1us         | ~10us      | Per cell |
| Full redraw (80x24)| ~50us        | ~500us     | 1920 cells |
| Get terminal size  | ~1us         | ~5us       |       |
| Read keypress      | ~1us         | ~10us      |       |

For most applications, IOTerminal performance is sufficient. The difference
is only noticeable with:
- Very high refresh rates (>30 fps)
- Large terminal sizes (>200x60)
- Intensive cell-by-cell updates

## Related Documentation

- [Windows Platform Support](./WINDOWS.md)
- [Architecture Overview](../core/ARCHITECTURE.md)
- [Performance Targets](../bench/PERFORMANCE_TARGETS.md)
