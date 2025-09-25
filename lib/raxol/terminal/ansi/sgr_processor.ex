defmodule Raxol.Terminal.ANSI.SGRProcessor do
  @moduledoc """
  Processes SGR (Select Graphic Rendition) ANSI escape sequences.

  SGR sequences control text formatting attributes like colors, bold, italic, etc.
  This module handles parsing SGR parameters and updating terminal styles accordingly.
  """

  @doc """
  Handles SGR parameters and updates the style state.

  ## Parameters
    - params: String of SGR parameters (e.g., "31", "1;4;31;48;5;196")
    - style: Current style state (can be nil or a map)

  ## Returns
    Updated style map
  """
  @spec handle_sgr(String.t(), any()) :: map()
  def handle_sgr(params, style) when is_binary(params) do
    style = ensure_style_map(style)

    params
    |> parse_params()
    |> process_params(style)
  end

  @doc """
  Process SGR codes with parsed parameters.

  ## Parameters
    - codes: List of integer SGR codes
    - style: Current style map

  ## Returns
    Updated style map
  """
  @spec process_sgr_codes(list(integer()), map()) :: map()
  def process_sgr_codes(codes, style) do
    style = ensure_style_map(style)
    process_params(codes, style)
  end

  # Private functions

  defp ensure_style_map(nil), do: default_style()
  defp ensure_style_map(style) when is_map(style), do: style
  defp ensure_style_map(_), do: default_style()

  defp default_style do
    %{
      foreground: nil,
      background: nil,
      bold: false,
      italic: false,
      underline: false,
      blink: false,
      reverse: false,
      hidden: false,
      strikethrough: false,
      dim: false,
      # Extended attributes
      underline_color: nil,
      underline_style: :single,
      overline: false
    }
  end

  defp parse_params(""), do: [0]

  defp parse_params(params) do
    params
    |> String.split(";")
    |> Enum.map(&parse_int/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_int(str) do
    case Integer.parse(str) do
      {num, ""} -> num
      _ -> nil
    end
  end

  defp process_params([], style), do: style

  defp process_params([code | rest], style) do
    updated_style = apply_sgr_code(code, style, rest)
    {_consumed, remaining} = get_consumed_params(code, rest)
    process_params(remaining, updated_style)
  end

  defp apply_sgr_code(0, _style, _rest), do: default_style()

  # Text attributes
  defp apply_sgr_code(1, style, _rest), do: Map.put(style, :bold, true)
  defp apply_sgr_code(2, style, _rest), do: Map.put(style, :dim, true)
  defp apply_sgr_code(3, style, _rest), do: Map.put(style, :italic, true)
  defp apply_sgr_code(4, style, _rest), do: Map.put(style, :underline, true)
  defp apply_sgr_code(5, style, _rest), do: Map.put(style, :blink, true)
  # Rapid blink
  defp apply_sgr_code(6, style, _rest), do: Map.put(style, :blink, true)
  defp apply_sgr_code(7, style, _rest), do: Map.put(style, :reverse, true)
  defp apply_sgr_code(8, style, _rest), do: Map.put(style, :hidden, true)
  defp apply_sgr_code(9, style, _rest), do: Map.put(style, :strikethrough, true)

  # Reset specific attributes
  defp apply_sgr_code(21, style, _rest), do: Map.put(style, :bold, false)
  defp apply_sgr_code(22, style, _rest), do: %{style | bold: false, dim: false}
  defp apply_sgr_code(23, style, _rest), do: Map.put(style, :italic, false)
  defp apply_sgr_code(24, style, _rest), do: Map.put(style, :underline, false)
  defp apply_sgr_code(25, style, _rest), do: Map.put(style, :blink, false)
  defp apply_sgr_code(27, style, _rest), do: Map.put(style, :reverse, false)
  defp apply_sgr_code(28, style, _rest), do: Map.put(style, :hidden, false)

  defp apply_sgr_code(29, style, _rest),
    do: Map.put(style, :strikethrough, false)

  # Basic foreground colors (30-37)
  defp apply_sgr_code(code, style, _rest) when code >= 30 and code <= 37 do
    Map.put(style, :foreground, basic_color(code - 30))
  end

  # Extended foreground color (38)
  defp apply_sgr_code(38, style, [5, color | _rest])
       when color >= 0 and color <= 255 do
    Map.put(style, :foreground, {:indexed, color})
  end

  defp apply_sgr_code(38, style, [2, r, g, b | _rest])
       when r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 do
    Map.put(style, :foreground, {:rgb, r, g, b})
  end

  # Default foreground (39)
  defp apply_sgr_code(39, style, _rest), do: Map.put(style, :foreground, nil)

  # Basic background colors (40-47)
  defp apply_sgr_code(code, style, _rest) when code >= 40 and code <= 47 do
    Map.put(style, :background, basic_color(code - 40))
  end

  # Extended background color (48)
  defp apply_sgr_code(48, style, [5, color | _rest])
       when color >= 0 and color <= 255 do
    Map.put(style, :background, {:indexed, color})
  end

  defp apply_sgr_code(48, style, [2, r, g, b | _rest])
       when r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 do
    Map.put(style, :background, {:rgb, r, g, b})
  end

  # Default background (49)
  defp apply_sgr_code(49, style, _rest), do: Map.put(style, :background, nil)

  # Overline (53)
  defp apply_sgr_code(53, style, _rest), do: Map.put(style, :overline, true)
  defp apply_sgr_code(55, style, _rest), do: Map.put(style, :overline, false)

  # Underline color (58)
  defp apply_sgr_code(58, style, [5, color | _rest])
       when color >= 0 and color <= 255 do
    Map.put(style, :underline_color, {:indexed, color})
  end

  defp apply_sgr_code(58, style, [2, r, g, b | _rest])
       when r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 do
    Map.put(style, :underline_color, {:rgb, r, g, b})
  end

  # Default underline color (59)
  defp apply_sgr_code(59, style, _rest),
    do: Map.put(style, :underline_color, nil)

  # Bright foreground colors (90-97)
  defp apply_sgr_code(code, style, _rest) when code >= 90 and code <= 97 do
    Map.put(style, :foreground, bright_color(code - 90))
  end

  # Bright background colors (100-107)
  defp apply_sgr_code(code, style, _rest) when code >= 100 and code <= 107 do
    Map.put(style, :background, bright_color(code - 100))
  end

  # Unhandled codes - return style unchanged
  defp apply_sgr_code(_code, style, _rest), do: style

  defp get_consumed_params(38, [5, _ | rest]), do: {2, rest}
  defp get_consumed_params(38, [2, _, _, _ | rest]), do: {4, rest}
  defp get_consumed_params(48, [5, _ | rest]), do: {2, rest}
  defp get_consumed_params(48, [2, _, _, _ | rest]), do: {4, rest}
  defp get_consumed_params(58, [5, _ | rest]), do: {2, rest}
  defp get_consumed_params(58, [2, _, _, _ | rest]), do: {4, rest}
  defp get_consumed_params(_, rest), do: {0, rest}

  defp basic_color(0), do: :black
  defp basic_color(1), do: :red
  defp basic_color(2), do: :green
  defp basic_color(3), do: :yellow
  defp basic_color(4), do: :blue
  defp basic_color(5), do: :magenta
  defp basic_color(6), do: :cyan
  defp basic_color(7), do: :white
  defp basic_color(_), do: nil

  defp bright_color(0), do: :bright_black
  defp bright_color(1), do: :bright_red
  defp bright_color(2), do: :bright_green
  defp bright_color(3), do: :bright_yellow
  defp bright_color(4), do: :bright_blue
  defp bright_color(5), do: :bright_magenta
  defp bright_color(6), do: :bright_cyan
  defp bright_color(7), do: :bright_white
  defp bright_color(_), do: nil
end
