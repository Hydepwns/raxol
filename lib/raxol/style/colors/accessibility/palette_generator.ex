defmodule Raxol.Style.Colors.Accessibility.PaletteGenerator do
  @moduledoc """
  Generates and validates accessible color palettes based on WCAG contrast requirements.

  Extracted from Raxol.Style.Colors.Accessibility.
  """

  alias Raxol.Style.Colors.Accessibility
  alias Raxol.Style.Colors.Accessibility.Suggester
  alias Raxol.Style.Colors.Color

  def generate_accessible_palette(base_color, opts) when is_list(opts) do
    background = Keyword.get(opts, :background)
    level = Keyword.get(opts, :level, :aa)

    base = normalize_color(base_color)
    bg = normalize_background(background)

    text =
      Suggester.suggest_accessible_color(Color.from_hex("#000000"),
        background: bg.hex,
        level: level
      )

    secondary =
      Suggester.suggest_accessible_color(base.hex,
        background: bg.hex,
        level: level
      )

    rotated = Raxol.Style.Colors.HSL.rotate_hue(base, 180)

    accent =
      Suggester.suggest_accessible_color(rotated.hex,
        background: bg.hex,
        level: level
      )

    link =
      Suggester.suggest_accessible_color("#0066CC",
        background: bg.hex,
        level: level
      )

    success =
      Suggester.suggest_accessible_color("#28A745",
        background: bg.hex,
        level: level
      )

    warning =
      Suggester.suggest_accessible_color("#FFC107",
        background: bg.hex,
        level: level
      )

    error =
      Suggester.suggest_accessible_color("#DC3545",
        background: bg.hex,
        level: level
      )

    info =
      Suggester.suggest_accessible_color("#17A2B8",
        background: bg.hex,
        level: level
      )

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
      when is_binary(background) do
    generate_accessible_palette(base_color, background: background)
  end

  def validate_colors(colors, opts) when is_list(opts) do
    bg = extract_background(opts)
    colors_map = normalize_colors_map(colors)

    issues =
      find_contrast_issues(colors_map, bg, Keyword.get(opts, :level, :aa))

    format_validation_result(Enum.empty?(issues), colors, issues)
  end

  def validate_colors(colors, background) when is_binary(background) do
    validate_colors(colors, background: background)
  end

  def adjust_palette(colors, background) do
    bg = normalize_color(background)
    adjusted = adjust_colors(colors, bg)

    case validate_colors(adjusted, background: bg.hex, level: :aa) do
      {:ok, _} -> adjusted
      {:error, _} -> fallback_colors(colors, bg)
    end
  end

  def suitable_for_text?(color, background) do
    case Accessibility.check_contrast(color, background, :aa) do
      {:ok, _} -> true
      _ -> false
    end
  end

  # --- Private Helpers ---

  defp normalize_color(color) when is_binary(color), do: Color.from_hex(color)
  defp normalize_color(color), do: color

  defp normalize_background(nil), do: Color.from_hex("#FFFFFF")

  defp normalize_background(background) when is_binary(background),
    do: Color.from_hex(background)

  defp normalize_background(background), do: background

  defp format_validation_result(true, colors, _issues), do: {:ok, colors}
  defp format_validation_result(false, _colors, issues), do: {:error, issues}

  defp extract_background(opts) do
    background = Keyword.get(opts, :background)
    convert_background_color(is_binary(background), background)
  end

  defp convert_background_color(true, background),
    do: Color.from_hex(background)

  defp convert_background_color(false, background),
    do: background || Color.from_hex("#FFFFFF")

  defp normalize_colors_map(colors) do
    Map.new(colors, fn {k, v} ->
      {k, normalize_color_value(is_binary(v), v)}
    end)
  end

  defp normalize_color_value(true, v), do: Color.from_hex(v)
  defp normalize_color_value(false, v), do: v

  defp find_contrast_issues(colors_map, bg, level) do
    colors_map
    |> Enum.reject(fn {key, _} -> key == :background end)
    |> Enum.flat_map(fn {key, color} ->
      case Accessibility.check_contrast(color, bg, level) do
        {:ok, _} -> []
        {:error, _} -> [{key, :insufficient_contrast}]
      end
    end)
  end

  defp adjust_colors(colors, bg) do
    colors
    |> Enum.map(fn {key, color} ->
      adjust_color_by_key(key == :background, key, color, bg.hex)
    end)
    |> Map.new()
  end

  defp adjust_color_by_key(true, key, color, _bg_hex), do: {key, color}

  defp adjust_color_by_key(false, key, color, bg_hex) do
    {key,
     Suggester.suggest_accessible_color(color, background: bg_hex, level: :aa)}
  end

  defp fallback_colors(colors, bg) do
    colors
    |> Enum.map(fn {key, _color} ->
      set_fallback_color(key == :background, key, bg)
    end)
    |> Map.new()
  end

  defp set_fallback_color(true, key, bg), do: {key, bg.hex}

  defp set_fallback_color(false, key, bg),
    do: {key, Suggester.get_optimal_text_color(bg)}
end
