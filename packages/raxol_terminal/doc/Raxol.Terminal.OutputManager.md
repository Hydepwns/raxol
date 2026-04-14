# `Raxol.Terminal.OutputManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/output_manager.ex#L1)

Manages terminal output operations including writing, flushing, and output buffering.
This module is responsible for handling all output-related operations in the terminal.

# `clear`

Clears the output buffer.
Returns the updated emulator.

# `empty?`

Checks if the output buffer is empty.
Returns true if the buffer is empty, false otherwise.

# `flush`

Flushes the output buffer.
Returns {:ok, updated_emulator} or {:error, reason}.

# `format_ansi_sequences`

Formats ANSI escape sequences for display.
Returns the formatted string with ANSI sequences replaced by readable descriptions.

# `format_control_chars`

Formats control characters for display.
Returns the formatted string.

# `format_unicode`

Formats Unicode characters for display.
Returns the formatted string.

# `get_buffer`

Gets the output buffer instance.
Returns the output buffer.

# `get_content`

Gets the current output buffer content.
Returns the buffer content as a string.

# `get_encoding`

Gets the current output buffer encoding.
Returns the current encoding.

# `get_mode`

Gets the current output buffer mode.
Returns the current mode.

# `get_size`

Gets the output buffer size.
Returns the number of bytes in the buffer.

# `set_content`

Sets the output buffer content.
Returns the updated emulator.

# `set_encoding`

Sets the output buffer encoding.
Returns the updated emulator.

# `set_mode`

Sets the output buffer mode.
Returns the updated emulator.

# `update_buffer`

Updates the output buffer instance.
Returns the updated emulator.

# `write`

Writes a string to the output buffer.
Returns the updated emulator.

# `writeln`

Writes a string to the output buffer with a newline.
Returns the updated emulator.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
