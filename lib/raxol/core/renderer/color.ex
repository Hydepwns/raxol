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
    with true <- Enum.member?(@ansi_16_atoms, color),
         code = @ansi_16_map[color] do
      cond do
        # Bright colors (90-97)
        code >= 8 ->
          "\e[#{90 + (code - 8)}m"

        # Standard colors (30-37)
        true ->
          "\e[#{30 + code}m"
      end
    else
      _ ->
        raise ArgumentError, "Invalid color format"
    end
  end

  def to_ansi(color) when is_integer(color) and color in 0..255 do
    "\e[38;5;#{color}m"
  end

  def to_ansi({r, g, b}) when r in 0..255 and g in 0..255 and b in 0..255 do
    "\e[38;2;#{r};#{g};#{b}m"
  end

  def to_ansi("#" <> _ = hex) do
    hex
    |> hex_to_rgb()
    |> to_ansi()
  end

  @doc """
  Converts a color representation to its ANSI background escape code.
  """
  def to_bg_ansi(color)

  def to_bg_ansi(:default), do: "\e[49m"

  def to_bg_ansi(color) when is_atom(color) do
    with true <- Enum.member?(@ansi_16_atoms, color),
         code = @ansi_16_map[color] do
      cond do
        # Bright colors (100-107)
        code >= 8 ->
          "\e[#{100 + (code - 8)}m"

        # Standard colors (40-47)
        true ->
          "\e[#{40 + code}m"
      end
    else
      _ ->
        raise ArgumentError, "Invalid color format"
    end
  end

  def to_bg_ansi(color) when is_integer(color) and color in 0..255 do
    "\e[48;5;#{color}m"
  end

  def to_bg_ansi({r, g, b}) when r in 0..255 and g in 0..255 and b in 0..255 do
    "\e[48;2;#{r};#{g};#{b}m"
  end

  def to_bg_ansi("#" <> _ = hex) do
    hex
    |> hex_to_rgb()
    |> to_bg_ansi()
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
  def create_theme(colors) when is_map(colors) do
    processed_colors =
      colors
      |> Enum.map(fn
        {key, "#" <> _ = hex} -> {key, hex_to_rgb(hex)}
        {key, value} when is_atom(value) and value in @ansi_16_atoms -> {key, value}
        {key, {r, g, b}} when r in 0..255 and g in 0..255 and b in 0..255 -> {key, {r, g, b}}
        {key, value} -> raise ArgumentError, "Invalid color in theme: #{inspect(value)}"
      end)
      |> Map.new()

    default = default_theme()
    Map.merge(default.colors, processed_colors)
  end

  def create_theme(_), do: raise ArgumentError, "Theme must be a map"

  @doc """
  Returns the default color theme.
  """
  def default_theme do
    Raxol.UI.Theming.Theme.get(Raxol.UI.Theming.Theme.default_theme_id())
  end

  @doc """
  Converts a hex color string to RGB.
  """
  def hex_to_rgb("#" <> hex) do
    case String.length(hex) do
      6 ->
        <<r::binary-size(2), g::binary-size(2), b::binary-size(2)>> = hex

        {String.to_integer(r, 16), String.to_integer(g, 16),
         String.to_integer(b, 16)}

      3 ->
        <<r::binary-size(1), g::binary-size(1), b::binary-size(1)>> = hex

        {
          String.to_integer(r <> r, 16),
          String.to_integer(g <> g, 16),
          String.to_integer(b <> b, 16)
        }
    end
  end

  @doc """
  Converts RGB values to the nearest ANSI 256 color code.
  """
  def rgb_to_ansi256({r, g, b}) do
    # 6x6x6 color cube
    if r == g and g == b do
      # Grayscale ramp
      cond do
        r < 4 -> 16
        r > 251 -> 231
        true -> 232 + div(r - 4, 10)
      end
    else
      # Color cube
      ir = div(r * 6, 256)
      ig = div(g * 6, 256)
      ib = div(b * 6, 256)
      16 + 36 * ir + 6 * ig + ib
    end
  end

  # Private Helpers

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
