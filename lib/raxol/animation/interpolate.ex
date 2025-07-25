defmodule Raxol.Animation.Interpolate do
  import Raxol.Guards

  @moduledoc """
  Provides interpolation functions for different data types.
  """

  alias Raxol.Style.Colors.Color
  alias Raxol.Style.Colors.HSL

  @doc """
  Interpolates between two values based on progress `t` (0.0 to 1.0).
  """
  def value(from, to, t) when number?(from) and number?(to) do
    from + (to - from) * t
  end

  # Handle tuples of size 2 and 3 with a simpler implementation
  def value(from_tuple, to_tuple, t)
      when tuple?(from_tuple) and tuple?(to_tuple) do
    if tuple_size(from_tuple) == tuple_size(to_tuple) and
         numeric_tuple?(from_tuple) and numeric_tuple?(to_tuple) do
      values =
        for i <- 0..(tuple_size(from_tuple) - 1) do
          from_val = elem(from_tuple, i)
          to_val = elem(to_tuple, i)
          value(from_val, to_val, t)
        end

      List.to_tuple(values)
    else
      from_tuple
    end
  end

  def value(from_list, to_list, t)
      when list?(from_list) and list?(to_list) and
             length(from_list) == length(to_list) do
    if valid_number_lists?(from_list, to_list) do
      Enum.zip(from_list, to_list)
      |> Enum.map(fn {f, v} -> value(f, v, t) end)
    else
      from_list
    end
  end

  def value(%Color{} = from_color, %Color{} = to_color, t) do
    {h1, s1, l1} = HSL.rgb_to_hsl(from_color.r, from_color.g, from_color.b)
    {h2, s2, l2} = HSL.rgb_to_hsl(to_color.r, to_color.g, to_color.b)

    {h, s, l} = interpolate_hsl({h1, s1, l1}, {h2, s2, l2}, t)
    {r, g, b} = HSL.hsl_to_rgb(h, s, l)
    Color.from_rgb(r, g, b)
  end

  def value(from_map, to_map, t) when map?(from_map) and map?(to_map) do
    Map.new(from_map, fn {key, from_value} ->
      case Map.fetch(to_map, key) do
        {:ok, to_value} ->
          {key, value(from_value, to_value, t)}

        :error ->
          {key, from_value}
      end
    end)
  end

  # Ensure final value is returned when t >= 1.0
  def value(_from, to, t) when float?(t) and t >= 1.0 do
    to
  end

  # Default fallback for unknown types or t < 1.0
  def value(from, _to, _t) do
    from
  end

  defp valid_number_lists?(from_list, to_list) do
    Enum.all?(from_list, &number?/1) and Enum.all?(to_list, &number?/1)
  end

  # Helper function to check if all elements in a tuple are numbers
  defp numeric_tuple?(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.all?(&number?/1)
  end

  defp interpolate_hsl({h1, s1, l1}, {h2, s2, l2}, t) do
    h = interpolate_hue(h1, h2, t)
    s = value(s1, s2, t) |> max(+0.0) |> min(1.0)
    l = value(l1, l2, t) |> max(+0.0) |> min(1.0)
    {h, s, l}
  end

  defp interpolate_hue(h1, h2, t) do
    diff = h2 - h1

    h_interpolated_raw =
      cond do
        abs(diff) <= 180 -> h1 + diff * t
        diff > 180 -> h1 + (diff - 360) * t
        true -> h1 + (diff + 360) * t
      end

    mod_val = h_interpolated_raw - Float.floor(h_interpolated_raw / 360) * 360
    h_positive = if mod_val < 0, do: mod_val + 360, else: mod_val
    round(h_positive) |> then(&if(&1 == 360, do: 0, else: &1))
  end
end
