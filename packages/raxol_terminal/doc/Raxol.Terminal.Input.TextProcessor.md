# `Raxol.Terminal.Input.TextProcessor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input/text_processor.ex#L1)

Handles text input processing for the terminal emulator.
This module extracts the text input handling logic from the main emulator.

# `handle_text_input`

```elixir
@spec handle_text_input(binary(), any()) :: any()
```

Processes text input and applies character set translation.

# `printable_char?`

```elixir
@spec printable_char?(binary()) :: boolean()
```

Checks if a character is printable.

# `printable_text?`

```elixir
@spec printable_text?(binary()) :: boolean()
```

Checks if the input contains printable text.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
