# `Raxol.Terminal.AdvancedFeatures`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/advanced_features.ex#L1)

Implements advanced terminal features for modern terminal emulators.

This module provides support for:
- OSC 8 Hyperlinks - Clickable links in terminal output
- Synchronized Output (DEC 2026) - Flicker-free rendering
- Focus Events - Terminal focus/blur detection
- Enhanced Bracketed Paste - Improved paste handling
- Window Manipulation - Advanced terminal control

These features enable rich, interactive terminal applications with modern UX patterns.

# `hyperlink_id`

```elixir
@type hyperlink_id() :: String.t()
```

# `hyperlink_params`

```elixir
@type hyperlink_params() :: %{
  optional(:id) =&gt; hyperlink_id(),
  optional(:tooltip) =&gt; String.t(),
  optional(:params) =&gt; map()
}
```

# `url`

```elixir
@type url() :: String.t()
```

# `begin_synchronized_output`

```elixir
@spec begin_synchronized_output() :: :ok
```

Enables synchronized output mode for flicker-free rendering.

When enabled, terminal output is buffered until explicitly flushed,
preventing screen flickering during complex updates.

## Examples

    AdvancedFeatures.begin_synchronized_output()
    # ... perform multiple terminal updates ...
    AdvancedFeatures.end_synchronized_output()

# `create_hyperlink`

```elixir
@spec create_hyperlink(String.t(), url(), hyperlink_params()) :: String.t()
```

Creates a clickable hyperlink using OSC 8 escape sequences.

## Parameters

- `text` - The text to display as clickable
- `url` - The URL to open when clicked
- `options` - Additional hyperlink options

## Examples

    iex> AdvancedFeatures.create_hyperlink("Visit GitHub", "https://github.com")
    "\e]8;;https://github.com\e\\Visit GitHub\e]8;;\e\\"

    iex> AdvancedFeatures.create_hyperlink("Click me", "https://example.com", %{
    ...>   id: "link1",
    ...>   tooltip: "Opens example.com"
    ...> })

# `create_hyperlinks`

```elixir
@spec create_hyperlinks([{String.t(), url()}], hyperlink_params()) :: [String.t()]
```

Creates multiple hyperlinks with shared parameters.

## Examples

    links = [
      {"GitHub", "https://github.com"},
      {"GitLab", "https://gitlab.com"}
    ]

    AdvancedFeatures.create_hyperlinks(links, %{tooltip: "Git repository"})

# `disable_bracketed_paste`

```elixir
@spec disable_bracketed_paste() :: :ok
```

Disables bracketed paste mode.

# `disable_focus_events`

```elixir
@spec disable_focus_events() :: :ok
```

Disables terminal focus events.

# `enable_bracketed_paste`

```elixir
@spec enable_bracketed_paste() :: :ok
```

Enables enhanced bracketed paste mode.

This prevents pasted content from being interpreted as terminal commands
and provides better handling of multiline pastes.

# `enable_focus_events`

```elixir
@spec enable_focus_events() :: :ok
```

Enables terminal focus events.

When enabled, the terminal will send escape sequences when it gains
or loses focus, allowing applications to respond to focus changes.

# `end_synchronized_output`

```elixir
@spec end_synchronized_output() :: :ok
```

Disables synchronized output mode and flushes buffered content.

# `get_terminal_capabilities`

```elixir
@spec get_terminal_capabilities() :: %{
  hyperlinks: boolean(),
  synchronized_output: boolean(),
  focus_events: boolean(),
  bracketed_paste: boolean(),
  window_manipulation: boolean(),
  terminal_type: String.t(),
  term_variable: String.t()
}
```

Gets current terminal capabilities and features.

# `get_window_size`

```elixir
@spec get_window_size() ::
  {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, term()}
```

Gets the current terminal window size.

Returns `{:ok, {width, height}}` or `{:error, reason}`.

# `parse_focus_event`

```elixir
@spec parse_focus_event(binary()) :: {:focus_in} | {:focus_out} | {:unknown, binary()}
```

Parses focus event sequences.

Returns:
- `{:focus_in}` - Terminal gained focus
- `{:focus_out}` - Terminal lost focus
- `{:unknown, data}` - Unrecognized sequence

# `parse_paste_event`

```elixir
@spec parse_paste_event(binary()) ::
  {:paste_start} | {:paste_end} | {:paste_content, binary()}
```

Parses bracketed paste sequences.

Returns:
- `{:paste_start}` - Beginning of pasted content
- `{:paste_end}` - End of pasted content
- `{:paste_content, data}` - Pasted content

# `set_window_title`

```elixir
@spec set_window_title(String.t()) :: :ok
```

Sets the terminal window title.

# `supports_hyperlinks?`

```elixir
@spec supports_hyperlinks?() :: boolean()
```

Detects if the current terminal supports OSC 8 hyperlinks.

# `supports_synchronized_output?`

```elixir
@spec supports_synchronized_output?() :: boolean()
```

Detects if the terminal supports synchronized output.

# `with_synchronized_output`

```elixir
@spec with_synchronized_output((-&gt; any())) :: any()
```

Executes a function with synchronized output enabled.

## Examples

    AdvancedFeatures.with_synchronized_output(fn ->
      Log.info("Line 1")
      Log.info("Line 2")
      # These will appear atomically
    end)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
