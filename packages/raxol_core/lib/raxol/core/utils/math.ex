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
end
