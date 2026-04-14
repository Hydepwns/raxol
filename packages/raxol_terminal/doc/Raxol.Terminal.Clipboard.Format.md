# `Raxol.Terminal.Clipboard.Format`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/clipboard/format.ex#L1)

Handles clipboard content formatting and filtering.

# `apply_filter`

```elixir
@spec apply_filter(String.t(), String.t(), String.t()) ::
  {:ok, String.t()} | {:error, :invalid_filter}
```

Applies a filter to clipboard content.

# `strip_formatting`

```elixir
@spec strip_formatting(String.t()) :: String.t()
```

Strips formatting from content.

# `to_html`

```elixir
@spec to_html(String.t(), String.t()) :: String.t()
```

Converts content to HTML format.

# `to_rtf`

```elixir
@spec to_rtf(String.t(), String.t()) :: String.t()
```

Converts content to RTF format.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
