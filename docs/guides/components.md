# Raxol UI Components

This guide provides an overview of the built-in UI components available in Raxol for building your terminal applications.

## Using Components

Components are the building blocks of your user interface. You define how they are arranged and what data they display within the `render/1` callback of your `Raxol.App` module. As detailed in the [Getting Started Tutorial](quick_start.md), you can use either the HEEx sigil (`~H`) or the `Raxol.View` module with component functions.

When using `Raxol.View`, you typically do the following:

```elixir
defmodule MyApp.View do
  use Raxol.App
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

### `<box>` / `box`

A fundamental container component, often used to group other elements and apply borders or padding.

**Attributes:**

- `border`: Defines the border style (e.g., `:single`, `:double`, `:none`).
- `padding`: Adds space inside the border (e.g., `1`, `%{top: 1, bottom: 1}`).
- `margin`: Adds space outside the border.
- `title`: Displays a title within the top border.
- `width`, `height`: Specifies dimensions.

**Example:**

```elixir
view do
  box border: :single, padding: 1, title: "My Box" do
    text content: "Content inside the box"
  end
end
```

### `<text>` / `text`

Displays static or dynamic text content.

**Attributes:**

- `content`: The string to display.
- `color`: Text color (e.g., `:cyan`, `:red`).
- `bg_color`: Background color.
- `attributes`: List of text styles (e.g., `[:bold, :underline, :italic]`).

**Example:**

```elixir
view do
  text content: "Important Notice", color: :yellow, attributes: [:bold]
end
```

### `<panel>` / `panel`

Similar to `box`, often used as a primary container or section divider. Can include a title.

**Attributes:**

- `title`: Text displayed in the panel's top border.
- `border`: Border style (e.g., `:single`).
- `width`, `height`: Specifies dimensions.

**Example:**

```elixir
view do
  panel title: "Settings", border: :single do
    # Other components...
  end
end
```

### `<row>` / `row` & `<column>` / `column`

Layout components used to arrange child elements horizontally (`row`) or vertically (`column`). They often contain child components that specify a `size` attribute for proportional distribution.

See the [Layout System and Proportional Sizing](#layout-system-and-proportional-sizing) section below for a detailed explanation of how `size` works.

**Attributes (for Children):**

- `size`: An integer representing the proportional size the child should occupy within the row/column.

**Example (`row`):**

```elixir
view do
  row do
    panel title: "Left Panel", size: 1 do
      # Content...
    end
    panel title: "Right Panel", size: 2 do
      # Content... (Takes twice the width of the left panel)
    end
  end
end
```

**Example (`column`):**

```elixir
view do
  column do
    box size: 1 do # Top section
      text content: "Top"
    end
    box size: 1 do # Bottom section
      text content: "Bottom"
    end
  end
end
```

## Layout System and Proportional Sizing

The `<row>` and `<column>` components are the primary tools for arranging elements in your UI. Their power comes from how they distribute available space among their direct children.

**Key Concept: The `size` Attribute**

When you place components directly inside a `<row>` or `<column>`, you can add a `size` attribute to those child components. This attribute dictates how the available space (horizontal space for `<row>`, vertical space for `<column>`) is divided proportionally.

- **Calculation:** The total available space is divided based on the _sum_ of the `size` values of all children. Each child then receives a fraction of the space corresponding to its `size` value relative to the total.
- **No `size`:** If a child does not have a `size` attribute, it's typically rendered with its minimum required size first, and the remaining space is then distributed among the children that _do_ have a `size`. If no children have `size`, they might be sized based on their content or share space equally (behavior might vary).
- **Units:** The `size` value is a relative proportion, not a fixed number of characters or lines. `size: 2` means "take twice as much space as an element with `size: 1`".

**Example Breakdown (`examples/basic/rendering.exs`)**

The rendering example demonstrates this well:

```elixir
view do
  column do
    # Top Row (Takes 1 part of vertical space)
    row size: 1 do
      panel title: "Panel 1", size: 1 do # Takes 1 part of horizontal space
        # ...
      end
      panel title: "Panel 2", size: 2 do # Takes 2 parts of horizontal space
        # ...
      end
    end
    # Bottom Panel (Takes 2 parts of vertical space)
    panel title: "Panel 3", size: 2 do
      # ...
    end
  end
end
```

1.  **Outer `column`:** Divides the _vertical_ space.
    - The `row` child has `size: 1`.
    - The `panel` child (`Panel 3`) has `size: 2`.
    - Total vertical `size` = 1 + 2 = 3.
    - The `row` gets 1/3 of the vertical space.
    - `Panel 3` gets 2/3 of the vertical space.
2.  **Inner `row`:** Divides the _horizontal_ space allocated to it (1/3 of the total height).
    - `Panel 1` has `size: 1`.
    - `Panel 2` has `size: 2`.
    - Total horizontal `size` = 1 + 2 = 3.
    - `Panel 1` gets 1/3 of the row's width.
    - `Panel 2` gets 2/3 of the row's width.

This proportional sizing allows your UI to adapt gracefully to different terminal sizes.

### `<label>` / `label`

Displays simple text, often used alongside form inputs or other elements.

**Attributes:**

- `content`: The text to display.
- `for`: (Potentially associates the label with another element - needs verification).

**Example:**

```elixir
view do
  label content: "Enter your name:"
  # ... text input component (if available)
end
```

### `<button>` / `button`

An interactive element that triggers a message when clicked or activated.

**Attributes:**

- `label`: The text displayed on the button.
- `on_click`: The message to send to the `update/2` callback when the button is activated.
- `variant`: (Optional) Style variant (e.g., `:primary`).

**Example:**

```elixir
view do
  button label: "Increment Count", on_click: :increment
end
```

## Placeholder / WIP Components

The following components were seen as placeholders in examples (`examples/basic/rendering.exs`) but may not be fully implemented yet. Their availability and functionality should be verified.

- `Table`
- `Tree`
- `Chart`
- `Sparkline`

Please refer to the specific examples or source code for the latest status on these components.
