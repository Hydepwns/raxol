# `Raxol.Terminal.ANSI.CharacterSets`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/character_sets.ex#L1)

Consolidated character set management for the terminal emulator.
Combines: Handler, StateManager, Translator, and core CharacterSets functionality.
Supports G0, G1, G2, G3 character sets and their switching operations.

Sub-modules:
- `CharacterSets.Handler`     -- control sequence handling
- `CharacterSets.StateManager` -- G-set state management
- `CharacterSets.Translator`   -- codepoint translation
- `CharacterSets.CharsetData`  -- per-charset translation maps

# `charset`

```elixir
@type charset() ::
  :us_ascii
  | :uk
  | :french
  | :german
  | :swedish
  | :swiss
  | :italian
  | :spanish
  | :portuguese
  | :japanese
  | :korean
  | :latin1
  | :latin2
  | :latin3
  | :latin4
  | :latin5
  | :cyrillic
  | :arabic
  | :greek
  | :hebrew
  | :thai
  | :dec_special_graphics
  | :dec_supplemental_graphics
  | :dec_technical
  | :dec_multinational
```

# `codepoint`

```elixir
@type codepoint() :: non_neg_integer()
```

# `charset_code_to_module`

Maps a character set code to module (for backward compatibility).

# `clear_single_shift`

# `designate_charset`

Designates a character set for a G-set.

# `get_active`

# `get_active_charset`

# `handle_control_sequence`

Handles a character set control sequence.

# `handle_sequence`

# `index_to_gset`

Maps an index to a gset name.

# `invoke_designator`

Invokes a character set designator.

# `new`

# `new_state`

Creates a new character set state.

# `set_g0`

# `set_g1`

# `set_g2`

# `set_g3`

# `set_gl`

# `set_gr`

# `set_single_shift`

# `switch_charset`

Switches the character set for a given G-set in a charset state map.

# `switch_charset_emulator`

Switches the character set for a given G-set in an emulator.

# `translate_char`

# `translate_char`

# `translate_character`

Translates a character using the current character set state.

# `translate_string`

Translates a string using the active character set.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
