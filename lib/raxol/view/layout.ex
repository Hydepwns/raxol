defmodule Raxol.View.Layout do
  @moduledoc """
  Provides layout functions for Raxol views.

  This module contains functions for creating layout components
  that can be used in Raxol views.
  """

  # Require the main View module to use its macros (like box)
  require Raxol.View

  alias Raxol.View

  @type opts :: keyword()
  @type children_fun :: fun()

  @doc """
  Creates a row layout component.

  ## Options

  * `:style` - Style map for the row
  * `:gap` - Gap between items
  * `:align` - Alignment of items (:start, :center, :end)
  * `:justify` - Justification of items (:start, :center, :end, :space_between)

  ## Example

  ```elixir
  row(style: %{gap: 1, align: :center}) do
    text("Left")
    text("Right")
  end
  ```
  """
  @spec row(opts()) :: %{
          :children => list(),
          :opts => Keyword.t(),
          :type => :row
        }
  def row(opts) when is_list(opts) do
    View.row(opts)
  end

  @spec row(opts(), [{:do, children_fun()}]) :: map()
  @dialyzer {:nowarn_function, row: 2}
  def row(opts \\ [], do: block) when is_list(opts) and is_function(block, 0) do
    View.row(opts, block)
  end

  @doc """
  Creates a column layout component.

  ## Options

  * `:style` - Style map for the column
  * `:gap` - Gap between items
  * `:align` - Alignment of items (:start, :center, :end)
  * `:justify` - Justification of items (:start, :center, :end, :space_between)

  ## Example

  ```elixir
  column(style: %{gap: 1, align: :center}) do
    text("Top")
    text("Bottom")
  end
  ```
  """
  @spec column(opts()) :: %{
          :children => list(),
          :opts => Keyword.t(),
          :type => :column
        }
  def column(opts) when is_list(opts) do
    View.column(opts)
  end

  @spec column(opts(), [{:do, children_fun()}]) :: map()
  @dialyzer {:nowarn_function, column: 2}
  def column(opts \\ [], do: block)
      when is_list(opts) and is_function(block, 0) do
    View.column(opts, block)
  end

  @doc """
  Creates a box component for layout.

  ## Options

  * `:style` - Style map for the box
  * `:border` - Border style (:none, :single, :double, :rounded, :bold, :dashed)
  * `:padding` - Padding around the content
  * `:margin` - Margin around the box

  ## Example

  ```elixir
  box(style: %{border: :single, padding: 1}) do
    text("Content goes here")
  end
  ```
  """
  def box(opts \\ [], do: block) do
    %{
      type: :box,
      attrs: opts,
      children: block
    }
  end

  @doc """
  Creates a grid layout component.

  ## Options

  * `:style` - Style map for the grid
  * `:columns` - Number of columns
  * `:rows` - Number of rows
  * `:gap` - Gap between grid items

  ## Example

  ```elixir
  grid(style: %{columns: 2, gap: 1}) do
    text("Item 1")
    text("Item 2")
    text("Item 3")
    text("Item 4")
  end
  ```
  """
  def grid(opts \\ [], do: block) do
    %{
      type: :grid,
      attrs: opts,
      children: block
    }
  end

  @doc """
  Creates a stack layout component.

  ## Options

  * `:style` - Style map for the stack
  * `:spacing` - Space between items
  * `:align` - Alignment of items (:start, :center, :end)

  ## Example

  ```elixir
  stack(style: %{spacing: 1, align: :center}) do
    text("Item 1")
    text("Item 2")
    text("Item 3")
  end
  ```
  """
  def stack(opts \\ [], do: block) do
    %{
      type: :stack,
      attrs: opts,
      children: block
    }
  end

  @doc """
  Creates a flex layout component.

  ## Options

  * `:style` - Style map for the flex container
  * `:direction` - Direction of flex items (:row, :column)
  * `:wrap` - Whether to wrap items (:nowrap, :wrap)
  * `:justify` - Justification of items (:start, :center, :end, :space_between, :space_around)
  * `:align` - Alignment of items (:start, :center, :end, :stretch)
  * `:gap` - Gap between items

  ## Example

  ```elixir
  flex(style: %{direction: :row, wrap: :wrap, gap: 1}) do
    text("Item 1")
    text("Item 2")
    text("Item 3")
  end
  ```
  """
  def flex(opts \\ [], do: block) do
    %{
      type: :flex,
      attrs: opts,
      children: block
    }
  end
end
