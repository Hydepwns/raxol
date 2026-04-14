# `Raxol.Terminal.Escape.Parsers.SCSParser`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/escape/parsers/scs_parser.ex#L1)

Parser for SCS (Select Character Set) escape sequences.

SCS sequences are used to designate character sets to G0-G3 graphic sets.
They follow the pattern ESC ( x, ESC ) x, ESC * x, or ESC + x
where the intermediate character determines which G-set to modify.

# `parse`

```elixir
@spec parse(char(), String.t()) ::
  {:ok, term(), String.t()}
  | {:incomplete, String.t()}
  | {:error, atom(), String.t()}
```

Parses an SCS sequence after the ESC and intermediate character.

## Parameters
  - intermediate: The intermediate character ('(', ')', '*', '+')
  - input: The remaining input after the intermediate

## Returns
  - `{:ok, command, remaining}` - Successfully parsed command
  - `{:incomplete, input}` - Input is incomplete
  - `{:error, reason, input}` - Parse error

---

*Consult [api-reference.md](api-reference.md) for complete listing*
