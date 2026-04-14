# `Raxol.Terminal.ANSI.SGR.Formatter`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/sgr.ex#L9)

SGR parameter formatting for the Raxol Terminal ANSI TextFormatting module.
Handles SGR parameter parsing, formatting, and attribute handling.

# `format_sgr_params`

```elixir
@spec format_sgr_params(Raxol.Terminal.ANSI.TextFormatting.text_style()) :: String.t()
```

Formats a style into SGR (Select Graphic Rendition) parameters.
Returns a string of ANSI SGR codes.

# `parse_sgr_param`

```elixir
@spec parse_sgr_param(integer(), Raxol.Terminal.ANSI.TextFormatting.text_style()) ::
  Raxol.Terminal.ANSI.TextFormatting.text_style()
```

Parses an SGR parameter and applies it to the given style.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
