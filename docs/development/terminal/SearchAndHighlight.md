---
title: Search and Highlight Component
description: Documentation for the search and highlight component in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: components
tags: [search, highlight, terminal, documentation]
---

# Search and Highlight Component

The search and highlight component manages text search, pattern matching, and content highlighting in the terminal emulator.

## Features

- Text search
- Regex support
- Incremental search
- Case sensitivity
- Word boundaries
- Search history
- Match highlighting
- Pattern matching
- Search navigation
- Result marking

## Usage

```elixir
# Create a new search manager
search = Raxol.Terminal.Search.new()

# Perform search
{:ok, results} = Raxol.Terminal.Search.find(search, "pattern")

# Navigate results
{:ok, match} = Raxol.Terminal.Search.next(search)

# Highlight matches
:ok = Raxol.Terminal.Search.highlight_matches(search)
```

## Configuration

The search manager can be configured with the following options:

```elixir
config = %{
  case_sensitive: false,
  whole_word: false,
  regex_enabled: true,
  max_results: 1000,
  highlight_color: :yellow,
  search_timeout: 5000,
  history_size: 50,
  incremental: true,
  wrap_around: true
}

search = Raxol.Terminal.Search.new(config)
```

## Implementation Details

### Search Types

1. **Text Search**

   - Plain text
   - Case matching
   - Word boundaries
   - Exact matches

2. **Pattern Search**

   - Regular expressions
   - Wildcards
   - Character classes
   - Capture groups

3. **Special Search**
   - Multi-line search
   - Context search
   - Reverse search
   - Fuzzy search

### Search Management

1. **Result Management**

   - Result caching
   - Result navigation
   - Result filtering
   - Result sorting

2. **Highlight Management**
   - Match highlighting
   - Selection highlighting
   - Color management
   - Style management

### Search State

1. **Query State**

   - Current query
   - Query type
   - Query options
   - Query history

2. **Result State**
   - Match positions
   - Match count
   - Current match
   - Match metadata

## API Reference

### Search Management

```elixir
# Initialize search manager
@spec new() :: t()

# Perform search
@spec find(search :: t(), pattern :: String.t(), options :: map()) :: {:ok, [match()]} | {:error, String.t()}

# Update search
@spec update(search :: t(), pattern :: String.t()) :: {:ok, [match()]} | {:error, String.t()}

# Clear search
@spec clear(search :: t()) :: :ok
```

### Result Navigation

```elixir
# Next match
@spec next(search :: t()) :: {:ok, match()} | :error

# Previous match
@spec previous(search :: t()) :: {:ok, match()} | :error

# Jump to match
@spec goto_match(search :: t(), index :: integer()) :: {:ok, match()} | :error
```

### Highlight Management

```elixir
# Highlight matches
@spec highlight_matches(search :: t()) :: :ok

# Clear highlights
@spec clear_highlights(search :: t()) :: :ok

# Set highlight style
@spec set_highlight_style(search :: t(), style :: map()) :: t()
```

## Events

The search and highlight component emits the following events:

- `:search_started` - When a new search begins
- `:search_updated` - When search results update
- `:search_completed` - When search completes
- `:match_found` - When a match is found
- `:match_selected` - When a match is selected
- `:highlights_updated` - When highlights change
- `:search_cleared` - When search is cleared

## Example

```elixir
defmodule MyTerminal do
  alias Raxol.Terminal.Search

  def example do
    # Create a new search manager
    search = Search.new()

    # Configure search
    search = search
      |> Search.set_case_sensitive(false)
      |> Search.set_whole_word(true)
      |> Search.set_regex_enabled(true)

    # Perform search
    {:ok, results} = Search.find(search, "pattern\\w+")
    IO.puts("Found #{length(results)} matches")

    # Navigate results
    {:ok, first} = Search.next(search)
    {:ok, prev} = Search.previous(search)

    # Work with highlights
    :ok = Search.highlight_matches(search)
    search = Search.set_highlight_style(search, %{
      color: :yellow,
      bold: true
    })

    # Use incremental search
    search = search
      |> Search.start_incremental()
      |> Search.update("pat")
      |> Search.update("patt")
      |> Search.update("pattern")

    # Work with search history
    history = Search.get_history(search)
    :ok = Search.restore_from_history(search, 0)
  end
end
```

## Testing

The search and highlight component includes comprehensive tests:

```elixir
defmodule Raxol.Terminal.SearchTest do
  use ExUnit.Case
  alias Raxol.Terminal.Search

  test "finds text patterns correctly" do
    search = Search.new()
    {:ok, results} = Search.find(search, "test")
    assert length(results) > 0
  end

  test "handles regex patterns" do
    search = Search.new()
    {:ok, results} = Search.find(search, "\\w+\\d+", %{regex: true})
    assert length(results) > 0
  end

  test "navigates results correctly" do
    search = Search.new()
    {:ok, _} = Search.find(search, "test")
    {:ok, match1} = Search.next(search)
    {:ok, match2} = Search.next(search)
    assert match1 != match2
  end

  test "manages highlights correctly" do
    search = Search.new()
    {:ok, _} = Search.find(search, "test")
    :ok = Search.highlight_matches(search)
    highlights = Search.get_highlights(search)
    assert length(highlights) > 0
  end
```
