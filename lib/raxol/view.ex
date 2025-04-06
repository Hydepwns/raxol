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
