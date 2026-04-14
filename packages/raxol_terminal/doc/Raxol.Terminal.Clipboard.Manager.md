# `Raxol.Terminal.Clipboard.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/clipboard/clipboard_manager.ex#L1)

Manages clipboard operations for the terminal, including copying and pasting text.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Clipboard.Manager{
  content: String.t(),
  mode: :normal | :bracketed
}
```

# `append`

Appends text to the current clipboard content.

# `clear`

Clears the clipboard content (global function).

# `clear`

Clears the clipboard content.

# `copy`

Copies content to the clipboard with the specified format.

# `empty?`

Checks if the clipboard is empty.

# `get_content`

Gets the current clipboard content.

# `get_mode`

Gets the current clipboard mode.

# `length`

Gets the length of the clipboard content.

# `new`

Creates a new clipboard manager instance.

# `paste`

Pastes content from the clipboard with the specified format.

# `prepend`

Prepends text to the current clipboard content.

# `reset`

Resets the clipboard manager to its initial state.

# `set_content`

Sets the clipboard content.

# `set_mode`

Sets the clipboard mode.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
