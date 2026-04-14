# `Raxol.Core.Events.Event`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/events/event.ex#L1)

Defines the structure for events in the Raxol system, providing a standardized format
for key presses, mouse actions, and other UI events that components need to process.

Events are structs with a :type and :data field, where :type indicates the event category
(e.g., :key, :mouse, :resize) and :data contains the event-specific details.

# `cursor_event`

```elixir
@type cursor_event() :: %{
  visible: boolean(),
  style: :block | :line | :underscore,
  blink: boolean(),
  position: {non_neg_integer(), non_neg_integer()}
}
```

# `event_data`

```elixir
@type event_data() :: any()
```

# `event_type`

```elixir
@type event_type() :: atom()
```

# `focus_event`

```elixir
@type focus_event() :: %{target: focus_target(), focused: boolean()}
```

# `focus_target`

```elixir
@type focus_target() :: :component | :window | :application
```

# `key`

```elixir
@type key() :: atom() | String.t()
```

# `key_event`

```elixir
@type key_event() :: %{key: key(), state: key_state(), modifiers: modifiers()}
```

# `key_state`

```elixir
@type key_state() :: :pressed | :released | :repeat
```

# `modifiers`

```elixir
@type modifiers() :: [atom()]
```

# `mouse_button`

```elixir
@type mouse_button() :: :left | :right | :middle
```

# `mouse_event`

```elixir
@type mouse_event() :: %{
  button: mouse_button() | nil,
  state: mouse_state() | nil,
  position: mouse_position(),
  modifiers: modifiers()
}
```

# `mouse_position`

```elixir
@type mouse_position() :: {non_neg_integer(), non_neg_integer()}
```

# `mouse_state`

```elixir
@type mouse_state() :: :pressed | :released | :double_click
```

# `paste_event`

```elixir
@type paste_event() :: %{
  text: String.t(),
  position: {non_neg_integer(), non_neg_integer()}
}
```

# `scroll_direction`

```elixir
@type scroll_direction() :: :vertical | :horizontal
```

# `scroll_event`

```elixir
@type scroll_event() :: %{
  direction: scroll_direction(),
  delta: integer(),
  position: {non_neg_integer(), non_neg_integer()}
}
```

# `selection_event`

```elixir
@type selection_event() :: %{
  start_pos: {non_neg_integer(), non_neg_integer()},
  end_pos: {non_neg_integer(), non_neg_integer()},
  text: String.t()
}
```

# `t`

```elixir
@type t() :: %Raxol.Core.Events.Event{
  data: event_data(),
  mounted: term(),
  render_count: term(),
  timestamp: DateTime.t(),
  type: event_type()
}
```

# `window_event`

```elixir
@type window_event() :: %{
  width: non_neg_integer(),
  height: non_neg_integer(),
  action: :resize | :focus | :blur
}
```

# `cursor_event`

Creates a cursor event.

## Parameters
  * `visible` - Whether cursor is visible
  * `style` - Cursor style
  * `blink` - Whether cursor should blink
  * `position` - Cursor position

# `custom`

Creates a simple custom event.

# `custom_event`

Creates a custom event.

## Parameters
  * `data` - Custom event data

# `focus_event`

Creates a focus event.

## Parameters
  * `target` - What received/lost focus
  * `focused` - Whether focus was gained (true) or lost (false)

# `key`

Creates a simple key event with pressed state and no modifiers.

# `key_event`

Creates a keyboard event.

## Parameters
  * `key` - The key that was pressed/released (e.g. :enter, :backspace, "a")
  * `state` - The state of the key (:pressed, :released, :repeat)
  * `modifiers` - List of active modifiers (e.g. [:shift, :ctrl])

# `key_match`
*macro* 

Match macro for key events. Works in pattern match positions (case/function heads).

## Examples

    # Match a character key:
    key_match("q") -> ...

    # Match a special key:
    key_match(:tab) -> ...

    # Match with extra data fields:
    key_match(:tab, shift: true) -> ...

# `key_match`
*macro* 

Match macro for key events with additional data fields.

## Examples

    key_match(:tab, shift: true) -> ...

# `mouse`

Creates a simple mouse event with pressed state and no modifiers.

# `mouse`

Creates a mouse event with drag state.

# `mouse_event`

Creates a mouse event.

## Parameters
  * `button` - The mouse button (:left, :right, :middle)
  * `position` - The mouse position as {x, y}
  * `state` - The button state (:pressed, :released, :double_click)
  * `modifiers` - List of active modifiers (e.g. [:shift, :ctrl])

# `new`

Creates a new event with the given type and data. Optionally accepts a timestamp (defaults to now).

# `paste_event`

Creates a paste event.

## Parameters
  * `text` - Pasted text
  * `position` - Paste position

# `scroll_event`

Creates a scroll event.

## Parameters
  * `direction` - Scroll direction
  * `delta` - Amount scrolled (positive or negative)
  * `position` - Current scroll position

# `selection_event`

Creates a selection event.

## Parameters
  * `start_pos` - Selection start position
  * `end_pos` - Selection end position
  * `text` - Selected text

# `timer`

Creates a simple timer event.

# `timer_event`

Creates a timer event.

## Parameters
  * `data` - Timer-specific data

# `window`

Creates a simple window event.

# `window_event`

Creates a window event.

## Parameters
  * `width` - The window width
  * `height` - The window height
  * `action` - The window action (:resize, :focus, :blur)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
