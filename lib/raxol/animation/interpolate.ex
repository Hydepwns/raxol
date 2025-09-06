defmodule Raxol.Animation.Interpolate do
  @moduledoc """
  Provides interpolation functions for different data types.
  """

  alias Raxol.Style.Colors.Color
  alias Raxol.Style.Colors.HSL

  @doc """
  Interpolates between two values based on progress `t` (0.0 to 1.0).
  """
  def value(from, to, t) when is_number(from) and is_number(to) do
    from + (to - from) * t
  end

  # Handle tuples of size 2 and 3 with a simpler implementation
  def value(from_tuple, to_tuple, t)
      when is_tuple(from_tuple) and is_tuple(to_tuple) do
    case {tuple_size(from_tuple) == tuple_size(to_tuple), 
          numeric_is_tuple(from_tuple), numeric_is_tuple(to_tuple)} do
      {true, true, true} ->
        values =
          for i <- 0..(tuple_size(from_tuple) - 1) do
            from_val = elem(from_tuple, i)
            to_val = elem(to_tuple, i)
            value(from_val, to_val, t)
          end

        List.to_tuple(values)
      _ ->
        from_tuple
    end
  end

  def value(from_list, to_list, t)
      when is_list(from_list) and is_list(to_list) and
             length(from_list) == length(to_list) do
    case valid_number_lists?(from_list, to_list) do
      true ->
        Enum.zip(from_list, to_list)
        |> Enum.map(fn {f, v} -> value(f, v, t) end)
      false ->
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

  def value(from_map, to_map, t) when is_map(from_map) and is_map(to_map) do
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
  def value(_from, to, t) when is_float(t) and t >= 1.0 do
    to
  end

  # Default fallback for unknown types or t < 1.0
  def value(from, _to, _t) do
    from
  end

  defp valid_number_lists?(from_list, to_list) do
    Enum.all?(from_list, &is_number/1) and Enum.all?(to_list, &is_number/1)
  end

  # Helper function to check if all elements in a tuple are numbers
  defp numeric_is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.all?(&is_number/1)
  end

  defp interpolate_hsl({h1, s1, l1}, {h2, s2, l2}, t) do
    h = interpolate_hue(h1, h2, t)
    s = value(s1, s2, t) |> max(+0.0) |> min(1.0)
    l = value(l1, l2, t) |> max(+0.0) |> min(1.0)
    {h, s, l}
  end

  defp interpolate_hue(h1, h2, t) do
    diff = h2 - h1
    h_interpolated_raw = calculate_hue_interpolation(h1, diff, t)

    mod_val = h_interpolated_raw - Float.floor(h_interpolated_raw / 360) * 360
    h_positive = case mod_val < 0 do
      true -> mod_val + 360
      false -> mod_val
    end
    case round(h_positive) do
      360 -> 0
      other -> other
    end
  end

  defp calculate_hue_interpolation(h1, diff, t) when abs(diff) <= 180,
    do: h1 + diff * t

  defp calculate_hue_interpolation(h1, diff, t) when diff > 180,
    do: h1 + (diff - 360) * t

  defp calculate_hue_interpolation(h1, diff, t), do: h1 + (diff + 360) * t
end
