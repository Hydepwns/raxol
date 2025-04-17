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

  @type opts :: keyword()
  @type children_fun :: fun()

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
  Creates a panel component, handling options and an optional do block.
  """
  defmacro panel(opts \\ [], do: block) do
    quote do
      panel_opts = unquote(opts)
      # Directly process the block result, handling lists/nils/elements
      panel_children =
        List.wrap(unquote(block)) |> List.flatten() |> Enum.reject(&is_nil(&1))

      %{type: :panel, opts: panel_opts, children: panel_children}
    end
  end

  @doc """
  Creates a column component with child elements.
  """
  @spec column(opts(), children_fun()) :: map()
  def column(opts, fun) when is_list(opts) and is_function(fun, 0) do
    %{type: :column, opts: opts, children: fun.()}
  end

  @doc """
  Creates a column component, returning a map describing it.
  """
  @spec column(opts()) :: map()
  def column(opts) when is_list(opts) do
    %{type: :column, opts: opts, children: []}
  end

  @doc """
  Creates a row component with child elements.
  """
  @spec row(opts(), children_fun()) :: map()
  def row(opts, fun) when is_list(opts) and is_function(fun, 0) do
    %{type: :row, opts: opts, children: fun.()}
  end

  @doc """
  Creates a row component, returning a map describing it.
  """
  @spec row(opts()) :: map()
  def row(opts) when is_list(opts) do
    %{type: :row, opts: opts, children: []}
  end

  @doc """
  Creates a text component.
  """
  # Simplified return type
  @spec text(binary(), opts()) :: any()
  def text(content, _opts \\ []) when is_binary(content) do
    %{type: :text, text: content, attrs: %{}}
  end

  @doc """
  Creates a button component.
  """
  # Keep opts for future styling/behaviour
  def button(opts \\ [], label) when is_list(opts) and is_binary(label) do
    %{type: :button, label: label, opts: opts}
  end

  @doc """
  Creates a toast notification representation.
  """
  # Keep opts for future styling/duration
  def toast(message, opts \\ []) when is_binary(message) do
    %{type: :toast, message: message, opts: opts}
  end

  @doc """
  Creates a box layout element.
  Accepts children via a do block.
  """
  defmacro box(opts \\ [], do: block) do
    quote do
      box_opts = unquote(opts)
      # Directly process the block result, handling lists/nils/elements
      box_children =
        List.wrap(unquote(block)) |> List.flatten() |> Enum.reject(&is_nil(&1))

      %{type: :box, opts: box_opts, children: box_children}
    end
  end

  @doc """
  Represents a placeholder element that plugins can replace.

  This is not directly rendered but acts as a marker for plugins
  to insert dynamic content (like images).

  ## Attributes

  - `type` - An atom identifying the type of placeholder (e.g., `:image`).
  """
  def placeholder(type, _opts \\ []) when is_atom(type) do
    # Placeholders don't have children or standard attributes like text/panel
    %{type: :placeholder, placeholder_type: type}
  end

  @doc """
  Recursively converts a Raxol.View DSL map representation into a
  Raxol.Core.Renderer.Element struct tree.
  Handles maps, elements, strings, lists, and nil.
  """
  def to_element(dsl_map) when is_map(dsl_map) and not is_struct(dsl_map) do
    tag = Map.get(dsl_map, :type)
    # Map attributes/opts based on DSL type conventions
    attributes = Map.get(dsl_map, :opts, Map.get(dsl_map, :attrs, []))
    # Map content based on DSL type conventions
    content = Map.get(dsl_map, :text, Map.get(dsl_map, :label, nil))

    children_dsl = Map.get(dsl_map, :children, [])
    # Recursively convert children, filtering out nils
    children_elements =
      children_dsl
      # Recursive call
      |> Enum.map(&to_element/1)
      # Remove any nils returned
      |> Enum.reject(&is_nil(&1))

    %Raxol.Core.Renderer.Element{
      tag: tag,
      attributes: attributes,
      content: content,
      # Assign cleaned list
      children: children_elements,
      # Ensure each element gets a unique ref
      ref: make_ref(),
      # Style needs to be extracted/handled appropriately if needed here
      # Basic style passing
      style: Map.get(dsl_map, :style, %{})
    }
  end

  # Handle cases where the input is already an Element
  def to_element(%Raxol.Core.Renderer.Element{} = element), do: element
  # Handle raw strings by converting them to text elements
  def to_element(text) when is_binary(text),
    do: to_element(%{type: :text, text: text})

  # Handle nil explicitly
  def to_element(nil), do: nil
  # Handle lists by converting each item and wrapping in a fragment
  def to_element(list) when is_list(list) do
    list
    |> Enum.map(&to_element/1)
    |> Enum.reject(&is_nil(&1))
    |> case do
      # Return nil if list becomes empty after conversion
      [] -> nil
      # Wrap list in fragment
      elements -> to_element(%{type: :fragment, children: elements})
    end
  end

  # Catch-all for unexpected types - return nil
  def to_element(_other), do: nil
end
