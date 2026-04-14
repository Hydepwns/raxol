# `Raxol.Terminal.ANSI.Sequences.Modes`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/sequences/modes.ex#L1)

ANSI Terminal Modes Sequence Handler.

Handles parsing and application of ANSI terminal mode sequences,
including screen modes, input modes, and rendering modes.

# `handle_mode_sequence`

Sets or resets ANSI modes.

# `set_alternate_buffer`

Switch to alternate buffer mode.

## Parameters

* `emulator` - The terminal emulator state
* `use_alternate` - Boolean indicating if alternate buffer should be used

## Returns

Updated emulator state

# `set_bracketed_paste_mode`

Enable or disable bracketed paste mode.

## Parameters

* `emulator` - The terminal emulator state
* `enabled` - Boolean indicating if mode should be enabled or disabled

## Returns

Updated emulator state

# `set_focus_reporting`

Enable or disable focus reporting.

## Parameters

* `emulator` - The terminal emulator state
* `enabled` - Boolean indicating if mode should be enabled or disabled

## Returns

Updated emulator state

# `set_screen_mode`

Set or reset a screen mode.

## Parameters

* `emulator` - The terminal emulator state
* `mode` - Mode identifier
* `enabled` - Boolean indicating if mode should be enabled or disabled

## Returns

Updated emulator state

---

*Consult [api-reference.md](api-reference.md) for complete listing*
