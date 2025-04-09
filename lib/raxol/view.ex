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
  Creates a panel component, returning a map describing it.
  """
  @spec panel(opts()) :: map()
  def panel(opts) when is_list(opts) do
    # TODO: Implement actual panel rendering based on opts
    %{type: :panel, opts: opts, children: []} # Return a map representation
  end

  @doc """
  Creates a panel component with child elements.
  """
  @spec panel(opts(), children_fun()) :: map()
  def panel(opts, fun) when is_list(opts) and is_function(fun, 0) do
    %{type: :panel, opts: opts, children: fun.()} # Return map for block usage too
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
  @spec text(binary(), opts()) :: any() # Simplified return type
  def text(content, _opts \\ []) when is_binary(content) do
    %{type: :text, text: content, attrs: %{}}
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

  def box(children \\ [], _opts \\ []) do
    # TODO: Implement actual box rendering
    children
  end
end
