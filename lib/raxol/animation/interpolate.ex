defmodule Raxol.Animation.Interpolate do
  @moduledoc """
  Provides interpolation functions for different data types.
  """

  @doc """
  Interpolates between two values based on progress `t` (0.0 to 1.0).
  """
  def value(from, to, t) when is_number(from) and is_number(to) do
    from + (to - from) * t
  end

  # TODO: Implement interpolation for other types:
  # - Colors (RGB, HSL)
  # - Tuples (e.g., {x, y} coordinates)
  # - Lists/Maps?

  # Ensure final value is returned when t >= 1.0
  def value(_from, to, t) when is_float(t) and t >= 1.0 do
    to
  end

  # Default fallback for unknown types or t < 1.0
  def value(from, _to, _t) do
    from
  end
end
