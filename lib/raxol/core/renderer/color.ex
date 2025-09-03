defmodule Raxol.Core.Renderer.Color do
  @moduledoc """
  Provides comprehensive color support for terminal rendering.

  Supports:
  * ANSI 16 colors (4-bit)
  * ANSI 256 colors (8-bit)
  * True Color (24-bit)
  * Color themes
  * Terminal background detection
  """

  @type color :: ansi_16() | ansi_256() | true_color()
  @type ansi_16 ::
          :black
          | :red
          | :green
          | :yellow
          | :blue
          | :magenta
          | :cyan
          | :white
          | :bright_black
          | :bright_red
          | :bright_green
          | :bright_yellow
          | :bright_blue
          | :bright_magenta
          | :bright_cyan
          | :bright_white
  @type ansi_256 :: 0..255
  @type true_color :: {0..255, 0..255, 0..255}

  @ansi_16_atoms [
    :black,
    :red,
    :green,
    :yellow,
    :blue,
    :magenta,
    :cyan,
    :white,
    :bright_black,
    :bright_red,
    :bright_green,
    :bright_yellow,
    :bright_blue,
    :bright_magenta,
    :bright_cyan,
    :bright_white
  ]

  @ansi_16_map %{
    black: 0,
    red: 1,
    green: 2,
    yellow: 3,
    blue: 4,
    magenta: 5,
    cyan: 6,
    white: 7,
    bright_black: 8,
    bright_red: 9,
    bright_green: 10,
    bright_yellow: 11,
    bright_blue: 12,
    bright_magenta: 13,
    bright_cyan: 14,
    bright_white: 15
  }

  @doc """
  Converts a color representation to its ANSI foreground escape code.
  """
  def to_ansi(color)

  def to_ansi(:default), do: "\e[39m"

  def to_ansi(color) when is_atom(color) do
    if Enum.member?(@ansi_16_atoms, color) do
      code = @ansi_16_map[color]

      if code >= 8 do
        "\e[#{90 + (code - 8)}m"
      else
        "\e[#{30 + code}m"
      end
    else
      raise ArgumentError, "Invalid color format"
    end
  end

  def to_ansi(color) when is_integer(color) and color in 0..255//1 do
    "\e[38;5;#{color}m"
  end

  def to_ansi({r, g, b})
      when r in 0..255//1 and g in 0..255//1 and b in 0..255//1 do
    "\e[38;2;#{r};#{g};#{b}m"
  end

  def to_ansi("#" <> _ = hex) do
    hex
    |> hex_to_rgb()
    |> to_ansi()
  end

  def to_ansi(_invalid) do
    raise ArgumentError, "Invalid color format"
  end

  @doc """
  Converts a color representation to its ANSI background escape code.
  """
  def to_bg_ansi(color)

  def to_bg_ansi(:default), do: "\e[49m"

  def to_bg_ansi(color) when is_atom(color) do
    case {Enum.member?(@ansi_16_atoms, color), @ansi_16_map[color]} do
      {true, code} when not is_nil(code) ->
        if code >= 8 do
          "\e[#{100 + (code - 8)}m"
        else
          "\e[#{40 + code}m"
        end

      _ ->
        raise ArgumentError, "Invalid color format"
    end
  end

  def to_bg_ansi(color) when is_integer(color) and color in 0..255//1 do
    "\e[48;5;#{color}m"
  end

  def to_bg_ansi({r, g, b})
      when r in 0..255//1 and g in 0..255//1 and b in 0..255//1 do
    "\e[48;2;#{r};#{g};#{b}m"
  end

  def to_bg_ansi("#" <> _ = hex) do
    hex
    |> hex_to_rgb()
    |> to_bg_ansi()
  end

  def to_bg_ansi(_invalid) do
    raise ArgumentError, "Invalid color format"
  end

  @doc """
  Detects the terminal's background color.
  Returns :light or :dark.
  """
  def detect_background do
    case System.get_env("COLORFGBG") do
      nil -> detect_background_fallback()
      value -> parse_colorfgbg(value)
    end
  end

  @doc """
  Creates a color theme map.
  """
  def create_theme(input) when not is_map(input) do
    raise ArgumentError, "Theme must be a map"
  end

  def create_theme(%{colors: colors}) when not is_map(colors) do
    raise ArgumentError, "Theme colors must be a map"
  end

  def create_theme(colors) when is_map(colors) do
    processed_colors = process_theme_colors(colors)
    default = default_theme()
    %{colors: Map.merge(default.colors, processed_colors)}
  end

  defp process_theme_colors(colors) do
    colors
    |> Enum.map(&process_color_entry/1)
    |> Map.new()
  end

  defp process_color_entry({key, "#" <> _ = hex}) do
    {key, hex_to_rgb(hex)}
  end

  defp process_color_entry({key, value})
       when is_atom(value) and value in @ansi_16_atoms do
    {key, value}
  end

  defp process_color_entry({key, {r, g, b}})
       when r in 0..255//1 and g in 0..255//1 and b in 0..255//1 do
    {key, {r, g, b}}
  end

  defp process_color_entry({_key, value}) do
    msg =
      if is_binary(value),
        do: "Invalid color in theme: #{value}",
        else: "Invalid color in theme: #{inspect(value)}"

    raise(ArgumentError, msg)
  end

  @doc """
  Returns the default color theme.
  """
  def default_theme do
    theme =
      Raxol.UI.Theming.Theme.get(Raxol.UI.Theming.Theme.default_theme_id())

    colors = convert_theme_colors(theme.colors)
    merged_colors = merge_with_defaults(colors)
    %{colors: merged_colors}
  end

  defp convert_theme_colors(colors) do
    colors
    |> Enum.map(fn {key, color} ->
      case color do
        %Raxol.Style.Colors.Color{r: r, g: g, b: b} -> {key, {r, g, b}}
        hex when is_binary(hex) -> {key, hex_to_rgb(hex)}
        other -> {key, other}
      end
    end)
    |> Map.new()
  end

  defp merge_with_defaults(colors) do
    default_values = %{
      foreground: {0, 0, 0},
      background: {255, 255, 255},
      primary: {0, 119, 204},
      secondary: {102, 102, 102},
      accent: {255, 153, 0},
      error: {204, 0, 0},
      warning: {255, 153, 0},
      success: {0, 153, 0},
      surface: {245, 245, 245},
      text: {51, 51, 51},
      info: {0, 153, 204}
    }

    required_keys = Map.keys(default_values)

    Enum.reduce(required_keys, colors, fn key, acc ->
      Map.put_new(acc, key, default_values[key])
    end)
  end

  @doc """
  Converts a hex color string to RGB.
  """
  def hex_to_rgb("#" <> hex) when is_binary(hex) do
    case String.length(hex) do
      6 -> parse_6_digit_hex(hex)
      3 -> parse_3_digit_hex(hex)
      _ -> raise ArgumentError, "Invalid hex color format"
    end
  end

  def hex_to_rgb(invalid) when is_binary(invalid) do
    raise ArgumentError, "Invalid hex color format"
  end

  defp parse_6_digit_hex(hex) when is_binary(hex) do
    case parse_hex_components(hex, 2) do
      {:ok, {r, g, b}} -> {r, g, b}
      {:error, _} -> raise ArgumentError, "Invalid hex color format"
    end
  end

  defp parse_3_digit_hex(hex) when is_binary(hex) do
    case parse_hex_components(hex, 1) do
      {:ok, {r, g, b}} -> {r, g, b}
      {:error, _} -> raise ArgumentError, "Invalid hex color format"
    end
  end

  defp parse_hex_components(hex, size) when is_binary(hex) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           case size do
             2 ->
               <<r::binary-size(2), g::binary-size(2), b::binary-size(2)>> = hex

               {:ok,
                {String.to_integer(r, 16), String.to_integer(g, 16),
                 String.to_integer(b, 16)}}

             1 ->
               <<r::binary-size(1), g::binary-size(1), b::binary-size(1)>> = hex

               {:ok,
                {
                  String.to_integer(r <> r, 16),
                  String.to_integer(g <> g, 16),
                  String.to_integer(b <> b, 16)
                }}
           end
         end) do
      {:ok, result} -> result
      {:error, _} -> {:error, :invalid_hex}
    end
  end

  @doc """
  Converts RGB values to the nearest ANSI 256 color code.
  """
  def rgb_to_ansi256({r, g, b})
      when r in 0..255//1 and g in 0..255//1 and b in 0..255//1 do
    if r == g and g == b do
      grayscale_to_ansi256(r)
    else
      color_cube_to_ansi256(r, g, b)
    end
  end

  def rgb_to_ansi256({r, g, b})
      when r < 0 or r > 255 or g < 0 or g > 255 or b < 0 or b > 255 do
    raise ArgumentError, "RGB values must be between 0 and 255"
  end

  def rgb_to_ansi256(_invalid) do
    raise ArgumentError, "Invalid RGB tuple"
  end

  defp grayscale_to_ansi256(r) when r < 4, do: 16
  defp grayscale_to_ansi256(r) when r > 251, do: 231
  defp grayscale_to_ansi256(r), do: 232 + div(r - 4, 10)

  defp color_cube_to_ansi256(r, g, b) do
    ir = div(r * 6, 256)
    ig = div(g * 6, 256)
    ib = div(b * 6, 256)
    16 + 36 * ir + 6 * ig + ib
  end

  defp detect_background_fallback do
    case System.get_env("TERM_PROGRAM") do
      "iTerm.app" -> :black
      "Apple_Terminal" -> :black
      _ -> :default
    end
  end

  defp parse_colorfgbg(value) do
    case String.split(value, ";") do
      [_, "0"] -> :black
      [_, "15"] -> :white
      _ -> :default
    end
  end
end
