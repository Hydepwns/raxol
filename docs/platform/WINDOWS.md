# Windows Platform Support

Raxol provides full Windows support through a pure Elixir terminal driver, delivering consistent functionality across all platforms.

## Overview

**Status**: ✅ Fully Supported (v1.7.0+)
**Backend**: Pure Elixir (IOTerminal) using OTP 28+ raw mode
**Requirements**: Windows 10+ with VT100 terminal emulation
**Performance**: ~500μs per frame (adequate for 60fps applications)

## How It Works

Raxol automatically selects the appropriate terminal backend:

- **Unix/macOS**: Uses native termbox2 NIF for optimal performance (~50μs/frame)
- **Windows**: Uses pure Elixir IOTerminal driver (~500μs/frame)

The selection happens transparently at runtime - no configuration needed.

## Requirements

### Operating System
- **Windows 10 or later** (with VT100 support)
- Windows Terminal (recommended) or Windows Console Host
- PowerShell 7+ or Windows PowerShell 5.1+

### Elixir/Erlang
- **Erlang/OTP 28+** (for raw terminal mode support)
- **Elixir 1.17+**

### Terminal Emulation
Windows 10+ includes built-in VT100/ANSI escape sequence support. This is enabled by default in:
- Windows Terminal
- PowerShell
- Command Prompt (cmd.exe)

## Installation

Standard installation works on Windows without additional setup:

```powershell
# Add to mix.exs
{:raxol, "~> 1.7"}

# Install dependencies
mix deps.get

# Compile (NIF compilation skipped automatically on Windows)
mix compile
```

## Verification

Verify Windows support is working:

```elixir
# Check backend in use
iex> Code.ensure_loaded?(Raxol.Terminal.IOTerminal)
true

iex> Code.ensure_loaded?(:termbox2_nif)
false  # Expected on Windows

# Test terminal operations
iex> alias Raxol.Terminal.IOTerminal
iex> {:ok, state} = IOTerminal.init()
iex> IOTerminal.clear_screen()
:ok
iex> IOTerminal.set_cursor(10, 5)
:ok
iex> IOTerminal.shutdown()
:ok
```

## Features

All Raxol features work identically on Windows:

✅ **Terminal Operations**
- Screen clearing, cursor positioning
- Cell and string rendering
- Unicode character support
- 256-color ANSI palette

✅ **Input Handling**
- Raw keyboard input (OTP 28+ raw mode)
- Mouse events
- Special keys (arrows, function keys, etc.)

✅ **Advanced Features**
- Multi-framework UI (React, Svelte, LiveView, HEEx)
- Component library
- Theme system
- Event handling
- State management

## Performance

| Operation | Windows (IOTerminal) | Unix (termbox2 NIF) |
|-----------|---------------------|---------------------|
| Frame render | ~500μs | ~50μs |
| Screen clear | <100μs | <10μs |
| Set cursor | <50μs | <5μs |
| Set cell | <100μs | <10μs |

Performance is adequate for:
- 60fps terminal UIs (16ms frame budget)
- Interactive applications
- Text editors
- Dashboard applications

## Terminal Emulators

### Recommended: Windows Terminal

Best experience with Windows Terminal:
- Full unicode support
- True color (24-bit)
- GPU-accelerated rendering
- Customizable fonts and themes

Install via Microsoft Store or:
```powershell
winget install Microsoft.WindowsTerminal
```

### PowerShell

Works well with both:
- PowerShell 7+ (pwsh.exe)
- Windows PowerShell 5.1 (powershell.exe)

Enable ANSI colors if not enabled:
```powershell
# Check current setting
Get-ItemProperty HKCU:\Console VirtualTerminalLevel

# Enable VT100 (if needed)
Set-ItemProperty HKCU:\Console VirtualTerminalLevel -Type DWORD 1
```

### Command Prompt (cmd.exe)

Supported but limited:
- Basic ANSI color support
- Unicode may have issues
- Use Windows Terminal or PowerShell for best experience

## Troubleshooting

### Colors Not Displaying

If ANSI colors aren't working:

```powershell
# Verify VT100 is enabled
reg query HKCU\Console /v VirtualTerminalLevel

# Enable if needed
reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f
```

### Unicode Characters Not Rendering

1. Ensure terminal font supports unicode (e.g., Cascadia Code, Consolas)
2. Use Windows Terminal instead of cmd.exe
3. Verify system locale supports UTF-8

### Performance Issues

If experiencing sluggish rendering:

1. Use Windows Terminal (GPU-accelerated)
2. Reduce UI complexity (fewer updates per frame)
3. Consider batch rendering operations
4. Profile with `mix raxol.profile`

### Module Not Found Errors

If seeing `:termbox2_nif` errors on Windows:

This is expected! Windows uses IOTerminal, not the NIF. Verify:
- Mix compilation completes without NIF build
- IOTerminal module is available
- No C compilation errors during `mix deps.compile`

## Development

### Running Tests on Windows

```powershell
# Standard test command
mix test --exclude slow --exclude integration

# Test IOTerminal specifically
mix test test/raxol/terminal/io_terminal_test.exs

# Test with coverage
mix test --cover
```

### Debugging

Enable debug logging:
```elixir
# config/dev.exs
config :logger, level: :debug
```

Check which backend is active:
```elixir
# In your application
require Logger
Logger.info("termbox2_nif available: #{Code.ensure_loaded?(:termbox2_nif)}")
Logger.info("IOTerminal available: #{Code.ensure_loaded?(Raxol.Terminal.IOTerminal)}")
```

## Implementation Details

### Pure Elixir Driver (IOTerminal)

Located in `lib/raxol/terminal/io_terminal.ex`:

**Features**:
- OTP 28+ raw terminal mode via `:shell.start_interactive/1`
- ANSI escape sequences via `IO.ANSI`
- Cross-platform terminal size detection via `:io.columns/0`, `:io.rows/0`
- 8-bit color support (256 colors)
- Unicode character rendering

**API**:
```elixir
IOTerminal.init()               # Initialize terminal
IOTerminal.shutdown()           # Restore terminal state
IOTerminal.clear_screen()       # Clear screen
IOTerminal.set_cursor(x, y)     # Position cursor
IOTerminal.hide_cursor()        # Hide cursor
IOTerminal.show_cursor()        # Show cursor
IOTerminal.set_cell(x, y, char, fg, bg)  # Render cell
IOTerminal.print_string(x, y, str, fg, bg) # Render string
IOTerminal.get_terminal_size()  # Get width/height
IOTerminal.set_title(title)     # Set window title
```

### Automatic Backend Selection

The Driver (`lib/raxol/terminal/driver.ex`) automatically selects the backend:

```elixir
@termbox2_available Code.ensure_loaded?(:termbox2_nif)

# In init_manager/1
{_terminal_init_result, io_terminal_state} =
  if @termbox2_available do
    {apply(:termbox2_nif, :tb_init, []), nil}
  else
    case IOTerminal.init() do
      {:ok, io_state} -> {0, io_state}
      {:error, _reason} -> {-1, nil}
    end
  end
```

## Comparison with Unix

| Feature | Windows (IOTerminal) | Unix (termbox2 NIF) |
|---------|---------------------|---------------------|
| Backend | Pure Elixir | Native C NIF |
| OTP Version | 28+ required | 26+ supported |
| Compilation | No C compiler needed | Requires C compiler |
| Performance | Good (~500μs) | Excellent (~50μs) |
| Unicode | Full support | Full support |
| Colors | 256 colors | 256 colors |
| Mouse | Supported | Supported |
| API | Identical | Identical |

## Future Enhancements

Potential optimizations for Windows:

1. **Native Windows Console API NIF** (Optional)
   - Would provide ~50μs performance like Unix
   - Requires C compilation on Windows
   - Not currently needed (pure Elixir sufficient)

2. **DirectWrite Integration**
   - GPU-accelerated text rendering
   - Better font support
   - Requires Windows-specific code

3. **ConPTY Support**
   - Modern Windows pseudo-console
   - Better process integration
   - Available in Windows 10 1809+

## Resources

- [Windows Terminal Documentation](https://docs.microsoft.com/en-us/windows/terminal/)
- [Console Virtual Terminal Sequences](https://docs.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences)
- [Erlang/OTP 28 Raw Mode](https://www.erlang.org/doc/apps/stdlib/shell.html)
- [Raxol IOTerminal Tests](../../test/raxol/terminal/io_terminal_test.exs)

## Support

If you encounter issues with Windows support:

1. Check this documentation
2. Verify requirements (Windows 10+, OTP 28+)
3. Test with IOTerminal directly
4. Open an issue: https://github.com/Hydepwns/raxol/issues

Include in your report:
- Windows version
- Terminal emulator (Windows Terminal, PowerShell, cmd.exe)
- Erlang/OTP version
- Elixir version
- Error messages or unexpected behavior
