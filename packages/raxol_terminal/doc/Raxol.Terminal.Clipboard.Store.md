# `Raxol.Terminal.Clipboard.Store`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/clipboard/store.ex#L1)

Manages clipboard content storage and retrieval.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Clipboard.Store{
  content: String.t(),
  format: String.t(),
  timestamp: integer()
}
```

# `expired?`

```elixir
@spec expired?(t(), integer()) :: boolean()
```

Checks if a store entry is expired.

# `get_content`

```elixir
@spec get_content(t()) :: String.t()
```

Gets the content from a store entry.

# `get_format`

```elixir
@spec get_format(t()) :: String.t()
```

Gets the format from a store entry.

# `get_timestamp`

```elixir
@spec get_timestamp(t()) :: integer()
```

Gets the timestamp from a store entry.

# `new`

```elixir
@spec new(String.t(), String.t()) :: t()
```

Creates a new clipboard store entry.

# `update_content`

```elixir
@spec update_content(t(), String.t()) :: t()
```

Updates the content of a store entry.

# `update_format`

```elixir
@spec update_format(t(), String.t()) :: t()
```

Updates the format of a store entry.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
