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

  def value({f1, f2} = from_tuple, {t1, t2} = to_tuple, t)
      when is_tuple(from_tuple) and tuple_size(from_tuple) == 2 and
             is_tuple(to_tuple) and tuple_size(to_tuple) == 2 and
             is_number(f1) and is_number(f2) and is_number(t1) and is_number(t2) do
    {value(f1, t1, t), value(f2, t2, t)}
  end

  def value({f1, f2, f3} = from_tuple, {t1, t2, t3} = to_tuple, t)
      when is_tuple(from_tuple) and tuple_size(from_tuple) == 3 and
             is_tuple(to_tuple) and tuple_size(to_tuple) == 3 and
             is_number(f1) and is_number(f2) and is_number(f3) and
             is_number(t1) and is_number(t2) and is_number(t3) do
    {value(f1, t1, t), value(f2, t2, t), value(f3, t3, t)}
  end

  def value(from_list, to_list, t)
      when is_list(from_list) and is_list(to_list) and
             length(from_list) == length(to_list) do
    # Check if all elements are numbers before attempting to zip and map
    # This is a bit verbose; a more functional check might be cleaner but this is explicit
    all_from_numbers = Enum.all?(from_list, &is_number/1)
    all_to_numbers = Enum.all?(to_list, &is_number/1)

    if all_from_numbers and all_to_numbers do
      Enum.zip(from_list, to_list)
      |> Enum.map(fn {f, v} -> value(f, v, t) end)
    else
      # Fallback for lists not containing all numbers or if one is empty when the other isn't (caught by length check)
      # Based on the main fallback, return 'from' if types don't match for interpolation before t=1.0
      from_list
    end
  end

  def value(from_map, to_map, t) when is_map(from_map) and is_map(to_map) do
    # Iterate over the keys of the 'from_map'. For each key,
    # if it also exists in 'to_map', interpolate their values.
    # Keys present in 'from_map' but not in 'to_map' will be carried over from 'from_map'.
    # Keys present only in 'to_map' will be ignored for interpolation but will appear in the final
    # result if t >= 1.0 because the top-level 'to_map' is returned then.
    # This approach prioritizes 'from_map' structure for t < 1.0.

    Map.new(from_map, fn {key, from_value} ->
      case Map.fetch(to_map, key) do
        {:ok, to_value} ->
          # Recursively call value/3 for interpolation
          {key, value(from_value, to_value, t)}

        :error ->
          # Key not in to_map, carry over from_value
          {key, from_value}
      end
    end)
  end

  def value(%Color{} = from_color, %Color{} = to_color, t) do
    {h1, s1, l1} = HSL.rgb_to_hsl(from_color.r, from_color.g, from_color.b)
    {h2, s2, l2} = HSL.rgb_to_hsl(to_color.r, to_color.g, to_color.b)

    # Interpolate Hue (shortest path)
    diff = h2 - h1

    h_interpolated_raw =
      cond do
        abs(diff) <= 180 ->
          h1 + diff * t

        diff > 180 ->
          # Interpolate taking the shorter path across the 0/360 boundary
          h1 + (diff - 360) * t

        # This covers diff < -180
        true ->
          # Interpolate taking the shorter path across the 0/360 boundary
          h1 + (diff + 360) * t
      end

    # Normalize hue to be within [0, 360) and rounded, as per HSL module's internal style
    h_normalized =
      h_interpolated_raw
      # Round to nearest integer first
      |> round()
      # Get remainder with 360
      |> then(&rem(&1, 360))
      # Ensure positive
      |> then(fn h_rem -> if h_rem < 0, do: h_rem + 360, else: h_rem end)
      # Ensure h_final is strictly < 360 for HSL.hsl_to_rgb which expects h < 360
      |> then(fn h_almost_final ->
        if h_almost_final == 360, do: 0, else: h_almost_final
      end)

    # Interpolate Saturation and Lightness (linear)
    # Use existing numeric interpolation
    s_interpolated = value(s1, s2, t)
    l_interpolated = value(l1, l2, t)

    # Clamp S and L to valid ranges (0.0-1.0) as HSL functions expect
    s_final = max(0.0, min(1.0, s_interpolated))
    l_final = max(0.0, min(1.0, l_interpolated))

    {r_new, g_new, b_new} = HSL.hsl_to_rgb(h_normalized, s_final, l_final)

    # Use Color.from_rgb/3 to construct the new Color struct,
    # assuming it correctly sets r, g, b and any other derived fields like :hex.
    Color.from_rgb(r_new, g_new, b_new)
  end

  # TODO: Implement interpolation for other types:
  # - Colors (RGB, HSL) - Basic interpolation via 3-tuple logic is in place.
  #   Advanced color space interpolation (e.g., HSL hue shortest path for %Color{} structs) is now implemented.
  # - Tuples (e.g., {x, y} coordinates) - Done for 2-tuples and 3-tuples.
  # - Lists/Maps? - Done for lists of numbers and maps with interpolatable values.

  # Ensure final value is returned when t >= 1.0
  def value(_from, to, t) when is_float(t) and t >= 1.0 do
    to
  end

  # Default fallback for unknown types or t < 1.0
  def value(from, _to, _t) do
    from
  end
end
