# `Raxol.Terminal.ANSI.CharacterSets.StateManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/character_sets/state_manager.ex#L1)

Manages character set state and operations.

# `charset`

```elixir
@type charset() ::
  :us_ascii
  | :dec_special_graphics
  | :uk
  | :us
  | :finnish
  | :french
  | :french_canadian
  | :german
  | :italian
  | :norwegian_danish
  | :portuguese
  | :spanish
  | :swedish
  | :swiss
```

# `charset_state`

```elixir
@type charset_state() :: %{
  active: charset(),
  single_shift: charset() | nil,
  g0: charset(),
  g1: charset(),
  g2: charset(),
  g3: charset(),
  gl: :g0 | :g1 | :g2 | :g3,
  gr: :g0 | :g1 | :g2 | :g3
}
```

# `charset_code_to_atom`

Converts a character set code to an atom.

# `clear_single_shift`

Clears the single shift.

# `get_active`

Gets the current active character set.

# `get_active_charset`

Gets the active character set by resolving the current GL setting.
Returns the actual charset, not the g-set reference.

# `get_active_gset`

Gets the active G-set character set (the charset of the current GL).

# `get_gl`

Gets the current GL (graphics left) setting.

# `get_gr`

Gets the current GR (graphics right) setting.

# `get_gset`

Gets a specific G-set character set.

# `get_single_shift`

Gets the single shift character set if any.

# `index_to_gset`

Converts G-set index to atom.

# `new`

Creates a new character set state with default values.

# `set_active`

Sets the active character set directly.

# `set_g0`

Sets the G0 character set.

# `set_g1`

Sets the G1 character set.

# `set_g2`

Sets the G2 character set.

# `set_g3`

Sets the G3 character set.

# `set_gl`

Sets the GL (graphics left) designation.

# `set_gr`

Sets the GR (graphics right) designation.

# `set_gset`

Sets a specific G-set character set.

# `set_single_shift`

Sets a single shift to the specified G-set.

# `update_active`

Updates the active character set based on current GL setting.

# `validate_state`

Validates character set state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
