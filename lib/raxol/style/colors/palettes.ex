defmodule Raxol.Style.Colors.Palettes do
  @moduledoc """
  Predefined color palettes for Raxol.

  This module provides a collection of predefined color palettes that can be used
  throughout the application. Each palette is a map of color names to Color structs.

  ## Usage

  ```elixir
  # Get a predefined palette
  solarized = Palettes.solarized()
  nord = Palettes.nord()
  dracula = Palettes.dracula()

  # Access colors from a palette
  primary = solarized.primary
  background = solarized.background
  ```
  """

  alias Raxol.Style.Colors.Color

  @doc """
  Returns the Solarized color palette.

  ## Examples

      iex> palette = Palettes.solarized()
      iex> palette.primary.hex
      "#268bd2"
  """
  def solarized do
    %{
      base03: Color.from_hex("#002b36"),
      base02: Color.from_hex("#073642"),
      base01: Color.from_hex("#586e75"),
      base00: Color.from_hex("#657b83"),
      base0: Color.from_hex("#839496"),
      base1: Color.from_hex("#93a1a1"),
      base2: Color.from_hex("#eee8d5"),
      base3: Color.from_hex("#fdf6e3"),
      yellow: Color.from_hex("#b58900"),
      orange: Color.from_hex("#cb4b16"),
      red: Color.from_hex("#dc322f"),
      magenta: Color.from_hex("#d33682"),
      violet: Color.from_hex("#6c71c4"),
      blue: Color.from_hex("#268bd2"),
      cyan: Color.from_hex("#2aa198"),
      green: Color.from_hex("#859900"),
      # Semantic mappings
      primary: Color.from_hex("#268bd2"),
      secondary: Color.from_hex("#859900"),
      accent: Color.from_hex("#b58900"),
      background: Color.from_hex("#002b36"),
      foreground: Color.from_hex("#839496")
    }
  end

  @doc """
  Returns the Nord color palette.

  ## Examples

      iex> palette = Palettes.nord()
      iex> palette.primary.hex
      "#5e81ac"
  """
  def nord do
    %{
      # Polar Night
      nord0: Color.from_hex("#2e3440"),
      nord1: Color.from_hex("#3b4252"),
      nord2: Color.from_hex("#434c5e"),
      nord3: Color.from_hex("#4c566a"),
      # Snow Storm
      nord4: Color.from_hex("#d8dee9"),
      nord5: Color.from_hex("#e5e9f0"),
      nord6: Color.from_hex("#eceff4"),
      # Frost
      nord7: Color.from_hex("#8fbcbb"),
      nord8: Color.from_hex("#88c0d0"),
      nord9: Color.from_hex("#81a1c1"),
      nord10: Color.from_hex("#5e81ac"),
      # Aurora
      nord11: Color.from_hex("#bf616a"),
      nord12: Color.from_hex("#d08770"),
      nord13: Color.from_hex("#ebcb8b"),
      nord14: Color.from_hex("#a3be8c"),
      nord15: Color.from_hex("#b48ead"),
      # Semantic mappings
      primary: Color.from_hex("#5e81ac"),
      secondary: Color.from_hex("#88c0d0"),
      accent: Color.from_hex("#ebcb8b"),
      background: Color.from_hex("#2e3440"),
      foreground: Color.from_hex("#d8dee9")
    }
  end

  @doc """
  Returns the Dracula color palette.

  ## Examples

      iex> palette = Palettes.dracula()
      iex> palette.primary.hex
      "#bd93f9"
  """
  def dracula do
    %{
      background: Color.from_hex("#282a36"),
      current_line: Color.from_hex("#44475a"),
      foreground: Color.from_hex("#f8f8f2"),
      comment: Color.from_hex("#6272a4"),
      cyan: Color.from_hex("#8be9fd"),
      green: Color.from_hex("#50fa7b"),
      orange: Color.from_hex("#ffb86c"),
      pink: Color.from_hex("#ff79c6"),
      purple: Color.from_hex("#bd93f9"),
      red: Color.from_hex("#ff5555"),
      yellow: Color.from_hex("#f1fa8c"),
      # Semantic mappings
      primary: Color.from_hex("#bd93f9"),
      secondary: Color.from_hex("#8be9fd"),
      accent: Color.from_hex("#ff79c6"),
      background: Color.from_hex("#282a36"),
      foreground: Color.from_hex("#f8f8f2")
    }
  end

  @doc """
  Returns the standard ANSI 16-color palette.

  ## Examples

      iex> palette = Palettes.ansi_16()
      iex> palette.black.hex
      "#000000"
  """
  def ansi_16 do
    %{
      black: Color.from_ansi(0),
      red: Color.from_ansi(1),
      green: Color.from_ansi(2),
      yellow: Color.from_ansi(3),
      blue: Color.from_ansi(4),
      magenta: Color.from_ansi(5),
      cyan: Color.from_ansi(6),
      white: Color.from_ansi(7),
      bright_black: Color.from_ansi(8),
      bright_red: Color.from_ansi(9),
      bright_green: Color.from_ansi(10),
      bright_yellow: Color.from_ansi(11),
      bright_blue: Color.from_ansi(12),
      bright_magenta: Color.from_ansi(13),
      bright_cyan: Color.from_ansi(14),
      bright_white: Color.from_ansi(15),
      # Semantic mappings
      primary: Color.from_ansi(4),    # blue
      secondary: Color.from_ansi(2),  # green
      accent: Color.from_ansi(3),     # yellow
      background: Color.from_ansi(0), # black
      foreground: Color.from_ansi(7)  # white
    }
  end

  @doc """
  Returns a custom palette based on a primary color.

  ## Examples

      iex> palette = Palettes.from_primary("#4285F4")  # Google Blue
      iex> palette.primary.hex
      "#4285F4"
  """
  def from_primary(primary_color) when is_binary(primary_color) do
    primary = Color.from_hex(primary_color)
    from_primary(primary)
  end

  def from_primary(%Color{} = primary) do
    # Create complementary color for secondary
    secondary = Color.complement(primary)

    # Create an accent color (lightened primary)
    accent = Color.lighten(primary, 0.3)

    # Create background (very dark version of primary)
    bg_base = Color.darken(primary, 0.8)
    background = %{
      bg_base
      | r: min(bg_base.r, 40),
        g: min(bg_base.g, 40),
        b: min(bg_base.b, 50)
    }

    # Create foreground (light neutral color)
    fg_base = Color.lighten(bg_base, 0.7)
    foreground = %{
      fg_base
      | r: max(fg_base.r, 200),
        g: max(fg_base.g, 200),
        b: max(fg_base.b, 200)
    }

    %{
      primary: primary,
      secondary: secondary,
      accent: accent,
      background: background,
      foreground: foreground,
      # Additional colors
      primary_light: Color.lighten(primary, 0.2),
      primary_dark: Color.darken(primary, 0.2),
      secondary_light: Color.lighten(secondary, 0.2),
      secondary_dark: Color.darken(secondary, 0.2),
      accent_light: Color.lighten(accent, 0.2),
      accent_dark: Color.darken(accent, 0.2),
      # Neutral colors
      neutral_100: Color.lighten(background, 0.8),
      neutral_200: Color.lighten(background, 0.6),
      neutral_300: Color.lighten(background, 0.4),
      neutral_400: Color.lighten(background, 0.2),
      neutral_500: background,
      neutral_600: Color.darken(background, 0.2),
      neutral_700: Color.darken(background, 0.4),
      neutral_800: Color.darken(background, 0.6),
      neutral_900: Color.darken(background, 0.8)
    }
  end
end
