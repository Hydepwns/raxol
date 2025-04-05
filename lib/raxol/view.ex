defmodule Raxol.View do
  @moduledoc """
  A DSL for building terminal user interfaces.
  
  This module provides a declarative way to define UI elements
  using a familiar HTML-like syntax.
  
  ## Example
  
  ```elixir
  use Raxol.View
  
  view do
    panel title: "Welcome" do
      row do
        column size: 6 do
          label content: "Left side"
        end
        column size: 6 do
          label content: "Right side" 
        end
      end
    end
  end
  ```
  """
  
  @type t :: term()
  
  @doc """
  Imports the view DSL for use in the current module.
  """
  defmacro __using__(_opts) do
    quote do
      import Raxol.View
      import Raxol.View.Elements
    end
  end
  
  @doc """
  Creates a view with the given elements.
  
  This is the root of any UI definition.
  
  ## Example
  
  ```elixir
  view do
    panel title: "My App" do
      # Content goes here
    end
  end
  ```
  """
  defmacro view(do: block) do
    quote do
      %{
        type: :view,
        children: unquote(block)
      }
    end
  end

  @doc """
  Creates a panel component.
  """
  def panel(_opts \\ [], fun) when is_function(fun, 0) do
    # TODO: Implement actual panel rendering
    fun.()
  end

  @doc """
  Creates a column component.
  """
  def column(_opts \\ [], fun) when is_function(fun, 0) do
    # TODO: Implement actual column rendering
    fun.()
  end

  @doc """
  Creates a row component.
  """
  def row(_opts \\ [], fun) when is_function(fun, 0) do
    # TODO: Implement actual row rendering
    fun.()
  end

  @doc """
  Creates a text component.
  """
  def text(content, _opts \\ []) when is_binary(content) do
    # TODO: Implement actual text rendering
    content
  end

  @doc """
  Creates a button component.
  """
  def button(_opts \\ [], label) when is_binary(label) do
    # TODO: Implement actual button rendering
    label
  end

  @doc """
  Creates a toast notification.
  """
  def toast(message, _opts \\ []) when is_binary(message) do
    # TODO: Implement actual toast rendering
    message
  end
end

defmodule Raxol.View.Elements do
  @moduledoc """
  Basic UI elements for Raxol views.
  
  This module defines the core UI elements that can be used
  in Raxol views.
  """
  
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
  
  ## Example
  
  ```elixir
  label content: "Hello, world!"
  ```
  """
  defmacro label(opts) do
    quote do
      %{
        type: :label,
        attrs: unquote(opts)
      }
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
end 