defmodule Raxol.Core.Utils.Math do
  @moduledoc """
  Shared numeric utilities.
  """

  @doc """
  Clamps `value` to the range `[lo, hi]`.

  ## Examples

      iex> Raxol.Core.Utils.Math.clamp(5, 0, 10)
      5

      iex> Raxol.Core.Utils.Math.clamp(-1, 0, 10)
      0

      iex> Raxol.Core.Utils.Math.clamp(15, 0, 10)
      10
  """
  @spec clamp(number(), number(), number()) :: number()
  def clamp(value, lo, hi), do: value |> max(lo) |> min(hi)

  @doc """
  Computes the scroll offset needed to keep `index` visible in a viewport
  of `visible_count` items starting at `scroll_offset`.

  Returns the (possibly adjusted) scroll offset.

  ## Examples

      iex> Raxol.Core.Utils.Math.scroll_into_view(5, 0, 10)
      0

      iex> Raxol.Core.Utils.Math.scroll_into_view(12, 0, 10)
      3

      iex> Raxol.Core.Utils.Math.scroll_into_view(2, 5, 10)
      2
  """
  @spec scroll_into_view(integer(), integer(), pos_integer()) :: integer()
  def scroll_into_view(index, scroll_offset, visible_count) do
    cond do
      index < scroll_offset -> index
      index >= scroll_offset + visible_count -> index - visible_count + 1
      true -> scroll_offset
    end
  end
end
