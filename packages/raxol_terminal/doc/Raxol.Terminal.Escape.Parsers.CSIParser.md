# `Raxol.Terminal.Escape.Parsers.CSIParser`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/escape/parsers/csi_parser.ex#L1)

Parser for CSI (Control Sequence Introducer) escape sequences.

CSI sequences are introduced by ESC [ and contain various terminal control commands
for cursor movement, text formatting, screen manipulation, etc.

# `parse`

```elixir
@spec parse(String.t()) ::
  {:ok, term(), String.t()}
  | {:incomplete, String.t()}
  | {:error, atom(), String.t()}
```

Parses a CSI sequence after the ESC [ prefix.

## Parameters
  - input: The input string after ESC [

## Returns
  - `{:ok, command, remaining}` - Successfully parsed command
  - `{:incomplete, input}` - Input is incomplete, need more data
  - `{:error, reason, input}` - Parse error

---

*Consult [api-reference.md](api-reference.md) for complete listing*
