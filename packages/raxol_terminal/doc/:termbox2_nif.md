# `:termbox2_nif`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/termbox2_nif/lib/termbox2_nif.ex#L1)

Termbox2 NIF for Elixir - A terminal UI library.

# `load_nif`

# `tb_clear`

Clear the terminal.

# `tb_height`

Get the height of the terminal.

# `tb_hide_cursor`

Hide the cursor.
Returns 0 on success, -1 on error.

# `tb_init`

Initialize the termbox2 library.
Returns 0 on success, -1 on error.

# `tb_present`

Present the changes to the terminal.

# `tb_print`

Print a string at the specified position.
Returns 0 on success, -1 on error.

# `tb_set_cell`

Set a cell in the terminal.
Returns 0 on success, -1 on error.

# `tb_set_cursor`

Set the cursor position.

# `tb_set_input_mode`

Set the input mode.
Returns the previous mode.

# `tb_set_output_mode`

Set the output mode.
Returns the previous mode.

# `tb_set_position`

Set the terminal window position.
Returns {:ok, "set"} on success, {:error, reason} on failure.

# `tb_set_title`

Set the terminal title.
Returns {:ok, "set"} on success, {:error, reason} on failure.

# `tb_shutdown`

Shutdown the termbox2 library.

# `tb_width`

Get the width of the terminal.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
