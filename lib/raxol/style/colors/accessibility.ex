defmodule Raxol.Style.Colors.Accessibility do
  import Raxol.Guards

  @moduledoc """
  Provides utilities for color accessibility, focusing on WCAG contrast.
  """

  alias Raxol.Style.Colors.Utilities
  alias Raxol.Style.Colors.Color
  require Raxol.Core.Runtime.Log

  # WCAG contrast ratio thresholds
  # AA level for normal text
  @contrast_aa 4.5
  # AAA level for normal text
  @contrast_aaa 7.0
  # AA level for large text
  @contrast_aa_large 3.0
  # AAA level for large text
  @contrast_aaa_large 4.5

  @doc """
  Calculates the relative luminance of a color according to WCAG guidelines.

  ## Parameters

  - `color` - The color to calculate luminance for (hex string or Color struct)

  ## Returns

  - A float between 0 and 1 representing the relative luminance

  ## Examples

      iex> Raxol.Style.Colors.Accessibility.relative_luminance("#000000")
      0.0

      iex> Raxol.Style.Colors.Accessibility.relative_luminance("#FFFFFF")
      1.0
  """
  def relative_luminance(color) when binary?(color) do
    # Allow hex string input for convenience
    case Color.from_hex(color) do
      %Color{} = c -> relative_luminance(c)
      # Or handle error? Defaulting to black for invalid hex.
      _ -> +0.0
    end
  end

  def relative_luminance(%Color{r: r, g: g, b: b}) do
    # Convert RGB values to relative luminance
    r_lin = _channel_to_linear(r)
    g_lin = _channel_to_linear(g)
    b_lin = _channel_to_linear(b)

    0.2126 * r_lin + 0.7152 * g_lin + 0.0722 * b_lin
  end

  # WCAG formula for converting sRGB channel to linear value
  defp _channel_to_linear(channel_val)
       when channel_val >= 0 and channel_val <= 255 do
    v = channel_val / 255
    if v <= 0.03928, do: v / 12.92, else: :math.pow((v + 0.055) / 1.055, 2.4)
  end

  @doc """
  Calculates the contrast ratio between two colors according to WCAG guidelines.

  ## Parameters

  - `color1` - The first color (hex string or Color struct)
  - `color2` - The second color (hex string or Color struct)

  ## Returns

  - A float representing the contrast ratio (1:1 to 21:1)

  ## Examples

      iex> Raxol.Style.Colors.Accessibility.contrast_ratio("#000000", "#FFFFFF")
      21.0

      iex> Raxol.Style.Colors.Accessibility.contrast_ratio("#777777", "#999999")
      1.3
  """
  def contrast_ratio(color1, color2)
      when binary?(color1) or binary?(color2) do
    # Allow hex string input
    c1 = if binary?(color1), do: Color.from_hex(color1), else: color1
    c2 = if binary?(color2), do: Color.from_hex(color2), else: color2
    contrast_ratio(c1, c2)
  end

  def contrast_ratio(%Color{} = color1, %Color{} = color2) do
    l1 = relative_luminance(color1)
    l2 = relative_luminance(color2)
    # WCAG contrast ratio formula
    (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
  end

  def contrast_ratio({r1, g1, b1}, {r2, g2, b2}) do
    c1 = %Color{r: r1, g: g1, b: b1}
    c2 = %Color{r: r2, g: g2, b: b2}
    contrast_ratio(c1, c2)
  end

  @doc """
  Checks if a foreground color is readable on a background color.

  ## Parameters

  - `background` - Background color
  - `foreground` - Text color
  - `level` - Accessibility level (`:aa`, `:aaa`, `:aa_large`, `:aaa_large`)

  ## Examples

      iex> bg = Raxol.Style.Colors.Color.from_hex("#333333")
      iex> fg = Raxol.Style.Colors.Color.from_hex("#FFFFFF")
      iex> Raxol.Style.Colors.Accessibility.readable?(bg, fg)
      true

      iex> bg = Raxol.Style.Colors.Color.from_hex("#CCCCCC")
      iex> fg = Raxol.Style.Colors.Color.from_hex("#999999")
      iex> Raxol.Style.Colors.Accessibility.readable?(bg, fg, :aaa)
      false
  """
  @spec readable?(
          Color.t() | String.t(),
          Color.t() | String.t(),
          :aa | :aaa | :aa_large | :aaa_large
        ) ::
          boolean()
  def readable?(background, foreground, level \\ :aa) do
    ratio = contrast_ratio(background, foreground)

    threshold =
      case level do
        :aa -> @contrast_aa
        :aaa -> @contrast_aaa
        :aa_large -> @contrast_aa_large
        :aaa_large -> @contrast_aaa_large
      end

    ratio >= threshold
  end

  @doc """
  Suggests an appropriate text color (black or white) for a given background.

  Ensures minimum AA contrast.

  ## Parameters

  - `background` - The background color (hex string or Color struct)

  ## Examples

      iex> Raxol.Style.Colors.Accessibility.suggest_text_color("#333333").hex
      "#FFFFFF"

      iex> Raxol.Style.Colors.Accessibility.suggest_text_color("#EEEEEE").hex
      "#000000"
  """
  def suggest_text_color(background) do
    bg =
      if binary?(background), do: Color.from_hex(background), else: background

    Utilities.best_bw_contrast(bg)
  end

  @doc """
  Suggests a color with good contrast (at least AA) to the base color.

  Prioritizes complementary color, then black/white.

  ## Parameters

  - `color` - The base color (hex string or Color struct)

  ## Examples

      iex> color = Raxol.Style.Colors.Color.from_hex("#3366CC")
      iex> contrast_color = Raxol.Style.Colors.Accessibility.suggest_contrast_color(color)
      iex> Raxol.Style.Colors.Accessibility.readable?(color, contrast_color)
      true
  """
  def suggest_contrast_color(color) when binary?(color) do
    case Color.from_hex(color) do
      %Color{} = c -> suggest_contrast_color(c)
      # Default to black for invalid base
      _ -> Color.from_hex("#000000")
    end
  end

  def suggest_contrast_color(%Color{} = color) do
    # Start with the complementary color
    # Need access to complement, which might move to HSL or stay in Color
    # Assuming Color.complement exists for now
    complement = Color.complement(color)

    # Check if it has enough contrast
    if readable?(color, complement, :aa) do
      complement
    else
      # If not, try black or white (whichever has better contrast)
      # This chooses black/white based on contrast
      suggest_text_color(color)
    end
  end

  @doc """
  Finds an accessible color pair (foreground/background) based on a base color and WCAG level.

  Tries to find a contrasting color (black or white first) that meets the desired level.

  Parameters:
    - `base_color`: The Color struct or hex string to find a contrasting pair for.
    - `level`: The minimum WCAG contrast ratio level (:aa or :aaa, defaults to :aa).

  Returns:
    A tuple `{foreground_color, background_color}` where one is the `base_color`
    and the other is a contrasting color (typically black or white) that meets the
    specified `level`. Returns `nil` if no suitable pair is found immediately
    (further logic might be needed for complex cases).
  """
  def accessible_color_pair(base_color, level \\ :aa)

  # @doc false # Silence @doc warning for the first clause
  # Clause for binary (string) input
  def accessible_color_pair(base_color, level) when binary?(base_color) do
    case Color.from_hex(base_color) do
      # Delegate to Color struct clause
      %Color{} = c ->
        accessible_color_pair(c, level)

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Accessibility: Could not find accessible color pair for #{inspect(base_color)}",
          %{}
        )

        # Return nil for invalid base color
        nil
    end
  end

  # Clause for Color struct input
  def accessible_color_pair(%Color{} = base_color, level) do
    white = Color.from_hex("#FFFFFF")
    black = Color.from_hex("#000000")

    contrast_with_white = contrast_ratio(base_color, white)
    contrast_with_black = contrast_ratio(base_color, black)
    # Call the new helper function
    min_ratio = min_contrast(level)

    if contrast_with_white >= min_ratio do
      # White text on base_color background
      {white, base_color}
    else
      if contrast_with_black >= min_ratio do
        # Black text on base_color background
        {black, base_color}
      else
        Raxol.Core.Runtime.Log.debug(
          "Could not find accessible pair for color: #{inspect(base_color)}"
        )

        # Could not find a simple black/white contrast pair
        nil
      end
    end
  end

  # Define the missing helper function
  defp min_contrast(:aaa), do: 7.0
  defp min_contrast(_level), do: 4.5

  # --- High Contrast Mode Helpers ---

  defp adjust_until_contrast(
         color,
         background,
         target_ratio,
         adjust_fun,
         direction,
         max_steps \\ 30,
         step \\ 0.7
       ) do
    do_adjust_until_contrast(
      color,
      background,
      target_ratio,
      adjust_fun,
      direction,
      max_steps,
      step
    )
  end

  defp do_adjust_until_contrast(
         color,
         _background,
         _target_ratio,
         _adjust_fun,
         _direction,
         0,
         _step
       ),
       do: color

  defp do_adjust_until_contrast(
         color,
         background,
         target_ratio,
         adjust_fun,
         direction,
         steps,
         step
       ) do
    adjusted = adjust_fun.(color, step)
    orig_lum = relative_luminance(color)
    adj_lum = relative_luminance(adjusted)

    if contrast_ratio(adjusted, background) >= target_ratio and
         ((direction == :lighter and adj_lum > orig_lum) or
            (direction == :darker and adj_lum < orig_lum)) do
      adjusted
    else
      do_adjust_until_contrast(
        adjusted,
        background,
        target_ratio,
        adjust_fun,
        direction,
        steps - 1,
        min(step * 1.5, 1.0)
      )
    end
  end

  @spec lighten_until_contrast(Color.t(), Color.t(), number()) ::
          Color.t() | nil
  def lighten_until_contrast(color, background, target_ratio) do
    adjust_until_contrast(
      color,
      background,
      target_ratio,
      &Raxol.Style.Colors.HSL.lighten/2,
      :lighter
    )
  end

  @spec darken_until_contrast(Color.t(), Color.t(), number()) :: Color.t() | nil
  def darken_until_contrast(color, background, target_ratio) do
    adjust_until_contrast(
      color,
      background,
      target_ratio,
      &Raxol.Style.Colors.HSL.darken/2,
      :darker
    )
  end

  defp luminance_changed?(orig, adjusted, :lighter),
    do: relative_luminance(adjusted) > relative_luminance(orig)

  defp luminance_changed?(orig, adjusted, :darker),
    do: relative_luminance(adjusted) < relative_luminance(orig)

  # --- Stubs for missing functions (to resolve UndefinedFunctionError) ---

  @spec suggest_accessible_color(
          Color.t() | String.t(),
          Color.t() | String.t() | Keyword.t()
        ) :: String.t()
  def suggest_accessible_color(color, background) when binary?(background) do
    suggest_accessible_color(color, background: background)
  end

  def suggest_accessible_color(color, opts) when list?(opts) do
    color = normalize_color(color)
    {bg, min_ratio} = extract_options(opts)

    case check_contrast(color, bg, Keyword.get(opts, :level, :aa)) do
      {:ok, _} -> color.hex
      _ -> find_accessible_color(color, bg, min_ratio)
    end
  end

  defp normalize_color(color) do
    if binary?(color), do: Color.from_hex(color), else: color
  end

  defp extract_options(opts) do
    bg = normalize_color(Keyword.get(opts, :background) || "#FFFFFF")

    min_ratio =
      case Keyword.get(opts, :level, :aa) do
        :aaa -> @contrast_aaa
        :aa -> @contrast_aa
      end

    {bg, min_ratio}
  end

  defp find_accessible_color(color, bg, min_ratio) do
    bg_lum = relative_luminance(bg)

    if bg_lum < 0.5 do
      try_lighten_then_darken(color, bg, min_ratio)
    else
      try_darken_then_lighten(color, bg, min_ratio)
    end
  end

  defp try_lighten_then_darken(color, bg, min_ratio) do
    lightened = lighten_until_contrast(color, bg, min_ratio)

    if valid_adjustment?(lightened, color, bg, min_ratio, :lighter) do
      lightened.hex
    else
      darkened = darken_until_contrast(color, bg, min_ratio)

      if valid_adjustment?(darkened, color, bg, min_ratio, :darker) do
        darkened.hex
      else
        "#FFFFFF"
      end
    end
  end

  defp try_darken_then_lighten(color, bg, min_ratio) do
    darkened = darken_until_contrast(color, bg, min_ratio)

    if valid_adjustment?(darkened, color, bg, min_ratio, :darker) do
      darkened.hex
    else
      lightened = lighten_until_contrast(color, bg, min_ratio)

      if valid_adjustment?(lightened, color, bg, min_ratio, :lighter) do
        lightened.hex
      else
        "#000000"
      end
    end
  end

  defp valid_adjustment?(adjusted, original, bg, min_ratio, direction) do
    adjusted &&
      contrast_ratio(adjusted, bg) >= min_ratio &&
      luminance_changed?(original, adjusted, direction) &&
      adjusted.hex != original.hex
  end

  @spec generate_accessible_palette(
          Color.t() | String.t(),
          Color.t() | String.t() | Keyword.t()
        ) :: map()
  def generate_accessible_palette(base_color, opts) when list?(opts) do
    # Extract options
    background = Keyword.get(opts, :background)
    level = Keyword.get(opts, :level, :aa)

    # Convert colors
    base =
      if binary?(base_color), do: Color.from_hex(base_color), else: base_color

    bg =
      if binary?(background),
        do: Color.from_hex(background),
        else: background || Color.from_hex("#FFFFFF")

    # Generate accessible colors
    text =
      suggest_accessible_color(Color.from_hex("#000000"),
        background: bg.hex,
        level: level
      )

    secondary =
      suggest_accessible_color(base.hex, background: bg.hex, level: level)

    # Create a contrasting accent color by rotating hue and ensuring contrast
    rotated = Raxol.Style.Colors.HSL.rotate_hue(base, 180)

    accent =
      suggest_accessible_color(rotated.hex, background: bg.hex, level: level)

    # Generate semantic colors
    link = suggest_accessible_color("#0066CC", background: bg.hex, level: level)

    success =
      suggest_accessible_color("#28A745", background: bg.hex, level: level)

    warning =
      suggest_accessible_color("#FFC107", background: bg.hex, level: level)

    error =
      suggest_accessible_color("#DC3545", background: bg.hex, level: level)

    info = suggest_accessible_color("#17A2B8", background: bg.hex, level: level)

    # Validate and adjust if needed
    colors = %{
      primary: base.hex,
      secondary: secondary,
      accent: accent,
      background: bg.hex,
      text: text,
      link: link,
      success: success,
      warning: warning,
      error: error,
      info: info
    }

    case validate_colors(colors, background: bg.hex, level: level) do
      {:ok, _} -> colors
      {:error, _} -> adjust_palette(colors, bg.hex)
    end
  end

  def generate_accessible_palette(base_color, background)
      when binary?(background) do
    generate_accessible_palette(base_color, background: background)
  end

  @spec validate_colors(map(), Color.t() | String.t() | Keyword.t()) ::
          {:ok, map()} | {:error, Keyword.t()}
  def validate_colors(colors, opts) when list?(opts) do
    bg = extract_background(opts)
    colors_map = normalize_colors_map(colors)

    issues =
      find_contrast_issues(colors_map, bg, Keyword.get(opts, :level, :aa))

    if Enum.empty?(issues), do: {:ok, colors}, else: {:error, issues}
  end

  def validate_colors(colors, background) when binary?(background) do
    validate_colors(colors, background: background)
  end

  @spec get_optimal_text_color(Color.t() | String.t()) :: String.t()
  def get_optimal_text_color(background) do
    # Convert background to Color struct if it's a hex string
    bg =
      if binary?(background), do: Color.from_hex(background), else: background

    black = Color.from_hex("#000000")
    white = Color.from_hex("#FFFFFF")

    ratio_with_white = contrast_ratio(bg, white)
    ratio_with_black = contrast_ratio(bg, black)

    if ratio_with_white >= ratio_with_black do
      "#FFFFFF"
    else
      "#000000"
    end
  end

  @doc """
  Checks if two colors have sufficient contrast according to WCAG guidelines.

  ## Parameters

  - `color1` - First color
  - `color2` - Second color
  - `level` - WCAG level (:aa or :aaa)
  - `size` - Text size (:normal or :large)

  ## Returns

  - `{:ok, ratio}` if contrast is sufficient
  - `{:error, {:contrast_too_low, ratio, min_ratio}}` if contrast is insufficient
  """
  def check_contrast(color1, color2, level \\ :aa, size \\ :normal) do
    ratio = contrast_ratio(color1, color2)

    min_ratio =
      case {level, size} do
        {:aaa, :normal} -> @contrast_aaa
        {:aaa, :large} -> @contrast_aaa_large
        {:aa, :normal} -> @contrast_aa
        {:aa, :large} -> @contrast_aa_large
      end

    if ratio >= min_ratio do
      {:ok, ratio}
    else
      {:error, {:contrast_too_low, ratio, min_ratio}}
    end
  end

  @doc """
  Adjusts a color palette to ensure all colors are accessible against a background.

  ## Parameters

  - `colors` - Map of colors to adjust
  - `background` - Background color to check against

  ## Returns

  - Map of adjusted colors
  """
  @spec adjust_palette(map(), Color.t() | String.t()) :: map()
  def adjust_palette(colors, background) do
    bg = normalize_color(background)
    adjusted = adjust_colors(colors, bg)

    case validate_colors(adjusted, background: bg.hex, level: :aa) do
      {:ok, _} -> adjusted
      {:error, _} -> fallback_colors(colors, bg)
    end
  end

  defp adjust_colors(colors, bg) do
    colors
    |> Enum.map(fn {key, color} ->
      if key == :background,
        do: {key, color},
        else:
          {key, suggest_accessible_color(color, background: bg.hex, level: :aa)}
    end)
    |> Map.new()
  end

  defp fallback_colors(colors, bg) do
    colors
    |> Enum.map(fn {key, _color} ->
      if key == :background,
        do: {key, bg.hex},
        else: {key, get_optimal_text_color(bg)}
    end)
    |> Map.new()
  end

  @spec suitable_for_text?(Color.t() | String.t(), Color.t() | String.t()) ::
          boolean()
  def suitable_for_text?(color, background) do
    case check_contrast(color, background, :aa) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp extract_background(opts) do
    background = Keyword.get(opts, :background)

    if binary?(background),
      do: Color.from_hex(background),
      else: background || Color.from_hex("#FFFFFF")
  end

  defp normalize_colors_map(colors) do
    Map.new(colors, fn {k, v} ->
      {k, if(binary?(v), do: Color.from_hex(v), else: v)}
    end)
  end

  defp find_contrast_issues(colors_map, bg, level) do
    colors_map
    |> Enum.reject(fn {key, _} -> key == :background end)
    |> Enum.flat_map(fn {key, color} ->
      case check_contrast(color, bg, level) do
        {:ok, _} -> []
        {:error, _} -> [{key, :insufficient_contrast}]
      end
    end)
  end
end
