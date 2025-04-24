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
    %{
      type: :row,
      opts: opts,
      children: []
    }
  end

  @spec row(opts(), children_fun() | [{:do, children_fun()}]) :: map()
  @dialyzer {:nowarn_function, row: 2}
  def row(opts \\ [], block_or_fun) do
    children =
      if is_function(block_or_fun, 0) do
        block_or_fun.()
      else
        case block_or_fun do
          [do: block] when is_function(block, 0) -> block.()
          _ -> []
        end
      end

    %{
      type: :row,
      opts: opts,
      children: List.wrap(children)
    }
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
    %{
      type: :column,
      opts: opts,
      children: []
    }
  end

  @spec column(opts(), children_fun() | [{:do, children_fun()}]) :: map()
  @dialyzer {:nowarn_function, column: 2}
  def column(opts \\ [], block_or_fun) do
    children =
      if is_function(block_or_fun, 0) do
        block_or_fun.()
      else
        case block_or_fun do
          [do: block] when is_function(block, 0) -> block.()
          _ -> []
        end
      end

    %{
      type: :column,
      opts: opts,
      children: List.wrap(children)
    }
  end

  @doc """
  Creates a box component for layout, delegating to `Raxol.View.box/2`.

  This function serves as a convenience wrapper within the Layout module.
  Refer to `Raxol.View.box/2` for detailed options and usage.

  ## Options

  Accepts the same options as `Raxol.View.box/2`.

  ## Example

  ```elixir
  box(style: %{border: true, padding: 1}) do
    text("Content inside a box")
  end
  ```
  """
  @spec box(opts(), [{:do, children_fun()}]) :: map()
  @dialyzer {:nowarn_function, box: 2}
  def box(opts \\ [], do: block) when is_list(opts) and is_function(block, 0) do
    View.box(opts, do: block)
  end
end
