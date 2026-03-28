defmodule Raxol.Terminal.ANSI.TextFormatting.Colors do
  @moduledoc """
  Color handling utilities for ANSI text formatting.
  """
  @compile {:no_warn_undefined, Raxol.Terminal.ANSI.TextFormatting.ColorMap}

  alias Raxol.Terminal.ANSI.TextFormatting.ColorMap

  def ansi_code_to_color_name(code), do: ColorMap.ansi_code_to_name(code)

  def build_foreground_codes(nil), do: []

  def build_foreground_codes(color) when is_binary(color) do
    case ColorMap.name_to_fg_code(color) do
      nil -> []
      code -> [to_string(code)]
    end
  end

  def build_foreground_codes(color) when is_atom(color) do
    case ColorMap.name_to_fg_code(to_string(color)) do
      nil -> []
      code -> [to_string(code)]
    end
  end

  def build_foreground_codes(color) when is_integer(color),
    do: [to_string(color)]

  def build_foreground_codes(_), do: []

  def build_background_codes(nil), do: []

  def build_background_codes(color) when is_binary(color) do
    case ColorMap.name_to_bg_code(color) do
      nil -> []
      code -> [to_string(code)]
    end
  end

  def build_background_codes(color) when is_atom(color) do
    case ColorMap.name_to_bg_code(to_string(color)) do
      nil -> []
      code -> [to_string(code)]
    end
  end

  def build_background_codes(color) when is_integer(color),
    do: [to_string(color + 10)]

  def build_background_codes(_), do: []

  def handle_integer_color_param(code, style) do
    cond do
      code >= 30 and code <= 37 ->
        %{style | foreground: ColorMap.ansi_code_to_name(code)}

      code >= 40 and code <= 47 ->
        %{style | background: ColorMap.ansi_code_to_name(code - 10)}

      code >= 90 and code <= 97 ->
        base_color = ColorMap.ansi_code_to_name(code - 60)
        %{style | foreground: base_color, bold: true}

      code >= 100 and code <= 107 ->
        base_color = ColorMap.ansi_code_to_name(code - 70)
        %{style | background: base_color}

      true ->
        style
    end
  end

  def handle_tuple_color_param(tuple, style) do
    case tuple do
      {38, 5, n} when n >= 0 and n <= 255 ->
        %{style | foreground: {:indexed, n}}

      {48, 5, n} when n >= 0 and n <= 255 ->
        %{style | background: {:indexed, n}}

      {38, 2, r, g, b}
      when r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 ->
        %{style | foreground: {:rgb, r, g, b}}

      {48, 2, r, g, b}
      when r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 ->
        %{style | background: {:rgb, r, g, b}}

      _ ->
        style
    end
  end
end
