defmodule Raxol.Examples.ColorSystemDemo do
  @moduledoc """
  Demonstrates the color system capabilities.
  """
  
  alias Raxol.Style.Colors.{Color, Palette, Theme, Utilities}
  
  @doc """
  Renders a demo of the color system capabilities.
  """
  def render do
    # Create a demo theme
    theme = create_demo_theme()
    
    # Render different views
    [
      render_theme_info(theme),
      render_palette_view(theme.palette),
      render_color_adaptation_view(theme),
      render_accessibility_view(theme)
    ]
    |> Enum.join("\n\n")
  end
  
  defp create_demo_theme do
    # Create a demo palette
    palette = %Palette{
      name: "Demo",
      colors: %{
        primary: Color.from_hex("#0077CC"),
        secondary: Color.from_hex("#00AA00"),
        accent: Color.from_hex("#FF0000"),
        text: Color.from_hex("#333333"),
        background: Color.from_hex("#FFFFFF")
      }
    }
    
    # Create a theme from the palette
    Theme.from_palette(palette)
  end
  
  defp render_theme_info(theme) do
    """
    Theme: #{theme.name}
    Background: #{theme.background}
    Primary: #{theme.ui_colors.primary}
    Secondary: #{theme.ui_colors.secondary}
    Accent: #{theme.ui_colors.accent}
    Text: #{theme.ui_colors.text}
    """
  end
  
  defp render_palette_view(palette) do
    """
    Palette: #{palette.name}
    Colors:
    #{render_color_list(palette.colors)}
    """
  end
  
  defp render_color_list(colors) do
    colors
    |> Enum.map(fn {name, color} ->
      "  #{name}: #{color.hex}"
    end)
    |> Enum.join("\n")
  end
  
  defp render_color_adaptation_view(theme) do
    """
    Color Adaptation:
    Original Theme:
    #{render_theme_info(theme)}
    
    Adapted Theme:
    #{render_theme_info(Raxol.Style.Colors.Adaptive.adapt_theme(theme))}
    """
  end
  
  defp render_accessibility_view(theme) do
    """
    Accessibility:
    Background-Text Contrast: #{check_contrast(theme.background, theme.ui_colors.text)}
    Background-Primary Contrast: #{check_contrast(theme.background, theme.ui_colors.primary)}
    Background-Secondary Contrast: #{check_contrast(theme.background, theme.ui_colors.secondary)}
    Background-Accent Contrast: #{check_contrast(theme.background, theme.ui_colors.accent)}
    """
  end
  
  defp check_contrast(color1, color2) do
    ratio = Utilities.contrast_ratio(color1, color2)
    cond do
      ratio >= 7.0 -> "AAA (#{ratio |> Float.round(2)})"
      ratio >= 4.5 -> "AA (#{ratio |> Float.round(2)})"
      true -> "Insufficient (#{ratio |> Float.round(2)})"
    end
  end
end 