defmodule Raxol.Terminal.ANSI.TextFormatting.SGR do
  @moduledoc """
  SGR (Select Graphic Rendition) parameter handling for the Raxol Terminal ANSI TextFormatting module.
  Handles SGR parameter parsing, formatting, and attribute handling.
  """

  alias Raxol.Terminal.ANSI.TextFormatting.{Core, Colors}

  @sgr_style_map %{
    bold: 1,
    italic: 3,
    underline: 4,
    blink: 5,
    reverse: 7,
    conceal: 8,
    strikethrough: 9
  }

  @doc """
  Formats a style into SGR (Select Graphic Rendition) parameters.
  Returns a string of ANSI SGR codes.
  """
  @spec format_sgr_params(Core.text_style()) :: String.t()
  def format_sgr_params(style) do
    style_codes = build_style_codes(style)
    fg_codes = Colors.build_foreground_codes(style.foreground)
    bg_codes = Colors.build_background_codes(style.background)

    (style_codes ++ fg_codes ++ bg_codes)
    |> Enum.join(";")
  end

  @doc """
  Builds style codes for SGR formatting.
  """
  @spec build_style_codes(Core.text_style()) :: [integer()]
  def build_style_codes(style) do
    Enum.reduce(@sgr_style_map, [], fn {attr, code}, acc ->
      if Map.get(style, attr), do: [code] ++ acc, else: acc
    end)
  end

  @doc """
  Parses SGR (Select Graphic Rendition) parameters and applies them to the style.
  """
  @spec parse_sgr_param(integer() | tuple(), Core.text_style()) :: Core.text_style()
  def parse_sgr_param(param, style) do
    case param do
      0 -> Core.new()
      code when is_integer(code) -> handle_integer_param(code, style)
      tuple when is_tuple(tuple) -> handle_tuple_param(tuple, style)
      _ -> style
    end
  end

  @doc """
  Handles integer SGR parameters.
  """
  @spec handle_integer_param(integer(), Core.text_style()) :: Core.text_style()
  def handle_integer_param(code, style) do
    cond do
      # Basic attributes
      code in [1, 2, 3, 4, 5, 7, 8, 9] ->
        handle_basic_attribute(code, style)

      # Advanced attributes
      code in [51, 52, 53, 54, 55] ->
        handle_advanced_attribute(code, style)

      # Colors - delegate to Colors module
      code in [30, 31, 32, 33, 34, 35, 36, 37, 90, 91, 92, 93, 94, 95, 96, 97,
               40, 41, 42, 43, 44, 45, 46, 47, 100, 101, 102, 103, 104, 105, 106, 107] ->
        Colors.handle_integer_color_param(code, style)

      true ->
        style
    end
  end

  @doc """
  Handles basic SGR attributes.
  """
  @spec handle_basic_attribute(integer(), Core.text_style()) :: Core.text_style()
  def handle_basic_attribute(code, style) do
    case code do
      1 -> %{style | bold: true}
      2 -> %{style | faint: true}
      3 -> %{style | italic: true}
      4 -> %{style | underline: true}
      5 -> %{style | blink: true}
      7 -> %{style | reverse: true}
      8 -> %{style | conceal: true}
      9 -> %{style | strikethrough: true}
    end
  end

  @doc """
  Handles advanced SGR attributes.
  """
  @spec handle_advanced_attribute(integer(), Core.text_style()) :: Core.text_style()
  def handle_advanced_attribute(code, style) do
    case code do
      51 -> %{style | framed: true}
      52 -> %{style | encircled: true}
      53 -> %{style | overlined: true}
      54 -> %{style | framed: false, encircled: false}
      55 -> %{style | overlined: false}
    end
  end

  @doc """
  Handles tuple SGR parameters.
  """
  @spec handle_tuple_param(tuple(), Core.text_style()) :: Core.text_style()
  def handle_tuple_param(tuple, style) do
    Colors.handle_tuple_color_param(tuple, style)
  end
end
