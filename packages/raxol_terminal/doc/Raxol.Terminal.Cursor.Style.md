# `Raxol.Terminal.Cursor.Style`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/cursor/style.ex#L1)

Handles cursor style and visibility control for the terminal emulator.

This module provides functions for changing cursor appearance, controlling
visibility, and managing cursor blinking.

# `blink`

```elixir
@callback blink(cursor :: Raxol.Terminal.Cursor.Manager.t()) ::
  Raxol.Terminal.Cursor.Manager.t()
```

# `get_blink`

```elixir
@callback get_blink(cursor :: Raxol.Terminal.Cursor.Manager.t()) :: boolean()
```

# `get_state`

```elixir
@callback get_state(cursor :: Raxol.Terminal.Cursor.Manager.t()) :: atom()
```

# `get_style`

```elixir
@callback get_style(cursor :: Raxol.Terminal.Cursor.Manager.t()) :: atom()
```

# `hide`

```elixir
@callback hide(cursor :: Raxol.Terminal.Cursor.Manager.t()) ::
  Raxol.Terminal.Cursor.Manager.t()
```

# `set_bar`

```elixir
@callback set_bar(cursor :: Raxol.Terminal.Cursor.Manager.t()) ::
  Raxol.Terminal.Cursor.Manager.t()
```

# `set_blink_rate`

```elixir
@callback set_blink_rate(
  cursor :: Raxol.Terminal.Cursor.Manager.t(),
  rate :: integer()
) :: Raxol.Terminal.Cursor.Manager.t()
```

# `set_block`

```elixir
@callback set_block(cursor :: Raxol.Terminal.Cursor.Manager.t()) ::
  Raxol.Terminal.Cursor.Manager.t()
```

# `set_custom`

```elixir
@callback set_custom(
  cursor :: Raxol.Terminal.Cursor.Manager.t(),
  shape :: term(),
  dimensions :: term()
) :: Raxol.Terminal.Cursor.Manager.t()
```

# `set_underline`

```elixir
@callback set_underline(cursor :: Raxol.Terminal.Cursor.Manager.t()) ::
  Raxol.Terminal.Cursor.Manager.t()
```

# `show`

```elixir
@callback show(cursor :: Raxol.Terminal.Cursor.Manager.t()) ::
  Raxol.Terminal.Cursor.Manager.t()
```

# `toggle_blink`

```elixir
@callback toggle_blink(cursor :: Raxol.Terminal.Cursor.Manager.t()) ::
  Raxol.Terminal.Cursor.Manager.t()
```

# `toggle_visibility`

```elixir
@callback toggle_visibility(cursor :: Raxol.Terminal.Cursor.Manager.t()) ::
  Raxol.Terminal.Cursor.Manager.t()
```

# `update_blink`

```elixir
@callback update_blink(cursor :: Raxol.Terminal.Cursor.Manager.t()) ::
  {Raxol.Terminal.Cursor.Manager.t(), boolean()}
```

# `blink`

Makes the cursor blink.

## Examples

    iex> alias Raxol.Terminal.Cursor.{Manager, Style}
    iex> cursor = Manager.new()
    iex> cursor = Style.blink(cursor)
    iex> cursor.state
    :blinking

# `get_blink`

Gets the current cursor blink mode.

## Examples

    iex> alias Raxol.Terminal.Cursor.{Manager, Style}
    iex> cursor = Manager.new()
    iex> Style.get_blink(cursor)
    true

# `get_state`

Gets the current cursor state.

## Examples

    iex> alias Raxol.Terminal.Cursor.{Manager, Style}
    iex> cursor = Manager.new()
    iex> Style.get_state(cursor)
    :visible

# `get_style`

Gets the current cursor style.

## Examples

    iex> alias Raxol.Terminal.Cursor.{Manager, Style}
    iex> cursor = Manager.new()
    iex> Style.get_style(cursor)
    :block

# `hide`

Hides the cursor.

## Examples

    iex> alias Raxol.Terminal.Cursor.{Manager, Style}
    iex> cursor = Manager.new()
    iex> cursor = Style.hide(cursor)
    iex> cursor.state
    :hidden

# `set_bar`

Sets the cursor style to bar.

## Examples

    iex> alias Raxol.Terminal.Cursor.{Manager, Style}
    iex> cursor = Manager.new()
    iex> cursor = Style.set_bar(cursor)
    iex> cursor.style
    :bar

# `set_blink_rate`

Sets the cursor blink rate in milliseconds.

## Examples

    iex> alias Raxol.Terminal.Cursor.{Manager, Style}
    iex> cursor = Manager.new()
    iex> cursor = Style.set_blink_rate(cursor, 1000)
    iex> cursor.blink_rate
    1000

# `set_block`

Sets the cursor style to block.

## Examples

    iex> alias Raxol.Terminal.Cursor.{Manager, Style}
    iex> cursor = Manager.new()
    iex> cursor = Style.set_block(cursor)
    iex> cursor.style
    :block

# `set_custom`

Sets a custom cursor shape.

## Examples

    iex> alias Raxol.Terminal.Cursor.{Manager, Style}
    iex> cursor = Manager.new()
    iex> cursor = Style.set_custom(cursor, "█", {2, 1})
    iex> cursor.style
    :custom
    iex> cursor.custom_shape
    "█"

# `set_underline`

Sets the cursor style to underline.

## Examples

    iex> alias Raxol.Terminal.Cursor.{Manager, Style}
    iex> cursor = Manager.new()
    iex> cursor = Style.set_underline(cursor)
    iex> cursor.style
    :underline

# `show`

Makes the cursor visible.

## Examples

    iex> alias Raxol.Terminal.Cursor.{Manager, Style}
    iex> cursor = Manager.new()
    iex> cursor = Manager.set_state(cursor, :hidden)
    iex> cursor = Style.show(cursor)
    iex> cursor.state
    :visible

# `toggle_blink`

Toggles the cursor blinking state.

## Examples

    iex> alias Raxol.Terminal.Cursor.{Manager, Style}
    iex> cursor = Manager.new()
    iex> cursor = Style.toggle_blink(cursor)
    iex> cursor.state
    :blinking
    iex> cursor = Style.toggle_blink(cursor)
    iex> cursor.state
    :visible

# `toggle_visibility`

Toggles the cursor visibility.

## Examples

    iex> alias Raxol.Terminal.Cursor.{Manager, Style}
    iex> cursor = Manager.new()
    iex> cursor = Style.toggle_visibility(cursor)
    iex> cursor.state
    :hidden
    iex> cursor = Style.toggle_visibility(cursor)
    iex> cursor.state
    :visible

# `update_blink`

Updates the cursor blink state and returns the updated cursor and visibility.

## Examples

    iex> alias Raxol.Terminal.Cursor.{Manager, Style}
    iex> cursor = Manager.new()
    iex> cursor = Style.blink(cursor)
    iex> {_cursor, visible} = Style.update_blink(cursor)
    iex> is_boolean(visible)
    true

---

*Consult [api-reference.md](api-reference.md) for complete listing*
