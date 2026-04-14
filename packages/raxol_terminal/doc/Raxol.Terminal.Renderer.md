# `Raxol.Terminal.Renderer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/renderer.ex#L1)

Terminal renderer module.

This module handles rendering of terminal output using ANSI escape codes,
including:
- Character cell rendering
- Text styling (colors, bold, italic, underline)
- Cursor rendering
- Performance optimizations (style batching, caching)

## Integration with Other Modules

The Renderer module works closely with several specialized modules:

### Manipulation Module
- Receives text and style updates from the Manipulation module
- Renders text with proper styling and positioning
- Handles text insertion, deletion, and modification

### Selection Module
- Renders text selections with visual highlighting
- Supports multiple selections
- Handles selection state changes

### Validation Module
- Renders validation errors and warnings
- Applies visual indicators for invalid input
- Shows validation state through styling

## Performance Optimizations

The renderer includes several optimizations:
- Only renders changed cells
- Batches style updates for consecutive cells
- Minimizes terminal output
- Caches rendered output when possible

## Usage

```elixir
# Create a new renderer
buffer = ScreenBuffer.new(80, 24)
renderer = Renderer.new(buffer)

# Render with selection
selection = %{selection: {0, 0, 0, 5}}
output = Renderer.render(renderer, selection: selection)

# Render with validation
validation = Validation.validate_input(buffer, 0, 0, "text")
output = Renderer.render(renderer, validation: validation)
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Renderer{
  cursor: {non_neg_integer(), non_neg_integer()} | nil,
  font_settings: map(),
  screen_buffer: Raxol.Terminal.ScreenBuffer.t(),
  style_batching: term(),
  style_cache: map(),
  theme: map()
}
```

# `clear_cursor`

Clears the cursor position.

## Examples

    iex> screen_buffer = ScreenBuffer.new(80, 24)
    iex> renderer = Renderer.new(screen_buffer)
    iex> renderer = Renderer.set_cursor(renderer, {10, 5})
    iex> renderer = Renderer.clear_cursor(renderer)
    iex> renderer.cursor
    nil

# `get_content`

Gets the current content of the screen buffer.

## Parameters
  * `renderer` - The renderer to get content from
  * `opts` - Options for content retrieval
    * `:include_style` - Whether to include style information (default: false)
    * `:include_cursor` - Whether to include cursor position (default: false)

## Returns
  * `{:ok, content}` - The current content
  * `{:error, reason}` - If content retrieval fails

## Examples
    iex> get_content(renderer)
    {:ok, "Hello, World!"}

# `new`

Creates a new renderer with the given screen buffer.

## Examples

    iex> screen_buffer = ScreenBuffer.new(80, 24)
    iex> renderer = Renderer.new(screen_buffer)
    iex> renderer.screen_buffer
    %ScreenBuffer{}

# `render`

Renders the terminal content without additional options.

# `render`

Renders the terminal content.

# `render`

Renders the terminal content with additional options.

# `set_cursor`

Sets the cursor position.

## Examples

    iex> screen_buffer = ScreenBuffer.new(80, 24)
    iex> renderer = Renderer.new(screen_buffer)
    iex> renderer = Renderer.set_cursor(renderer, {10, 5})
    iex> renderer.cursor
    {10, 5}

# `set_font_settings`

Updates the font settings.

## Examples

    iex> screen_buffer = ScreenBuffer.new(80, 24)
    iex> renderer = Renderer.new(screen_buffer)
    iex> settings = %{family: "Fira Code"}
    iex> renderer = Renderer.set_font_settings(renderer, settings)
    iex> renderer.font_settings
    %{family: "Fira Code"}

# `set_theme`

Updates the theme settings.

## Examples

    iex> screen_buffer = ScreenBuffer.new(80, 24)
    iex> renderer = Renderer.new(screen_buffer)
    iex> theme = %{foreground: %{default: "#FFF"}}
    iex> renderer = Renderer.set_theme(renderer, theme)
    iex> renderer.theme
    %{foreground: %{default: "#FFF"}}

# `start_link`

Starts a new renderer process.

# `stop`

Stops the renderer process.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
