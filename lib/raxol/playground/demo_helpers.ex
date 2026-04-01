defmodule Raxol.Playground.DemoHelpers do
  @moduledoc """
  Shared helpers for playground demo TEA apps.

  Small utilities that eliminate the most common duplication
  across demos while keeping demos self-contained and readable.
  """

  @doc """
  Moves a cursor index down (increment), clamped to `max_index`.
  """
  @spec cursor_down(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def cursor_down(current, max_index), do: min(current + 1, max_index)

  @doc """
  Moves a cursor index up (decrement), clamped to 0.
  """
  @spec cursor_up(non_neg_integer()) :: non_neg_integer()
  def cursor_up(current), do: max(current - 1, 0)

  @doc """
  Returns `"> "` if `index` matches `selected`, else `"  "`.
  """
  @spec cursor_prefix(non_neg_integer(), non_neg_integer()) :: String.t()
  def cursor_prefix(index, selected) when index == selected, do: "> "
  def cursor_prefix(_index, _selected), do: "  "

  @doc """
  Cycles an index forward through a list length, wrapping around.
  """
  @spec cycle_next(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def cycle_next(current, count), do: rem(current + 1, count)
end
