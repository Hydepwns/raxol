# `Raxol.Terminal.SearchManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/search_manager.ex#L1)

Manages terminal search operations including text search, pattern matching, and search history.
This module is responsible for handling all search-related operations in the terminal.

# `add_to_history`

Adds a pattern to the search history.
Returns the updated emulator.

# `clear_history`

Clears the search history.
Returns the updated emulator.

# `clear_search`

Clears the current search.
Returns the updated emulator.

# `find_next`

Finds the next match in the search.
Returns {:ok, updated_emulator, match} or {:error, reason}.

# `find_previous`

Finds the previous match in the search.
Returns {:ok, updated_emulator, match} or {:error, reason}.

# `get_all_matches`

Gets all matches in the current search.
Returns the list of matches.

# `get_buffer`

Gets the search buffer instance.
Returns the search buffer.

# `get_current_index`

Gets the current match index.
Returns the current index.

# `get_match_count`

Gets the total number of matches.
Returns the number of matches.

# `get_options`

Gets the current search options.
Returns the current options.

# `get_pattern`

Gets the current search pattern.
Returns the current pattern.

# `get_search_history`

Gets the search history.
Returns the list of recent search patterns.

# `highlight_matches`

Highlights all matches in the current view.
Returns the updated emulator.

# `set_options`

Sets the search options.
Returns the updated emulator.

# `start_search`

Starts a new search with the given pattern.
Returns {:ok, updated_emulator} or {:error, reason}.

# `update_buffer`

Updates the search buffer instance.
Returns the updated emulator.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
