defmodule Raxol.View.Layout do
  @moduledoc """
  Provides layout functions for Raxol views.
  
  This module contains functions for creating layout components
  that can be used in Raxol views.
  """

  alias Raxol.Core.Renderer.View

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
  def row(opts \\ [], do: block) do
    View.row(opts, do: block)
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
  def column(opts \\ [], do: block) do
    View.column(opts, do: block)
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
    View.box(opts, do: block)
  end

  @doc """
  Creates a panel component.
  
  ## Options
  
  * `:title` - Panel title
  * `:style` - Style map for the panel
  * `:border` - Border style
  * `:padding` - Padding around the content
  
  ## Example
  
  ```elixir
  panel(title: "My Panel", style: %{border: :single}) do
    text("Panel content")
  end
  ```
  """
  def panel(opts \\ [], do: block) do
    View.panel(opts, do: block)
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
    View.grid(opts, do: block)
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
    View.stack(opts, do: block)
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
    View.flex(opts, do: block)
  end
end 