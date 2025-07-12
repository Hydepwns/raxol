defmodule Raxol.View.Elements do
  @moduledoc """
  Basic UI elements for Raxol views.

  This module defines the core UI elements that can be used
  in Raxol views.
  """

  import Raxol.Guards

  @doc """
  Creates a panel with a title and content.

  ## Options

  * `:title` - The panel title
  * `:height` - The panel height (optional)
  * `:width` - The panel width (optional)

  ## Example

  ```elixir
  panel title: "Information" do
    label content: "Some information"
  end
  ```
  """
  defmacro panel(opts \\ [], do: block) do
    quote do
      %{
        type: :panel,
        attrs: unquote(opts),
        children: unquote(block)
      }
    end
  end

  @doc """
  Creates a row layout for horizontal arrangement.

  ## Example

  ```elixir
  row do
    label content: "Left"
    label content: "Right"
  end
  ```
  """
  defmacro row(opts \\ [], do: block) do
    quote do
      %{
        type: :row,
        attrs: unquote(opts),
        children: unquote(block)
      }
    end
  end

  @doc """
  Creates a column layout for vertical arrangement.

  ## Options

  * `:size` - The column size (1-12)

  ## Example

  ```elixir
  column size: 6 do
    label content: "Half width"
  end
  ```
  """
  defmacro column(opts \\ [], do: block) do
    quote do
      %{
        type: :column,
        attrs: unquote(opts),
        children: unquote(block)
      }
    end
  end

  @doc """
  Creates a text label.

  ## Options

  * `:content` - The label text
  * Other options are passed as attributes
  """
  defmacro label(opts) when list?(opts) do
    quote do
      %{
        type: :label,
        attrs: unquote(opts)
      }
    end
  end

  # Handle label/1 with just content string for convenience
  defmacro label(content) when is_binary(content) do
    quote do
      %{
        type: :label,
        attrs: [content: unquote(content)]
      }
    end
  end

  @doc """
  Creates a text input field.

  ## Options

  * `:value` - The current input value
  * `:cursor` - The cursor position
  * `:focused` - Whether the input is focused
  * `:placeholder` - Placeholder text
  * `:password` - Whether to mask the input (boolean)
  """
  defmacro input(opts) do
    quote do
      %{type: :input, attrs: unquote(opts)}
    end
  end

  @doc """
  Creates a button that can be clicked.

  ## Options

  * `:label` - The button text
  * `:on_click` - The message to send when clicked

  ## Example

  ```elixir
  button label: "Click me", on_click: :button_clicked
  ```
  """
  defmacro button(opts) do
    quote do
      %{
        type: :button,
        attrs: unquote(opts)
      }
    end
  end

  @doc """
  Creates a text input field.

  ## Options

  * `:value` - The current input value
  * `:placeholder` - Placeholder text
  * `:on_change` - Function to call when value changes

  ## Example

  ```elixir
  text_input value: model.name, placeholder: "Enter your name", on_change: fn value -> {:update_name, value} end
  ```
  """
  defmacro text_input(opts) do
    quote do
      %{
        type: :text_input,
        attrs: unquote(opts)
      }
    end
  end

  @doc """
  Creates a checkbox.

  ## Options

  * `:checked` - Whether the checkbox is checked
  * `:label` - The checkbox label
  * `:on_toggle` - Function to call when toggled

  ## Example

  ```elixir
  checkbox checked: model.agreed, label: "I agree to terms", on_toggle: fn value -> {:update_agreed, value} end
  ```
  """
  defmacro checkbox(opts) do
    quote do
      %{
        type: :checkbox,
        attrs: unquote(opts)
      }
    end
  end

  @doc """
  Creates a table for displaying tabular data.

  ## Options

  * `:headers` - List of column headers
  * `:data` - List of rows, where each row is a list of cells

  ## Example

  ```elixir
  table headers: ["Name", "Age", "City"], data: [["John", "25", "New York"], ["Jane", "30", "San Francisco"]]
  ```
  """
  defmacro table(opts) do
    quote do
      %{
        type: :table,
        attrs: unquote(opts)
      }
    end
  end

  @doc """
  Creates a box container, often used for bordering or grouping.

  ## Options

  * `:style` - Map containing styling attributes (e.g., border, padding)

  ## Example

  ```elixir
  box style: %{border: :single, padding: 1} do
    text content: "Content inside the box"
  end
  ```
  """
  defmacro box(opts \\ [], do: block) do
    quote do
      %{
        type: :box,
        attrs: unquote(opts),
        children: unquote(block)
      }
    end
  end

  @doc """
  Creates a label element with the given text and options.
  """
  defmacro label(text, opts \\ []) do
    quote do
      %{
        type: :label,
        text: unquote(text),
        style: Keyword.get(unquote(opts), :style, %{})
      }
    end
  end
end
