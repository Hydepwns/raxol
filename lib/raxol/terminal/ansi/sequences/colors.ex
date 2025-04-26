defmodule Raxol.Terminal.ANSI.Sequences.Colors do
  @moduledoc """
  ANSI Color Sequence Handler.

  Handles parsing and application of ANSI color control sequences,
  including 16-color mode, 256-color mode, and true color (24-bit) mode.
  """

  alias Raxol.Style.Colors.{Color, Advanced}
  alias Raxol.Terminal.ANSI.TextFormatting

  # Standard 16 colors
  @colors %{
    0 => :black,
    1 => :red,
    2 => :green,
    3 => :yellow,
    4 => :blue,
    5 => :magenta,
    6 => :cyan,
    7 => :white,
    8 => :bright_black,
    9 => :bright_red,
    10 => :bright_green,
    11 => :bright_yellow,
    12 => :bright_blue,
    13 => :bright_magenta,
    14 => :bright_cyan,
    15 => :bright_white
  }

  @doc """
  Returns a map of ANSI color codes.

  ## Returns

  A map of color names to ANSI codes.

  ## Examples

      iex> Raxol.Terminal.ANSI.Sequences.Colors.color_codes()
      %{
        black: "\e[30m",
        red: "\e[31m",
        # ... other colors ...
        reset: "\e[0m"
      }
  """
  def color_codes do
    %{
      black: "\e[30m",
      red: "\e[31m",
      green: "\e[32m",
      yellow: "\e[33m",
      blue: "\e[34m",
      magenta: "\e[35m",
      cyan: "\e[36m",
      white: "\e[37m",
      bright_black: "\e[90m",
      bright_red: "\e[91m",
      bright_green: "\e[92m",
      bright_yellow: "\e[93m",
      bright_blue: "\e[94m",
      bright_magenta: "\e[95m",
      bright_cyan: "\e[96m",
      bright_white: "\e[97m",
      reset: "\e[0m"
    }
  end

  @doc """
  Set foreground color using true (24-bit) RGB color.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `r` - Red component (0-255)
  * `g` - Green component (0-255)
  * `b` - Blue component (0-255)

  ## Returns

  Updated emulator state
  """
  def set_foreground_true(emulator, r, g, b) do
    color = Color.from_rgb(r, g, b)

    adapted_color =
      Advanced.adapt_color_advanced(color, preserve_brightness: true)

    %{
      emulator
      | attributes: %{
          emulator.attributes
          | foreground_true: {adapted_color.r, adapted_color.g, adapted_color.b}
        }
    }
  end

  @doc """
  Set background color using true (24-bit) RGB color.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `r` - Red component (0-255)
  * `g` - Green component (0-255)
  * `b` - Blue component (0-255)

  ## Returns

  Updated emulator state
  """
  def set_background_true(emulator, r, g, b) do
    color = Color.from_rgb(r, g, b)

    adapted_color =
      Advanced.adapt_color_advanced(color, preserve_brightness: true)

    %{
      emulator
      | attributes: %{
          emulator.attributes
          | background_true: {adapted_color.r, adapted_color.g, adapted_color.b}
        }
    }
  end

  @doc """
  Set foreground color using 256-color mode.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `index` - Color index (0-255)

  ## Returns

  Updated emulator state
  """
  def set_foreground_256(emulator, index) do
    %{emulator | attributes: %{emulator.attributes | foreground_256: index}}
  end

  @doc """
  Set background color using 256-color mode.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `index` - Color index (0-255)

  ## Returns

  Updated emulator state
  """
  def set_background_256(emulator, index) do
    %{emulator | attributes: %{emulator.attributes | background_256: index}}
  end

  @doc """
  Set foreground color using basic 16-color mode.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `color_code` - Color code (0-15)

  ## Returns

  Updated emulator state
  """
  def set_foreground_basic(emulator, color_code) do
    color_name = Map.get(@colors, color_code)
    new_style = TextFormatting.set_foreground(emulator.style, color_name)
    %{emulator | style: new_style}
  end

  @doc """
  Set background color using basic 16-color mode.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `color_code` - Color code (0-15)

  ## Returns

  Updated emulator state
  """
  def set_background_basic(emulator, color_code) do
    color_name = Map.get(@colors, color_code)
    new_style = TextFormatting.set_background(emulator.style, color_name)
    %{emulator | style: new_style}
  end

  @doc """
  Generate ANSI color code for a given color.

  ## Parameters

  * `color` - The color struct
  * `type` - Either :foreground or :background

  ## Returns

  ANSI escape sequence as string
  """
  def color_code(%Color{r: r, g: g, b: b}, :foreground) do
    "\e[38;2;#{r};#{g};#{b}m"
  end

  def color_code(%Color{r: r, g: g, b: b}, :background) do
    "\e[48;2;#{r};#{g};#{b}m"
  end

  # Return empty string for invalid inputs
  def color_code(_color, _type), do: ""
end
