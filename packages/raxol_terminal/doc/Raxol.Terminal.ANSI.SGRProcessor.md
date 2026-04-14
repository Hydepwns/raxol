# `Raxol.Terminal.ANSI.SGRProcessor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/sgr_processor.ex#L1)

Processes SGR (Select Graphic Rendition) ANSI escape sequences.

SGR sequences control text formatting attributes like colors, bold, italic, etc.
This module handles parsing SGR parameters and updating terminal styles accordingly.

# `handle_sgr`

```elixir
@spec handle_sgr(String.t(), any()) :: map()
```

Handles SGR parameters and updates the style state.

## Parameters
  - params: String of SGR parameters (e.g., "31", "1;4;31;48;5;196")
  - style: Current style state (can be nil or a map)

## Returns
  Updated style map

# `process_sgr_codes`

```elixir
@spec process_sgr_codes([integer()], map()) :: map()
```

Process SGR codes with parsed parameters.

## Parameters
  - codes: List of integer SGR codes
  - style: Current style map

## Returns
  Updated style map

---

*Consult [api-reference.md](api-reference.md) for complete listing*
