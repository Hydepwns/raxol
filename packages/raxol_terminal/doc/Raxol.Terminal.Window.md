# `Raxol.Terminal.Window`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/window.ex#L1)

Represents a terminal window with its properties and state.

This module provides functionality for managing terminal windows, including:
* Window creation and configuration
* State management (active, inactive, minimized, maximized)
* Size and position control
* Parent-child window relationships
* Terminal emulator integration

## Window States

* `:active` - Window is currently focused
* `:inactive` - Window is not focused
* `:minimized` - Window is minimized
* `:maximized` - Window is maximized

## Usage

```elixir
# Create a new window with default size
window = Window.new(Config.new())

# Create a window with custom dimensions
window = Window.new(100, 50)

# Update window title
{:ok, window} = Window.set_title(window, "My Terminal")
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Window{
  children: [String.t()],
  clipboard: String.t(),
  config: Raxol.Terminal.Config.t(),
  cursor_shape: String.t(),
  emulator: Raxol.Terminal.Emulator.Struct.t(),
  font: String.t(),
  height: integer(),
  icon_name: String.t(),
  id: String.t() | nil,
  parent: String.t() | nil,
  position: window_position(),
  previous_size: window_size() | nil,
  size: window_size(),
  state: window_state(),
  title: String.t(),
  width: integer()
}
```

# `window_position`

```elixir
@type window_position() :: {integer(), integer()}
```

# `window_size`

```elixir
@type window_size() :: {integer(), integer()}
```

# `window_state`

```elixir
@type window_state() :: :active | :inactive | :minimized | :maximized
```

# `add_child`

Adds a child window.

# `clear_hyperlink`

Clears a hyperlink by ID.

# `get_children`

Gets the window's child windows.

# `get_clipboard`

Gets the window's clipboard content.

# `get_cursor_shape`

Gets the window's cursor shape.

# `get_dimensions`

Gets the window's current dimensions.

# `get_font`

Gets the window's font.

# `get_hyperlink`

Gets a hyperlink by ID.

# `get_icon_name`

Gets the window's icon name.

# `get_parent`

Gets the window's parent window.

# `get_position`

Gets the window's current position.

# `get_size`

Gets the window's current size.

# `get_state`

Gets the window's current state.

# `get_working_directory`

Gets the window's working directory.

# `new`

Creates a new window with the given configuration.

## Parameters

  * `config` - Terminal configuration (Config.t())

## Returns

  * A new window instance with the specified configuration

## Examples

    iex> config = Config.new()
    iex> window = Window.new(config)
    iex> window.size
    {80, 24}

# `new`

Creates a new window with custom dimensions.

## Parameters

  * `width` - Window width in characters (positive integer)
  * `height` - Window height in characters (positive integer)

## Returns

  * A new window instance with the specified dimensions

## Examples

    iex> window = Window.new(100, 50)
    iex> window.size
    {100, 50}

# `remove_child`

Removes a child window.

# `restore_size`

Restores the previous window size.

# `set_clipboard`

Updates the window's clipboard content.

# `set_cursor_shape`

Updates the window's cursor shape.

# `set_font`

Updates the window's font.

# `set_hyperlink`

Sets a hyperlink with the given ID and URL.

# `set_icon_name`

Updates the window's icon name.

# `set_parent`

Sets the parent window.

# `set_position`

Updates the window position.

# `set_size`

Updates the window size.

# `set_state`

Updates the window state.

# `set_title`

Updates the window title.

## Parameters

  * `window` - The window to update
  * `title` - New window title

## Returns

  * `{:ok, updated_window}` - Title updated successfully
  * `{:error, reason}` - Failed to update title

## Examples

    iex> window = Window.new(80, 24)
    iex> {:ok, window} = Window.set_title(window, "My Terminal")
    iex> window.title
    "My Terminal"

# `set_working_directory`

Sets the window's working directory.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
