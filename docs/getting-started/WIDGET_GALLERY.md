# Widget Gallery

Raxol ships with 23 widgets organized by category. All are available via the View DSL after `use Raxol.Core.Runtime.Application`.

## Layout

### column

Vertical stack. Children are arranged top-to-bottom.

```elixir
column style: %{gap: 1, padding: 1, align_items: :center} do
  [
    text("First"),
    text("Second"),
    text("Third")
  ]
end
```

### row

Horizontal stack. Children are arranged left-to-right.

```elixir
row style: %{gap: 2} do
  [text("Left"), spacer(), text("Right")]
end
```

### box

Container with optional border and padding.

```elixir
box style: %{border: :single, padding: 1, width: 30} do
  text("Inside a box")
end
```

Border styles: `:single`, `:double`, `:rounded`, `:bold`, `:ascii`

### spacer

Flexible space that fills available room.

```elixir
row do
  [text("Left"), spacer(), text("Right")]
end
```

### divider

Horizontal line separator.

```elixir
column do
  [text("Above"), divider(), text("Below")]
end
```

## Text & Display

### text

Styled text content.

```elixir
text("Hello", style: [:bold])
text("Dimmed", style: [:dim])
text("Alert", style: [:bold, :underline])
```

Style atoms: `:bold`, `:dim`, `:italic`, `:underline`, `:strikethrough`, `:reverse`

### progress

Progress bar indicator.

```elixir
progress(value: 65, max: 100)
```

### list

Render a list of items.

```elixir
list(items: ["Elixir", "Rust", "Go"])
```

### table

Tabular data display with headers, sorting, and row selection.

```elixir
# Via View DSL
table(
  data: [["Alice", "30"], ["Bob", "25"]],
  headers: ["Name", "Age"]
)
```

Component module: `Raxol.UI.Components.Display.Table`

### viewport

Scrollable container for content larger than the visible area.

```elixir
# See examples/components/displays/viewport_demo.exs
```

Component module: `Raxol.UI.Components.Display.Viewport`

### tree

Hierarchical tree view with expand/collapse.

Component module: `Raxol.UI.Components.Display.Tree`

### status_bar

Fixed status bar, typically at the bottom of the screen.

Component module: `Raxol.UI.Components.Display.StatusBar`

### code_block

Syntax-highlighted code display (uses Makeup for highlighting).

```elixir
# See examples/components/displays/code_block_demo.exs
```

Component module: `Raxol.UI.Components.CodeBlock`

### markdown_renderer

Renders markdown text with formatting.

```elixir
# See examples/components/displays/markdown_demo.exs
```

Component module: `Raxol.UI.Components.MarkdownRenderer`

## Input

### button

Clickable button that sends a message on click.

```elixir
button("Save", on_click: :save)
button("Delete", on_click: :delete)
```

Component module: `Raxol.UI.Components.Input.Button`

### text_input

Single-line text input field.

```elixir
text_input(value: model.name, placeholder: "Enter name...")
```

Component module: `Raxol.UI.Components.Input.TextInput`

### checkbox

Toggle checkbox.

```elixir
checkbox(checked: model.agreed, label: "I agree")
```

Component module: `Raxol.UI.Components.Input.Checkbox`

### select_list

Scrollable selection list with search, pagination, and multi-select.

```elixir
# See examples/components/navigation/select_list_showcase.ex
```

Component module: `Raxol.UI.Components.Input.SelectList`

### multi_line_input

Multi-line text editor with undo/redo.

```elixir
# See examples/components/input/multi_line_input_demo.exs
```

Component module: `Raxol.UI.Components.Input.MultiLineInput`

### tabs

Tab navigation component.

Component module: `Raxol.UI.Components.Input.Tabs`

### menu

Dropdown or context menu.

Component module: `Raxol.UI.Components.Input.Menu`

## Overlay

### modal

Modal dialog with customizable content and actions.

Component module: `Raxol.UI.Components.Modal`

## Progress

### progress/bar

Standard horizontal progress bar.

Component module: `Raxol.UI.Components.Progress.Bar`

### progress/spinner

Animated spinner indicator.

Component module: `Raxol.UI.Components.Progress.Spinner`

### progress/circular

Circular progress indicator.

Component module: `Raxol.UI.Components.Progress.Circular`

## Advanced

### process_component

Run a component in its own supervised process for crash isolation.

```elixir
# In your view:
process_component(MyWidget, %{path: "."})
```

If MyWidget crashes, it restarts automatically without affecting the rest of the app.

See `examples/components/process_component_demo.exs`.

### focus_ring

Visual focus indicator that follows keyboard navigation.

Component module: `Raxol.UI.Components.FocusRing`

## Using Components Directly

For advanced usage, components can be used as GenServers:

```elixir
alias Raxol.UI.Components.Input.TextInput

{:ok, state} = TextInput.init(%{id: "name", value: "", placeholder: "Name..."})
state = TextInput.handle_event(%Event{type: :key, data: %{char: "H"}}, state, context)
rendered = TextInput.render(state, context)
```

## Running Examples

```bash
# Showcase with all widget categories
mix run examples/apps/showcase_app.exs

# Individual widget demos
mix run examples/components/displays/viewport_demo.exs
mix run examples/components/displays/code_block_demo.exs
mix run examples/components/displays/markdown_demo.exs
mix run examples/components/input/multi_line_input_demo.exs
mix run examples/components/process_component_demo.exs
```
