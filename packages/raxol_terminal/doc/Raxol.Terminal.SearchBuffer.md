# `Raxol.Terminal.SearchBuffer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/search_buffer.ex#L1)

Manages search state, options, matches, and history for terminal search operations.

# `match`

```elixir
@type match() :: %{
  line: integer(),
  start: integer(),
  length: integer(),
  text: String.t()
}
```

# `options`

```elixir
@type options() :: %{case_sensitive: boolean(), regex: boolean()}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.SearchBuffer{
  current_index: integer(),
  history: [String.t()],
  matches: [match()],
  options: options(),
  pattern: String.t() | nil
}
```

# `add_to_history`

```elixir
@spec add_to_history(t(), String.t()) :: t()
```

Adds a pattern to the search history.

# `clear`

```elixir
@spec clear(t()) :: t()
```

Clears the current search.

# `clear_history`

```elixir
@spec clear_history(t()) :: t()
```

Clears the search history.

# `find_next`

```elixir
@spec find_next(t()) :: {:ok, t(), match()} | {:error, term()}
```

Finds the next match in the search.

# `find_previous`

```elixir
@spec find_previous(t()) :: {:ok, t(), match()} | {:error, term()}
```

Finds the previous match in the search.

# `get_all_matches`

```elixir
@spec get_all_matches(t()) :: [match()]
```

Gets all matches in the current search.

# `get_current_index`

```elixir
@spec get_current_index(t()) :: integer()
```

Gets the current match index.

# `get_match_count`

```elixir
@spec get_match_count(t()) :: non_neg_integer()
```

Gets the total number of matches.

# `get_options`

```elixir
@spec get_options(t()) :: map()
```

Gets the current search options.

# `get_pattern`

```elixir
@spec get_pattern(t()) :: String.t() | nil
```

Gets the current search pattern.

# `get_search_history`

```elixir
@spec get_search_history(t()) :: [String.t()]
```

Gets the search history.

# `highlight_matches`

```elixir
@spec highlight_matches(t()) :: t()
```

Highlights all matches in the current view (no-op placeholder).

# `set_options`

```elixir
@spec set_options(t(), map()) :: t()
```

Sets the search options.

# `start_search`

```elixir
@spec start_search(t(), String.t()) :: {:ok, t()} | {:error, term()}
```

Starts a new search with the given pattern.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
