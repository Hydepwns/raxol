defmodule Raxol.View.Elements do
  @moduledoc """
  Compatibility adapter for view elements.
  Provides the expected interface for UI components.
  """

  # Import the actual view functions
  alias Raxol.Core.Renderer.View

  # Require for macro usage
  require Raxol.Core.Renderer.View

  @doc """
  Creates a row layout with a block.
  """
  defmacro row(opts, do: block) do
    quote do
      Raxol.Core.Renderer.View.row(unquote(opts), do: unquote(block))
    end
  end

  @doc """
  Creates a row layout without a block.
  """
  def row(opts \\ []) do
    View.row(opts)
  end

  @doc """
  Creates a label (text) element.
  """
  def label(opts \\ []) do
    Raxol.View.Components.label(opts)
  end

  @doc """
  Creates a box element with a block.
  """
  defmacro box(opts, do: block) do
    quote do
      Raxol.Core.Renderer.View.box(unquote(opts), do: unquote(block))
    end
  end

  @doc """
  Creates a box element without a block.
  """
  def box(opts \\ []) do
    View.box(opts)
  end

  @doc """
  Creates a column layout.
  """
  defmacro column(opts, do: block) do
    quote do
      children = unquote(block)

      Raxol.Core.Renderer.View.column(
        Keyword.merge(unquote(opts), children: children)
      )
    end
  end

  @doc """
  Creates a text element.
  """
  def text(content, opts \\ []) do
    View.text(content, opts)
  end

  @doc """
  Creates a button element.
  """
  def button(text, opts \\ []) do
    View.button(text, opts)
  end

  @doc """
  Creates a checkbox element.
  """
  def checkbox(label, opts \\ []) do
    View.checkbox(label, opts)
  end

  @doc """
  Creates a text input element.
  """
  def text_input(opts \\ []) do
    View.text_input(opts)
  end

  @doc """
  Creates a table element.
  """
  def table(opts \\ []) do
    View.table(opts)
  end

  # Forward other common view functions
  defdelegate panel(opts), to: View
  defdelegate border(view, opts), to: View
  defdelegate scroll(view, opts), to: View
  defdelegate flex(constraints), to: View
  defdelegate shadow(opts), to: View
end
