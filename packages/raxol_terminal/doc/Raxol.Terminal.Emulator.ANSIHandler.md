# `Raxol.Terminal.Emulator.ANSIHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/ansi_handler.ex#L1)

Handles ANSI sequence processing for the terminal emulator.

This module provides ANSI sequence handling including:
- Sequence parsing
- Command handling
- SGR processing
- Mode management

# `handle_ansi_sequences`

Handles ANSI sequences for the emulator.

## Parameters

* `rest` - Remaining input to process
* `emulator` - The emulator state

## Returns

A tuple {updated_emulator, remaining_input}.

# `handle_csi_general`

# `handle_esc_equals`

# `handle_esc_greater`

# `handle_parsed_sequence`

Handles a parsed ANSI sequence.

## Parameters

* `parsed_sequence` - The parsed sequence
* `rest` - Remaining input
* `emulator` - The emulator state

## Returns

A tuple {updated_emulator, remaining_input}.

# `handle_reset_mode`

# `handle_reset_standard_mode`

# `handle_set_mode`

# `handle_set_scroll_region`

# `handle_set_standard_mode`

# `handle_sgr`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
