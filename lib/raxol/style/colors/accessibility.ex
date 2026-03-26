defmodule Raxol.Style.Colors.Accessibility do
  @moduledoc """
  Provides utilities for color accessibility, focusing on WCAG contrast.
  """

  @compile {:no_warn_undefined,
            [
              Raxol.Style.Colors.Accessibility.Suggester,
              Raxol.Style.Colors.Accessibility.PaletteGenerator
            ]}

  alias Raxol.Style.Colors.Color
  alias Raxol.Style.Colors.Accessibility.Suggester
  alias Raxol.Style.Colors.Accessibility.PaletteGenerator

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
  def relative_luminance(color) when is_binary(color) do
    case Color.from_hex(color) do
      %Color{} = c -> relative_luminance(c)
      _ -> +0.0
    end
  end

  def relative_luminance(%Color{r: r, g: g, b: b}) do
    r_lin = _channel_to_linear(r)
    g_lin = _channel_to_linear(g)
    b_lin = _channel_to_linear(b)

    0.2126 * r_lin + 0.7152 * g_lin + 0.0722 * b_lin
  end

  # WCAG formula for converting sRGB channel to linear value
  defp _channel_to_linear(channel_val)
       when channel_val >= 0 and channel_val <= 255 do
    v = channel_val / 255
    convert_to_linear(v <= 0.03928, v)
  end

  defp convert_to_linear(true, v), do: v / 12.92
  defp convert_to_linear(false, v), do: :math.pow((v + 0.055) / 1.055, 2.4)

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
      when is_binary(color1) or is_binary(color2) do
    c1 =
      case color1 do
        color when is_binary(color) -> Color.from_hex(color)
        color -> color
      end

    c2 =
      case color2 do
        color when is_binary(color) -> Color.from_hex(color)
        color -> color
      end

    contrast_ratio(c1, c2)
  end

  def contrast_ratio(%Color{} = color1, %Color{} = color2) do
    l1 = relative_luminance(color1)
    l2 = relative_luminance(color2)
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

    validate_contrast_ratio(ratio >= min_ratio, ratio, min_ratio)
  end

  defp validate_contrast_ratio(true, ratio, _min_ratio), do: {:ok, ratio}

  defp validate_contrast_ratio(false, ratio, min_ratio) do
    {:error, {:contrast_too_low, ratio, min_ratio}}
  end

  # --- Delegations to Suggester ---

  @doc """
  Suggests an appropriate text color (black or white) for a given background.

  Ensures minimum AA contrast.
  """
  defdelegate suggest_text_color(background), to: Suggester

  @doc """
  Suggests a color with good contrast (at least AA) to the base color.

  Prioritizes complementary color, then black/white.
  """
  defdelegate suggest_contrast_color(color), to: Suggester

  @doc """
  Finds an accessible color pair (foreground/background) based on a base color and WCAG level.
  """
  def accessible_color_pair(base_color, level \\ :aa) do
    Suggester.accessible_color_pair(base_color, level)
  end

  defdelegate get_optimal_text_color(background), to: Suggester

  @spec suggest_accessible_color(
          Color.t() | String.t(),
          Color.t() | String.t() | Keyword.t()
        ) :: String.t()
  defdelegate suggest_accessible_color(color, background_or_opts), to: Suggester

  @spec lighten_until_contrast(Color.t(), Color.t(), number()) ::
          Color.t() | nil
  defdelegate lighten_until_contrast(color, background, target_ratio),
    to: Suggester

  @spec darken_until_contrast(Color.t(), Color.t(), number()) :: Color.t() | nil
  defdelegate darken_until_contrast(color, background, target_ratio),
    to: Suggester

  # --- Delegations to PaletteGenerator ---

  @spec generate_accessible_palette(
          Color.t() | String.t(),
          Color.t() | String.t() | Keyword.t()
        ) :: map()
  defdelegate generate_accessible_palette(base_color, opts),
    to: PaletteGenerator

  @spec validate_colors(map(), Color.t() | String.t() | Keyword.t()) ::
          {:ok, map()} | {:error, Keyword.t()}
  defdelegate validate_colors(colors, opts), to: PaletteGenerator

  @doc """
  Adjusts a color palette to ensure all colors are accessible against a background.
  """
  @spec adjust_palette(map(), Color.t() | String.t()) :: map()
  defdelegate adjust_palette(colors, background), to: PaletteGenerator

  @spec suitable_for_text?(Color.t() | String.t(), Color.t() | String.t()) ::
          boolean()
  defdelegate suitable_for_text?(color, background), to: PaletteGenerator
end
