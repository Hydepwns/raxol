defmodule Raxol.Style.Colors.PaletteManager do
  import Raxol.Guards

  @moduledoc """
  Manages color palette generation and scale creation with accessibility considerations.
  """

  @doc """
  Generates a color scale from a base color with the specified number of steps.
  Ensures each color in the scale has sufficient contrast with dark backgrounds.

  ## Parameters
  * `base_color` - The base hex color (e.g., "#0077CC")
  * `steps` - Number of colors in the scale

  ## Returns
  List of hex color strings with sufficient contrast ratios
  """
  @spec generate_scale(String.t(), pos_integer()) :: [String.t()]
  def generate_scale(base_color, steps)
      when binary?(base_color) and steps > 0 do
    # Convert hex to HSL for easier manipulation
    {h, s, l} = hex_to_hsl(base_color)

    # Generate scale by varying lightness while maintaining hue and saturation
    # Start with lighter colors and progress to darker ones
    light_step = l / (steps - 1)

    Enum.map(0..(steps - 1), fn i ->
      new_l = max(0.1, min(0.9, l - i * light_step))
      hsl_to_hex(h, s, new_l)
    end)
    |> ensure_accessible_contrast()
  end

  defp hex_to_hsl(hex) do
    # Remove # if present
    hex = String.replace(hex, "#", "")

    # Parse RGB values
    {r, g, b} = parse_hex_rgb_values(hex)

    # Convert to HSL
    max_val = max(r, max(g, b))
    min_val = min(r, min(g, b))
    delta = max_val - min_val

    l = (max_val + min_val) / 2

    {h, s} = calculate_hue_and_saturation(r, g, b, max_val, min_val, delta, l)

    {h, s, l}
  end

  defp parse_hex_rgb_values(hex) do
    r = String.slice(hex, 0..1) |> String.to_integer(16) |> then(&(&1 / 255))
    g = String.slice(hex, 2..3) |> String.to_integer(16) |> then(&(&1 / 255))
    b = String.slice(hex, 4..5) |> String.to_integer(16) |> then(&(&1 / 255))
    {r, g, b}
  end

  defp calculate_hue_and_saturation(r, g, b, max_val, min_val, delta, l) do
    if delta == 0 do
      {0, 0}
    else
      s = calculate_saturation(delta, max_val, min_val, l)
      h = calculate_hue(r, g, b, max_val, delta)
      {h, s}
    end
  end

  defp calculate_saturation(delta, max_val, min_val, l) do
    if l > 0.5,
      do: delta / (2 - max_val - min_val),
      else: delta / (max_val + min_val)
  end

  defp calculate_hue(r, g, b, max_val, delta) do
    h =
      cond do
        max_val == r -> (g - b) / delta * 60
        max_val == g -> ((b - r) / delta + 2) * 60
        max_val == b -> ((r - g) / delta + 4) * 60
      end

    if h < 0, do: h + 360, else: h
  end

  defp hsl_to_hex(h, s, l) do
    {r, g, b} = hsl_to_rgb(h, s, l)
    rgb_to_hex(r, g, b)
  end

  defp hsl_to_rgb(h, s, l) do
    c = calculate_chroma(s, l)
    x = calculate_secondary_component(h, c)
    m = l - c / 2

    {r1, g1, b1} = hsl_rgb_components(h, c, x)
    r = round((r1 + m) * 255)
    g = round((g1 + m) * 255)
    b = round((b1 + m) * 255)
    {max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b))}
  end

  defp calculate_chroma(s, l) do
    (1 - abs(2 * l - 1)) * s
  end

  defp calculate_secondary_component(h, c) do
    c * (1 - abs(rem(trunc(h / 60), 2) - 1))
  end

  defp hsl_rgb_components(h, c, x) do
    cond do
      h < 60 -> {c, x, 0}
      h < 120 -> {x, c, 0}
      h < 180 -> {0, c, x}
      h < 240 -> {0, x, c}
      h < 300 -> {x, 0, c}
      true -> {c, 0, x}
    end
  end

  defp rgb_to_hex(r, g, b) do
    "#" <>
      String.pad_leading(Integer.to_string(r, 16), 2, "0") <>
      String.pad_leading(Integer.to_string(g, 16), 2, "0") <>
      String.pad_leading(Integer.to_string(b, 16), 2, "0")
  end

  defp ensure_accessible_contrast(colors) do
    dark_bg = "#121212"
    min_contrast = 3.0

    Enum.map(colors, fn color ->
      if has_sufficient_contrast(color, dark_bg, min_contrast) do
        color
      else
        # Adjust color to meet contrast requirements
        adjust_for_contrast(color, dark_bg, min_contrast)
      end
    end)
  end

  defp has_sufficient_contrast(color, background, min_ratio) do
    ratio = Raxol.Style.Colors.Utilities.contrast_ratio(color, background)
    ratio >= min_ratio
  end

  defp adjust_for_contrast(color, background, min_ratio) do
    # Simple adjustment: lighten the color until it meets contrast requirements
    {h, s, l} = hex_to_hsl(color)

    adjusted_l = adjust_lightness_for_contrast(h, s, l, background, min_ratio)
    hsl_to_hex(h, s, adjusted_l)
  end

  defp adjust_lightness_for_contrast(
         h,
         s,
         l,
         background,
         min_ratio,
         attempts \\ 0
       ) do
    if attempts >= 20 do
      # Fallback to a safe color if we can't achieve contrast
      0.8
    else
      test_color = hsl_to_hex(h, s, l)

      if has_sufficient_contrast(test_color, background, min_ratio) do
        l
      else
        # Increase lightness and try again
        new_l = min(0.95, l + 0.05)

        adjust_lightness_for_contrast(
          h,
          s,
          new_l,
          background,
          min_ratio,
          attempts + 1
        )
      end
    end
  end
end
