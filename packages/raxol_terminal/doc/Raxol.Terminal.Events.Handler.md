# `Raxol.Terminal.Events.Handler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/events/events_handler.ex#L1)

Handles terminal events and dispatches them to appropriate handlers.

# `handle_clipboard_event`

```elixir
@spec handle_clipboard_event(any(), any()) :: {:ok, any()} | {:error, String.t()}
```

Handles clipboard events.

# `handle_cursor_event`

```elixir
@spec handle_cursor_event(any(), any()) :: {:ok, any()} | {:error, String.t()}
```

Handles cursor events.

# `handle_event`

Generic event handler that dispatches to appropriate handlers.

# `handle_focus_event`

Handles focus events.

# `handle_keyboard_event`

Handles keyboard events.

# `handle_mode_event`

Handles mode change events.

# `handle_mouse_event`

Handles mouse events.

# `handle_paste_event`

```elixir
@spec handle_paste_event(any(), any()) :: {:ok, any()} | {:error, String.t()}
```

Handles paste events.

# `handle_scroll_event`

```elixir
@spec handle_scroll_event(any(), any()) :: {:ok, any()} | {:error, String.t()}
```

Handles scroll events.

# `handle_selection_event`

```elixir
@spec handle_selection_event(any(), any()) :: {:ok, any()} | {:error, String.t()}
```

Handles selection events.

# `handle_window_event`

Handles window-related events.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
