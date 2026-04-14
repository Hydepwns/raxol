# `Raxol.Terminal.IOTerminal`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/io_terminal.ex#L1)

Pure Elixir terminal I/O using OTP 28+ raw mode and IO.ANSI.

Cross-platform terminal support without NIFs. Works on:
- Windows 10+ (with VT100 support)
- macOS
- Linux

Uses:
- OTP 28's `shell:start_interactive/1` for raw terminal mode
- `IO.ANSI` for escape sequences and colors
- `:io.setopts/1` for terminal configuration

# `clear_screen`

Clear the entire screen.

# `get_terminal_size`

Get terminal width and height.
Returns `{:ok, {width, height}}` or `{:error, reason}`.

# `hide_cursor`

Hide the cursor.

# `init`

Initialize the terminal in raw mode.
Returns `{:ok, state}` or `{:error, reason}`.

# `present`

Present (flush) all pending output to the terminal.

# `print_string`

Print a string at position (x, y) with colors.

# `read_char`

Read a single character/keypress in raw mode.
Returns `{:ok, char}` or `{:error, reason}`.

# `set_cell`

Set a cell at position (x, y) with character, foreground, and background.
Colors are 8-bit ANSI color codes (0-255).

# `set_cursor`

Set cursor position (0-indexed).

# `set_title`

Set terminal title.

# `show_cursor`

Show the cursor.

# `shutdown`

Shutdown terminal and restore settings.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
