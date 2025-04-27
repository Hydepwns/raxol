# Raxol UI Components

This guide provides an overview of the built-in UI components available in Raxol for building your terminal applications.

## Using Components

Components are the building blocks of your user interface. You define how they are arranged and what data they display within the `render/1` callback of your `Raxol.App` module. As detailed in the [Getting Started Tutorial](quick_start.md), you can use either the HEEx sigil (`~H`) or the `Raxol.View` module with component functions.

When using `Raxol.View`, you typically do the following:

```elixir
defmodule MyApp.View do
  use Raxol.Core.Runtime.Application
  use Raxol.View          # Enable the view macro and component functions
  import Raxol.View.Elements # Optional: Import for direct component calls (e.g., box(...))

  @impl true
  def render(assigns) do
    view do
      # Use component functions here
      box border: :single do
        text content: "Hello, Components!"
      end
    end
  end
end
```

Component attributes are passed as keyword lists or maps.

## Common Components

Here are some of the core components provided by Raxol:

### `<box>`

A fundamental container component, often used to group other elements and apply borders or padding.

**Attributes:**

- `border`: Defines the border style (e.g., `:single`, `:double`, `:none`).
- `padding`: Adds space inside the border (e.g., `1`, `%{top: 1, bottom: 1}`).
- `margin`: Adds space outside the border.
- `title`: Displays a title within the top border.
- `width`, `height`: Specifies dimensions.

**Example:**

```elixir
~H\"""
<box border="single" padding={1} title="My Box" style={%{bg_color: :dark_grey}}>
  <text>Content inside the box</text>
</box>
\"""
```

### `<text>`

Displays static or dynamic text content.

**Attributes:**

- `content`: The string to display.
- `style`: Apply text styles from the theme (e.g., `%{color: :cyan, attributes: [:bold]}`).

**Example:**

```elixir
~H\"""
<text content="Important Notice" style={%{color: :yellow, attributes: [:bold]}} />
\"""
```

### `<panel>`

Similar to `box`, often used as a primary container or section divider. Can include a title.

**Attributes:**

- `title`: Text displayed in the panel's top border.
- `border`: Border style (e.g., `:single`).
- `width`, `height`: Specifies dimensions.
- `style`: Apply theme styles.

**Example:**

```elixir
~H\"""
<panel title="Settings" border="single">
  <!-- Other components... -->
  <text>Some setting</text>
</panel>
\"""
```

## Layout Components

Raxol primarily uses a grid-based system for complex layouts.

### `<grid>`

Arranges child components in a grid with a specified number of columns and rows.

**Attributes:**

- `columns` (integer, default: 1): The number of columns in the grid.
- `rows` (integer, default: calculated): The number of rows. If omitted, it's calculated based on the number of children and columns.
- `gap_x` (integer, default: 1): The horizontal gap (in characters) between columns.
- `gap_y` (integer, default: 1): The vertical gap (in characters) between rows.
- `style`: Apply theme styles to the grid container itself (e.g., background).

**Child Attributes:**

Child components placed directly inside a `<grid>` can have these attributes:

- `col_span` (integer, default: 1): How many columns the child should span.
- `row_span` (integer, default: 1): How many rows the child should span.

**Behavior:**

- Children are placed sequentially, filling cells left-to-right, then top-to-bottom.
- The available space within the grid (defined by its own `width` / `height` or the parent container) is divided equally among the defined rows and columns after accounting for gaps.
- Each child receives the space corresponding to the cell(s) it occupies (including spans).

**Example (2x2 Grid):**

```elixir
~H\"""
<grid columns={2} rows={2} gap_x={2} gap_y={1} style={%{width: 40, height: 10}}>
  <panel title="Top Left" border="single" />
  <panel title="Top Right" border="single" />
  <panel title="Bottom Left" border="single" />
  <panel title="Bottom Right" border="single" />
</grid>
\"""
```

**Example (Spanning Item):**

```elixir
~H\"""
<grid columns={3} rows={2} gap_x={1} gap_y={0}>
  <panel title="A" border="single" />
  <panel title="B (Spans 2 Cols)" border="single" col_span={2} />
  <panel title="C (Spans 2 Rows)" border="single" row_span={2} />
  <panel title="D" border="single" />
  <panel title="E" border="single" />
  <!-- Note: C spans row 1 & 2 in col 0. D fills row 1, col 1. E fills row 1, col 2. -->
</grid>
\"""
```

### `<label>`

Displays simple text, often used alongside form inputs or other elements.

**Attributes:**

- `content`: The text to display.
- `for`: (Potentially associates the label with another element - needs verification).

**Example:**

```elixir
~H\"""
<label content="Enter your name:" />
\"""
```

### `<button>`

An interactive element that triggers a message when clicked or activated.

**Attributes:**

- `label`: The text displayed on the button.
- `on_click`: The message to send to the `update/2` callback when the button is activated.
- `variant`: (Optional) Style variant (e.g., `:primary`).

**Example:**

```elixir
~H\"""
<button label="Increment Count" on_click=":increment" />
\"""
```

### `<Table>`

A component for displaying data in a structured tabular format.

**Note:** This component is defined in `Raxol.UI.Components.Display.Table`. Refer to the source code or specific examples (`examples/components/table_example.exs` if it exists) for detailed usage, including how to pass headers and data.

**Basic Usage (Conceptual):**

```elixir
# Assuming headers and data are assigned
~H\"""
<Table headers={@my_headers} data={@my_data} />
\"""
```

## Placeholder / WIP Components

The following components have been considered or were seen as placeholders in early examples (`examples/basic/rendering.exs`) but may not be fully implemented yet. Their availability and functionality should be verified in the source code or examples.

- `Tree`
- `Chart`
- `Sparkline`

Please refer to the specific examples or source code for the latest status on these potential components.

## Other Available Components

Besides the common components listed above, Raxol provides others, including:

- Input Components (e.g., `<TextInput>`, `<MultiLineInput>`, `<Checkbox>`, `<Dropdown>`) - See `lib/raxol/ui/components/input/`
- Display Components (e.g., `<Progress>`, `<Spinner>`) - See `lib/raxol/ui/components/display/`
- Specialized Components (e.g., `<Modal>`, `<HintDisplay>`) - Location may vary.

Refer to the source code in `lib/raxol/ui/components/` and specific examples for details on their usage and attributes.

## Visualization Placeholders

The core framework focuses on terminal UI elements. Advanced visualizations like charts and treemaps are handled via the `Raxol.Plugins.VisualizationPlugin`.

- **Charts & Treemaps**: Rendered by the visualization plugin when it encounters specific placeholder elements in the view. See the plugin's documentation and examples for details.
- **Sparkline**: Not currently implemented as a standard component.
- **Tree**: Not currently implemented as a standard component.
