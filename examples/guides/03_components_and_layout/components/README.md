---
title: Raxol UI Components & Layout
description: Overview of Raxol UI Components and the Layout System
date: 2025-05-10
author: Raxol Team
section: guides
tags: [components, layout, ui, guides, documentation]
---

# Raxol UI Components & Layout

_Raxol 0.8.0 is a full-stack terminal application framework with web interface support, plugin system, and enterprise features. Make sure you are using the latest version for the best experience!_

This document overviews the Raxol UI component system (`Base.Component` behaviour, `View.Elements` DSL, HEEx-like syntax) and the flexbox-inspired layout engine.

## Core Concepts

- **Components:** Reusable UI elements that manage their own state and rendering logic. They implement the `Raxol.UI.Components.Base.Component` behaviour.
- **View Definition:** Describes the structure and appearance of the UI. Raxol primarily uses a DSL based on `Raxol.View.Elements` macros, but also supports HEEx-like syntax (`~H`) in some contexts.
- **Layout Engine:** Calculates the size and position of elements within the terminal window based on the view structure and component styles.
- **Renderer:** Converts the calculated layout into styled character cells for display in the terminal.

## Component Behaviour (`Raxol.UI.Components.Base.Component`)

Custom components should typically implement this behaviour:

- `init/1`: Initializes the component's state.
- `update/2`: Handles messages sent to the component (optional).
- `handle_event/3`: Processes user input events like keyboard or mouse clicks (optional).
- `render/2`: Returns the component's view structure using one of the view definition methods.

## Defining Views

You define your application's UI within the `render/2` callback of your `Raxol.Core.Runtime.Application` module or a custom component.

### 1. Using `Raxol.View.Elements` Macros (Primary Method)

This approach uses Elixir macros for a more programmatic feel.

```elixir
defmodule MyApp.MyView do
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements # Import macros like view, box, text, etc.

  @impl true
  def render(assigns) do
    # Use the view macro as the root
    view do
      panel title: "Layout Example", style: [padding: 1] do
        box style: [flex_direction: :row, justify_content: :space_between] do
          text(content: "Left Text")
          button(label: "Click Me", on_click: :button_pressed)
        end
      end
    end
  end

  @impl true
  def handle_event({:click, :button_pressed}, state) do
    # Handle button click
    {:noreply, state}
  end

  # Other Application callbacks...
end
```

### 2. Using HEEx-like Sigil (`~H`)

Raxol also supports a syntax inspired by Surface/Phoenix LiveView's HEEx for defining views, which might feel more familiar to web developers.

```elixir
defmodule MyApp.MyView do
  use Raxol.Core.Runtime.Application
  # NOTE: `use Raxol.View` might be needed depending on setup
  # and how HEEx support is integrated. Check latest examples.

  @impl true
  def render(assigns) do
    ~H"""
    <panel title="Layout Example" border="single" padding={1}>
      <box style={%{flex_direction: :row, justify_content: :space_between}}>
        <text content="Left Text"/>
        <button label="Click Me" on_click={:button_pressed}/>
      </box>
    </panel>
    """
  end

  @impl true
  def handle_event({:click, :button_pressed}, state) do
    # Handle button click
    {:noreply, state}
  end

  # Other Application callbacks...
end
```

Component attributes are passed as keyword lists or maps in both syntaxes.

## Layout Components

Raxol provides several components primarily focused on structuring the UI layout.

### `<box>` / `box/1`

A fundamental container component, often used to group other elements and apply layout properties, borders, or padding.

**Attributes / Options:**

- `border`: Defines the border style (e.g., `:single`, `:double`, `:none`).
- `padding`: Adds space inside the border (e.g., `1`, `%{top: 1, bottom: 1}`).
- `margin`: Adds space outside the border.
- `title`: Displays a title within the top border.
- `width`, `height`: Specifies dimensions. Can use integers (cells), percentages (`"50%"`), or `:auto`.
- `flex_direction`: `:row` or `:column` (default: `:column`).
- `justify_content`: `:flex_start`, `:flex_end`, `:center`, `:space_between`, `:space_around`.
- `align_items`: `:flex_start`, `:flex_end`, `:center`, `:stretch` (default: `:stretch`).
- `style`: Apply theme styles (background color, text attributes, etc. - e.g., `[bg_color: :dark_grey, padding: 1]`).

**Example (`View.Elements`):**

```elixir
box border: :single, padding: 1, title: "My Box", style: [bg_color: :dark_grey] do
  text content: "Content inside the box"
end
```

**Example (`~H`):**

```elixir
~H"""
<box border="single" padding={1} title="My Box" style={%{bg_color: :dark_grey}}>
  <text content="Content inside the box"/>
</box>
"""
```

### `<panel>` / `panel/1`

Similar to `box`, often used as a primary container or section divider. Includes styling for a title integrated into the top border.

**Attributes / Options:**

- `title`: Text displayed in the panel's top border.
- `border`: Border style (e.g., `:single`, default: `:none`).
- `width`, `height`: Specifies dimensions.
- `padding`: Space inside the border.
- `style`: Apply theme styles.

**Example (`View.Elements`):**

```elixir
panel title: "Settings", border: :single do
  text content: "Some setting"
  button label: "Save", on_click: :save_settings
end
```

**Example (`~H`):**

```elixir
~H"""
<panel title="Settings" border="single">
  <text content="Some setting"/>
  <button label="Save" on_click={:save_settings}/>
</panel>
"""
```

### `<grid>` / `grid/1`

Arranges child components in a grid.

**Attributes / Options:**

- `columns` (integer, default: 1): The number of columns.
- `rows` (integer, default: calculated): The number of rows. If omitted, it's calculated based on children and columns.
- `gap_x` (integer, default: 1): Horizontal gap between columns.
- `gap_y` (integer, default: 1): Vertical gap between rows.
- `style`: Styles for the grid container itself (e.g., `[width: 40, height: 10]`).

**Child Attributes (within `grid`):**

- `col_span` (integer, default: 1): Columns the child occupies.
- `row_span` (integer, default: 1): Rows the child occupies.

**Behavior:** Children fill cells left-to-right, top-to-bottom. Space is divided among cells after accounting for gaps.

**Example (2x2 Grid - `View.Elements`):**

```elixir
grid columns: 2, rows: 2, gap_x: 2, gap_y: 1, style: [width: 40, height: 10] do
  panel title: "Top Left", border: :single
  panel title: "Top Right", border: :single
  panel title: "Bottom Left", border: :single
  panel title: "Bottom Right", border: :single
end
```

**Example (Spanning Item - `~H`):**

```elixir
~H"""
<grid columns={3} rows={2} gap_x={1} gap_y={0}>
  <panel title="A" border="single" />
  <panel title="B (Spans 2 Cols)" border="single" col_span={2} />
  <panel title="C (Spans 2 Rows)" border="single" row_span={2} />
  <panel title="D" border="single" />
  <panel title="E" border="single" />
  <!-- Note: C spans row 1 & 2 in col 0. D fills row 1, col 1. E fills row 1, col 2. -->
</grid>
"""
```

## Common UI Components

### `<text>` / `text/1`

Displays static or dynamic text content.

**Attributes / Options:**

- `content`: The string to display.
- `style`: Apply text styles from the theme (e.g., `[color: :cyan, attributes: [:bold]]`).

**Example (`View.Elements`):**

```elixir
text content: "Important Notice", style: [color: :yellow, attributes: [:bold]]
```

**Example (`~H`):**

```elixir
~H"""
<text content="Important Notice" style={%{color: :yellow, attributes: [:bold]}} />
"""
```

### `<label>` / `label/1`

Displays simple text, often used alongside form inputs. Semantically similar to `<text>`, but might have specific styling or accessibility implications in the future.

**Attributes / Options:**

- `content`: The text to display.
- `for`: (Future) May associate the label with an input element's ID for accessibility.

**Example (`View.Elements`):**

```elixir
label content: "Enter your name:"
```

### `<button>` / `button/1`

An interactive element that triggers a message when clicked or activated (e.g., via Enter key when focused).

**Attributes / Options:**

- `label`: The text displayed on the button.
- `on_click`: The message (usually an atom or tuple) sent to the `handle_event/2` or `update/2` callback when activated.
- `variant`: (Optional) Style variant from the theme (e.g., `:primary`, `:danger`).
- `style`: Custom styles.

**Example (`View.Elements`):**

```elixir
button label: "Increment Count", on_click: :increment
```

## Other Available Components

Raxol provides many other components located in `lib/raxol/ui/components/`.

**Input Components (`lib/raxol/ui/components/input/`):**

- `text_input`: Single-line text input field.
- `multi_line_input`: Multi-line text editor.
- `checkbox`: A toggleable checkbox.
- `radio_group`: Select one option from a group.
- `select_list`: Select one or more items from a scrollable list.
- `slider`: Select a value within a range.
- `form`: (Likely) Groups related input components.

### `<multi_line_input>` / `multi_line_input/1`

A multi-line text editor component supporting line wrapping, scrolling, selection, clipboard, and accessibility features. Now harmonized with the modern component system (style/theme merging, accessibility props, lifecycle hooks).

**Attributes / Options:**

- `value`: The current text value (string, default: "").
- `placeholder`: Placeholder text when empty (string, default: "").
- `width`, `height`: Dimensions in cells (integers, default: 40x10).
- `wrap`: Line wrapping mode (`:none`, `:char`, `:word`, default: `:word`).
- `style`: Custom styles (map, merged with theme and context styles).
- `theme`: Theme overrides (map, merged with context theme).
- `aria_label`: Accessibility label (string, optional).
- `tooltip`: Tooltip/help text (string, optional).
- `on_change`: Callback when text changes (function, optional).

**Example (`View.Elements`):**

```elixir
multi_line_input \
  value: state.notes,
  placeholder: "Enter notes...",
  width: 60,
  height: 8,
  wrap: :word,
  style: [text_color: :cyan, selection_color: :magenta],
  theme: %{cursor_color: :yellow},
  aria_label: "Notes field",
  tooltip: "Type your notes here",
  on_change: fn new_text -> send(self(), {:notes_changed, new_text}) end
```

**Example (`~H`):**

```elixir
~H"""
<multi_line_input
  value={@notes}
  placeholder="Enter notes..."
  width={60}
  height={8}
  wrap=":word"
  style={%{text_color: :cyan, selection_color: :magenta}}
  theme={%{cursor_color: :yellow}}
  aria_label="Notes field"
  tooltip="Type your notes here"
  on_change={&handle_notes_change/1}
/>
"""
```

**Display Components (`lib/raxol/ui/components/display/`):**

- `table`: Displays tabular data. Takes data and column definitions directly via attributes (e.g., `:headers`, `:data`) after refactoring.
- `spinner`: Shows an animated loading indicator.
- `progress` / `progress_bar`: Visualizes progress.

**Other (`lib/raxol/ui/components/`):**

- `modal`: Displays content in a layer above the main UI.
- `hint_display`: Shows contextual hints or shortcuts.
- `focus_ring`: Visual indicator for the focused element.

_(Note: This list is based on the current structure and previous documentation. Always check the source directory and specific component modules for the most up-to-date attributes and usage.)_

**Example (`Table` - Conceptual):**

```elixir
# In your Application or Component:
assigns = %{
  my_headers: [%{label: "ID"}, %{label: "Name"}],
  my_data: [%{id: 1, name: "Alice"}, %{id: 2, name: "Bob"}]
}

# In render/2 using View.Elements:
table headers: assigns.my_headers, data: assigns.my_data

# In render/2 using ~H:
~H"""
<Table headers={@my_headers} data={@my_data} />
"""
```

## Visualization Placeholders

Advanced visualizations like charts and treemaps are handled via the `Raxol.Plugins.VisualizationPlugin`. The plugin looks for specific placeholder elements (like `:chart`, `:treemap`, `:image`) in the view definition returned by your application or components and replaces them with the rendered visualization. Refer to the plugin's documentation or examples for details on required attributes for these placeholders.

## Layout System Details

The layout engine uses a flexbox-inspired approach. Control layout using style attributes (`:flex_direction`, `:justify_content`, `:align_items`, `:width`, `:height`, `:padding`, `:margin`, `:flex_grow`, etc.) within the `View.Elements` macros or component tags.

Refer to specific component documentation and examples for more details.

## Creating Custom Components

1. Create a new module, e.g., `lib/raxol/ui/components/my_custom_component.ex`.
2. `use Raxol.UI.Components.Base.Component`.
3. Implement the required callbacks (`init/1`, `render/2`) and optional callbacks (`handle_event/3`, `update/2`).
4. Use `Raxol.View.Elements` macros or `~H` within your `render/2` function to define the component's structure.
5. Integrate your component into your application's `render/2` function using its module name as a function (`MyCustomComponent.render(assigns)`) or potentially as a tag (`<MyCustomComponent attr={value}/>` if HEEx integration supports it).
