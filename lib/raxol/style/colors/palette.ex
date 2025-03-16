defmodule Raxol.Style.Colors.Palette do
  @moduledoc """
  Manages collections of related colors as palettes.
  Provides standard palettes and custom palette creation.
  
  ## Examples
  
  ```elixir
  # Using standard palettes
  palette = Raxol.Style.Colors.Palette.standard_16()
  solarized = Raxol.Style.Colors.Palette.solarized()
  
  # Creating a custom palette from a base color
  base_color = Raxol.Style.Colors.Color.from_hex("#4285F4")  # Google Blue
  custom_palette = Raxol.Style.Colors.Palette.from_base_color(base_color)
  
  # Accessing colors from a palette
  primary = Raxol.Style.Colors.Palette.get_color(palette, :primary)
  background = Raxol.Style.Colors.Palette.get_color(palette, :background)
  ```
  """
  
  alias Raxol.Style.Colors.Color
  
  defstruct [
    :name,
    :colors,          # Map of color names to Color structs
    :primary,         # Primary color reference
    :secondary,       # Secondary color reference
    :accent,          # Accent color references
    :background,      # Background color
    :foreground       # Foreground color
  ]
  
  @type t :: %__MODULE__{
    name: String.t(),
    colors: %{optional(atom()) => Color.t()},
    primary: atom(),
    secondary: atom(),
    accent: atom() | [atom()],
    background: atom(),
    foreground: atom()
  }
  
  @doc """
  Creates a standard 16-color ANSI palette.
  
  ## Examples
  
      iex> palette = Raxol.Style.Colors.Palette.standard_16()
      iex> Map.keys(palette.colors) |> length()
      16
  """
  def standard_16 do
    colors = %{
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
      bright_white: Color.from_ansi(15)
    }
    
    %__MODULE__{
      name: "ANSI 16",
      colors: colors,
      primary: :blue,
      secondary: :green,
      accent: :yellow,
      background: :black,
      foreground: :white
    }
  end
  
  @doc """
  Creates an ANSI 256 color palette.
  Currently this is a placeholder that returns the standard 16 colors.
  
  ## Examples
  
      iex> palette = Raxol.Style.Colors.Palette.ansi_256()
      iex> palette.name
      "ANSI 256"
  """
  def ansi_256 do
    # For now, we'll just return the standard 16 colors
    # This should be expanded to include the full 256 color set
    palette = standard_16()
    %{palette | name: "ANSI 256"}
  end
  
  @doc """
  Creates a Solarized color palette.
  
  ## Examples
  
      iex> palette = Raxol.Style.Colors.Palette.solarized()
      iex> palette.name
      "Solarized"
  """
  def solarized do
    colors = %{
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
      green: Color.from_hex("#859900")
    }
    
    %__MODULE__{
      name: "Solarized",
      colors: colors,
      primary: :blue,
      secondary: :green,
      accent: :yellow,
      background: :base03,
      foreground: :base0
    }
  end
  
  @doc """
  Creates a Nord color palette.
  
  ## Examples
  
      iex> palette = Raxol.Style.Colors.Palette.nord()
      iex> palette.name
      "Nord"
  """
  def nord do
    colors = %{
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
      nord15: Color.from_hex("#b48ead")
    }
    
    %__MODULE__{
      name: "Nord",
      colors: colors,
      primary: :nord10,
      secondary: :nord8,
      accent: :nord13,
      background: :nord0,
      foreground: :nord4
    }
  end
  
  @doc """
  Creates a Dracula color palette.
  
  ## Examples
  
      iex> palette = Raxol.Style.Colors.Palette.dracula()
      iex> palette.name
      "Dracula"
  """
  def dracula do
    colors = %{
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
      yellow: Color.from_hex("#f1fa8c")
    }
    
    %__MODULE__{
      name: "Dracula",
      colors: colors,
      primary: :purple,
      secondary: :cyan,
      accent: :pink,
      background: :background,
      foreground: :foreground
    }
  end
  
  @doc """
  Creates a new palette from a base color.
  
  ## Examples
  
      iex> base = Raxol.Style.Colors.Color.from_hex("#4285F4")
      iex> palette = Raxol.Style.Colors.Palette.from_base_color(base)
      iex> palette.name
      "Custom"
  """
  def from_base_color(%Color{} = base_color, name \\ "Custom") do
    # Create a palette with primary, secondary, and accent colors
    # based on color theory relationships
    primary = base_color
    
    # Create complementary color for secondary
    secondary = Color.complement(primary)
    
    # Create an accent color (lightened primary)
    accent = Color.lighten(primary, 0.3)
    
    # Create background (very dark version of primary)
    bg_base = Color.darken(primary, 0.8)
    background = %{bg_base | r: min(bg_base.r, 40), g: min(bg_base.g, 40), b: min(bg_base.b, 50)}
    
    # Create foreground (light neutral color)
    fg_base = Color.lighten(bg_base, 0.7)
    foreground = %{fg_base | r: max(fg_base.r, 200), g: max(fg_base.g, 200), b: max(fg_base.b, 200)}
    
    colors = %{
      primary: primary,
      secondary: secondary,
      accent: accent,
      background: background,
      foreground: foreground,
      
      # Additional colors for the palette
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
    
    %__MODULE__{
      name: name,
      colors: colors,
      primary: :primary,
      secondary: :secondary,
      accent: :accent,
      background: :background,
      foreground: :foreground
    }
  end
  
  @doc """
  Creates a complementary palette based on a base color.
  
  ## Examples
  
      iex> base = Raxol.Style.Colors.Color.from_hex("#4285F4")
      iex> palette = Raxol.Style.Colors.Palette.complementary(base)
      iex> palette.name
      "Complementary"
  """
  def complementary(%Color{} = base_color) do
    palette = from_base_color(base_color, "Complementary")
    complement = Color.complement(base_color)
    
    # Add more complementary-specific colors
    colors = Map.merge(palette.colors, %{
      complement: complement,
      complement_light: Color.lighten(complement, 0.2),
      complement_dark: Color.darken(complement, 0.2)
    })
    
    %{palette | colors: colors, secondary: :complement}
  end
  
  @doc """
  Creates a triadic color palette based on a base color.
  
  ## Examples
  
      iex> base = Raxol.Style.Colors.Color.from_hex("#4285F4")
      iex> palette = Raxol.Style.Colors.Palette.triadic(base)
      iex> palette.name
      "Triadic"
  """
  def triadic(%Color{} = base_color) do
    palette = from_base_color(base_color, "Triadic")
    
    # Create triadic colors (120 degrees apart on the color wheel)
    # For simplicity, we'll simulate this with specific color manipulations
    # In a full implementation, you would use HSL conversion and rotate the hue
    triadic1 = Color.complement(base_color)
    triadic2 = %Color{
      r: triadic1.b,
      g: triadic1.r,
      b: triadic1.g,
      hex: Color.to_hex(%Color{r: triadic1.b, g: triadic1.r, b: triadic1.g}),
      ansi_code: nil,
      name: nil
    }
    
    # Add triadic colors to the palette
    colors = Map.merge(palette.colors, %{
      triadic1: triadic1,
      triadic2: triadic2,
      triadic1_light: Color.lighten(triadic1, 0.2),
      triadic2_light: Color.lighten(triadic2, 0.2),
      triadic1_dark: Color.darken(triadic1, 0.2),
      triadic2_dark: Color.darken(triadic2, 0.2)
    })
    
    %{palette | colors: colors, secondary: :triadic1, accent: :triadic2}
  end
  
  @doc """
  Creates an analogous color palette based on a base color.
  
  ## Examples
  
      iex> base = Raxol.Style.Colors.Color.from_hex("#4285F4")
      iex> palette = Raxol.Style.Colors.Palette.analogous(base)
      iex> palette.name
      "Analogous"
  """
  def analogous(%Color{} = base_color) do
    palette = from_base_color(base_color, "Analogous")
    
    # Create analogous colors (next to each other on the color wheel)
    # For simplicity, we'll simulate this with specific color manipulations
    # In a full implementation, you would use HSL conversion and rotate the hue
    analogous1 = %Color{
      r: trunc(base_color.r * 0.8),
      g: trunc(base_color.g * 1.1),
      b: trunc(min(base_color.b * 1.3, 255)),
      hex: "",  # Will be computed below
      ansi_code: nil,
      name: nil
    }
    analogous1 = %{analogous1 | hex: Color.to_hex(analogous1)}
    
    analogous2 = %Color{
      r: trunc(min(base_color.r * 1.3, 255)),
      g: trunc(base_color.g * 0.8),
      b: trunc(base_color.b * 1.1),
      hex: "",  # Will be computed below
      ansi_code: nil,
      name: nil
    }
    analogous2 = %{analogous2 | hex: Color.to_hex(analogous2)}
    
    # Add analogous colors to the palette
    colors = Map.merge(palette.colors, %{
      analogous1: analogous1,
      analogous2: analogous2,
      analogous1_light: Color.lighten(analogous1, 0.2),
      analogous2_light: Color.lighten(analogous2, 0.2),
      analogous1_dark: Color.darken(analogous1, 0.2),
      analogous2_dark: Color.darken(analogous2, 0.2)
    })
    
    %{palette | colors: colors, secondary: :analogous1, accent: :analogous2}
  end
  
  @doc """
  Creates a monochromatic color palette with specified number of steps.
  
  ## Examples
  
      iex> base = Raxol.Style.Colors.Color.from_hex("#4285F4")
      iex> palette = Raxol.Style.Colors.Palette.monochromatic(base, 5)
      iex> palette.name
      "Monochromatic"
  """
  def monochromatic(%Color{} = base_color, steps \\ 5) when steps > 1 do
    palette = from_base_color(base_color, "Monochromatic")
    
    # Create a set of colors with the same hue but different lightness
    mono_colors = for i <- 0..(steps - 1) do
      # Calculate amount for evenly distributed lightness values
      amount = i / (steps - 1)
      # Create darker to lighter variants
      color = Color.lighten(Color.darken(base_color, 0.9), amount * 0.9)
      {String.to_atom("mono_#{i}"), color}
    end
    
    # Add monochromatic colors to the palette
    mono_map = Map.new(mono_colors)
    colors = Map.merge(palette.colors, mono_map)
    
    # Find middle tone for primary and lightest for accent
    middle_index = div(steps, 2)
    accent_index = steps - 1
    
    %{palette | 
      colors: colors, 
      primary: String.to_atom("mono_#{middle_index}"),
      accent: String.to_atom("mono_#{accent_index}")
    }
  end
  
  @doc """
  Gets a color from a palette by name.
  
  ## Examples
  
      iex> palette = Raxol.Style.Colors.Palette.standard_16()
      iex> color = Raxol.Style.Colors.Palette.get_color(palette, :red)
      iex> color.hex
      "#800000"
  """
  def get_color(%__MODULE__{colors: colors}, name) when is_atom(name) do
    Map.get(colors, name)
  end
  
  def get_color(%__MODULE__{colors: colors}, name) when is_binary(name) do
    Map.get(colors, String.to_atom(name))
  end
  
  @doc """
  Adds a color to a palette with the given name.
  
  ## Examples
  
      iex> palette = Raxol.Style.Colors.Palette.standard_16()
      iex> color = Raxol.Style.Colors.Color.from_hex("#FF00FF")
      iex> updated = Raxol.Style.Colors.Palette.add_color(palette, :hot_pink, color)
      iex> Raxol.Style.Colors.Palette.get_color(updated, :hot_pink) == color
      true
  """
  def add_color(%__MODULE__{} = palette, name, %Color{} = color) when is_atom(name) do
    %{palette | colors: Map.put(palette.colors, name, color)}
  end
  
  def add_color(%__MODULE__{} = palette, name, %Color{} = color) when is_binary(name) do
    add_color(palette, String.to_atom(name), color)
  end
  
  @doc """
  Removes a color from a palette by name.
  
  ## Examples
  
      iex> palette = Raxol.Style.Colors.Palette.standard_16()
      iex> updated = Raxol.Style.Colors.Palette.remove_color(palette, :red)
      iex> Raxol.Style.Colors.Palette.get_color(updated, :red)
      nil
  """
  def remove_color(%__MODULE__{} = palette, name) when is_atom(name) do
    %{palette | colors: Map.delete(palette.colors, name)}
  end
  
  def remove_color(%__MODULE__{} = palette, name) when is_binary(name) do
    remove_color(palette, String.to_atom(name))
  end
  
  @doc """
  Merges two palettes, with the second palette's colors taking precedence.
  
  ## Examples
  
      iex> p1 = Raxol.Style.Colors.Palette.standard_16()
      iex> p2 = Raxol.Style.Colors.Palette.solarized()
      iex> merged = Raxol.Style.Colors.Palette.merge_palettes(p1, p2)
      iex> merged.name
      "ANSI 16 + Solarized"
  """
  def merge_palettes(%__MODULE__{} = palette1, %__MODULE__{} = palette2) do
    %{palette1 | 
      name: "#{palette1.name} + #{palette2.name}",
      colors: Map.merge(palette1.colors, palette2.colors),
      primary: palette2.primary,
      secondary: palette2.secondary,
      accent: palette2.accent,
      background: palette2.background,
      foreground: palette2.foreground
    }
  end
end 