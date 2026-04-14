# `Raxol.Terminal.Clipboard.History`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/clipboard/history.ex#L1)

Manages clipboard history for the terminal.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Clipboard.History{
  entries: [{String.t(), String.t()}],
  max_size: non_neg_integer()
}
```

# `add`

```elixir
@spec add(t(), String.t(), String.t()) :: {:ok, t()}
```

Adds content to the clipboard history.

# `clear`

```elixir
@spec clear(t()) :: {:ok, t()}
```

Clears the clipboard history.

# `get`

```elixir
@spec get(t(), non_neg_integer(), String.t()) ::
  {:ok, String.t()} | {:error, :not_found}
```

Gets content from the clipboard history by index.

# `get_all`

```elixir
@spec get_all(t(), String.t(), non_neg_integer() | :infinity) ::
  {:ok, [String.t()], t()}
```

Gets all entries from the clipboard history with the specified format.

# `new`

```elixir
@spec new(non_neg_integer()) :: t()
```

Creates a new clipboard history with the specified size limit.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
