defmodule Raxol.Style.Colors.PaletteManager do
  @moduledoc """
  Manages color palette generation and scale creation with accessibility considerations.
  """

  alias Raxol.Style.Colors.HSL

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
      when is_binary(base_color) and steps > 0 do
    # Convert hex to HSL for easier manipulation
    {h, s, l} = hex_to_hsl(base_color)

    # Generate scale by varying lightness while maintaining hue and saturation
    # Start with lighter colors and progress to darker ones
    light_step = l / (steps - 1)

    Enum.map(0..(steps - 1), fn i ->
      new_l = Raxol.Core.Utils.Math.clamp(l - i * light_step, 0.1, 0.9)
      hsl_to_hex(h, s, new_l)
    end)
    |> ensure_accessible_contrast()
  end

  defp hex_to_hsl(hex) do
    hex = String.replace(hex, "#", "")
    r = String.slice(hex, 0..1) |> String.to_integer(16)
    g = String.slice(hex, 2..3) |> String.to_integer(16)
    b = String.slice(hex, 4..5) |> String.to_integer(16)

    {h, s, l} = HSL.rgb_to_hsl(r, g, b)
    # Return as floats (hue in degrees, s/l as 0.0-1.0)
    {h * 1.0, s * 1.0, l * 1.0}
  end

  defp hsl_to_hex(h, s, l) do
    {r, g, b} = hsl_to_rgb(h, s, l)
    rgb_to_hex(r, g, b)
  end

  defp hsl_to_rgb(h, s, l) do
    HSL.hsl_to_rgb(h * 1.0, s * 1.0, l * 1.0)
  end

  defp rgb_to_hex(r, g, b),
    do: Raxol.Utils.ColorConversion.rgb_to_hex({r, g, b})

  defp ensure_accessible_contrast(colors) do
    dark_bg = "#121212"
    min_contrast = 3.0

    Enum.map(colors, fn color ->
      ensure_color_contrast(color, dark_bg, min_contrast)
    end)
  end

  defp ensure_color_contrast(color, background, min_contrast) do
    case has_sufficient_contrast(color, background, min_contrast) do
      true -> color
      false -> adjust_for_contrast(color, background, min_contrast)
    end
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
    handle_lightness_adjustment(
      attempts >= 20,
      h,
      s,
      l,
      background,
      min_ratio,
      attempts
    )
  end

  defp handle_lightness_adjustment(
         true,
         _h,
         _s,
         _l,
         _background,
         _min_ratio,
         _attempts
       ) do
    # Fallback to a safe color if we can't achieve contrast
    0.8
  end

  defp handle_lightness_adjustment(
         false,
         h,
         s,
         l,
         background,
         min_ratio,
         attempts
       ) do
    test_color = hsl_to_hex(h, s, l)

    case has_sufficient_contrast(test_color, background, min_ratio) do
      true ->
        l

      false ->
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
