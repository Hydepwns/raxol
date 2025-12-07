# Fuzzy Search

> [Documentation](../README.md) > [Features](README.md) > Fuzzy Search

Multi-mode search with fuzzy, exact, and regex matching.

## Usage

```elixir
alias Raxol.Search.Fuzzy

# Fuzzy: "hlo" matches "hello"
results = Fuzzy.search(buffer, "hlo", :fuzzy)

# Exact: precise matches
results = Fuzzy.search(buffer, "World", :exact)

# Regex: patterns
results = Fuzzy.search(buffer, ~r/H\w+/, :regex)
```

## Search Modes

```elixir
# Fuzzy with scoring
[match | _] = Fuzzy.search(buffer, "hlo", :fuzzy)
match.position  # {x, y}
match.score     # 0.0-1.0
match.highlight # [0, 2, 3]

# Case sensitivity
results = Fuzzy.search(buffer, "hello", :fuzzy, %{case_sensitive: true})
```

## Interactive Search

```elixir
# Create state
search = Fuzzy.new(buffer)

# Update query
search = Fuzzy.update_query(search, "pattern")

# Navigate
search = Fuzzy.next_match(search)
search = Fuzzy.previous_match(search)

# Current match
current = Fuzzy.get_current_match(search)
```

## Highlighting

```elixir
# Default style
buffer = Fuzzy.highlight_matches(buffer, search.matches)

# Custom style
style = %{bg_color: :cyan, fg_color: :black, bold: true}
buffer = Fuzzy.highlight_matches(buffer, search.matches, style)
```

## Statistics

```elixir
stats = Fuzzy.get_stats(search)
# %{total_matches: 5, current: 2, query: "hello"}
```

## Integration

```elixir
def handle_search(state, query) do
  search = Fuzzy.update_query(state.search, query)

  case Fuzzy.get_current_match(search) do
    %{position: pos} ->
      vim = put_in(state.vim.cursor, pos)
      %{state | vim: vim, search: search}
    nil ->
      %{state | search: search}
  end
end
```

Performance: ~100μs for 1000-line buffer
