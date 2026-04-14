# `Raxol.Terminal.Input.SpecialKeys`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input/special_keys.ex#L1)

Handles special key combinations and their escape sequences.

This module provides functionality for:
- Detecting special key combinations (Ctrl, Alt, Shift, Meta)
- Converting special keys to their corresponding escape sequences
- Handling modifier key state
- Supporting extended key combinations

# `modifier`

```elixir
@type modifier() :: :ctrl | :alt | :shift | :meta
```

# `modifier_state`

```elixir
@type modifier_state() :: %{required(modifier()) =&gt; boolean()}
```

# `atom_to_escape_sequence`

Converts an atom key to its corresponding escape sequence.

# `key_with_modifiers_to_escape_sequence`

Converts a key with modifiers to its corresponding escape sequence.

# `new_state`

Creates a new modifier state.

## Examples

    iex> state = SpecialKeys.new_state()
    iex> state.ctrl
    false

# `to_escape_sequence`

Converts a key combination to its corresponding escape sequence.

## Examples

    iex> state = SpecialKeys.new_state() |> SpecialKeys.update_state("Control", true)
    iex> SpecialKeys.to_escape_sequence(state, "c")
    "[99"

# `update_state`

Updates the modifier state based on a key event.

## Examples

    iex> state = SpecialKeys.new_state()
    iex> state = SpecialKeys.update_state(state, "Control", true)
    iex> state.ctrl
    true

---

*Consult [api-reference.md](api-reference.md) for complete listing*
