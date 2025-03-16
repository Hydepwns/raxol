defmodule Raxol.Style.Colors.System do
  @moduledoc """
  A comprehensive color system for Raxol that integrates with accessibility features.
  
  This module provides a robust color system that:
  - Manages color palettes with semantic naming
  - Provides accessible color alternatives for high contrast mode
  - Supports theme customization
  - Calculates contrast ratios for text/background combinations
  - Automatically adjusts colors for optimal readability
  - Integrates with the accessibility module
  
  ## Usage
  
  ```elixir
  # Initialize the color system
  ColorSystem.init()
  
  # Get a semantic color (will respect accessibility settings)
  color = ColorSystem.get_color(:primary)
  
  # Get a specific color variation
  hover_color = ColorSystem.get_color(:primary, :hover)
  
  # Register a custom theme
  ColorSystem.register_theme(:ocean, %{
    primary: "#0077CC",
    secondary: "#00AAFF",
    background: "#001133",
    foreground: "#FFFFFF",
    accent: "#FF9900"
  })
  
  # Apply a theme
  ColorSystem.apply_theme(:ocean)
  ```
  """
  
  alias Raxol.Style.Colors.Color
  alias Raxol.Style.Colors.Palette
  alias Raxol.Style.Colors.Theme
  alias Raxol.Style.Colors.Utilities
  alias Raxol.Style.Colors.Adaptive
  alias Raxol.Core.Accessibility
  alias Raxol.Core.Events.Manager, as: EventManager
  
  @default_theme :standard
  
  @doc """
  Initialize the color system.
  
  This sets up the default themes, registers event handlers for accessibility changes,
  and establishes the default color palette.
  
  ## Options
  
  * `:theme` - The initial theme to use (default: `:standard`)
  * `:high_contrast` - Whether to start in high contrast mode (default: from accessibility settings)
  
  ## Examples
  
      iex> ColorSystem.init()
      :ok
      
      iex> ColorSystem.init(theme: :dark)
      :ok
  """
  def init(opts \\ []) do
    # Get the initial theme
    initial_theme = Keyword.get(opts, :theme, @default_theme)
    
    # Get high contrast setting from accessibility or options
    high_contrast = case Process.get(:accessibility_options) do
      nil -> Keyword.get(opts, :high_contrast, false)
      accessibility_options -> Keyword.get(opts, :high_contrast, accessibility_options[:high_contrast])
    end
    
    # Initialize color palettes registry
    Process.put(:color_system_palettes, %{})
    
    # Initialize themes registry
    Process.put(:color_system_themes, %{})
    
    # Initialize current theme
    Process.put(:color_system_current_theme, initial_theme)
    
    # Initialize high contrast state
    Process.put(:color_system_high_contrast, high_contrast)
    
    # Register standard themes
    register_standard_themes()
    
    # Register event handlers for accessibility changes
    EventManager.register_handler(:accessibility_high_contrast, __MODULE__, :handle_high_contrast)
    
    # Apply the initial theme
    apply_theme(initial_theme, high_contrast: high_contrast)
    
    :ok
  end
  
  @doc """
  Get a color from the current theme.
  
  This function respects the current accessibility settings, automatically
  returning high-contrast alternatives when needed.
  
  ## Parameters
  
  * `color_name` - The semantic name of the color (e.g., `:primary`, `:error`)
  * `variant` - The variant of the color (e.g., `:base`, `:hover`, `:active`) (default: `:base`)
  
  ## Examples
  
      iex> ColorSystem.get_color(:primary)
      "#0077CC"
      
      iex> ColorSystem.get_color(:primary, :hover)
      "#0088DD"
  """
  def get_color(color_name, variant \\ :base) do
    # Get the current theme
    current_theme = get_current_theme()
    
    # Get high contrast setting
    high_contrast = get_high_contrast()
    
    # Get color from theme
    if high_contrast do
      get_high_contrast_color(current_theme, color_name, variant)
    else
      get_standard_color(current_theme, color_name, variant)
    end
  end
  
  @doc """
  Register a custom theme.
  
  ## Parameters
  
  * `theme_name` - Unique identifier for the theme
  * `colors` - Map of color names to color values
  * `opts` - Additional options
  
  ## Options
  
  * `:high_contrast_colors` - Map of high contrast alternatives
  * `:variants` - Map of color variants (hover, active, etc.)
  
  ## Examples
  
      iex> ColorSystem.register_theme(:ocean, %{
      ...>   primary: "#0077CC",
      ...>   secondary: "#00AAFF",
      ...>   background: "#001133",
      ...>   foreground: "#FFFFFF",
      ...>   accent: "#FF9900"
      ...> })
      :ok
  """
  def register_theme(theme_name, colors, opts \\ []) do
    # Get high contrast colors or generate them automatically
    high_contrast_colors = Keyword.get(opts, :high_contrast_colors) || 
                          generate_high_contrast_colors(colors)
    
    # Get variants or use defaults
    variants = Keyword.get(opts, :variants) || %{}
    
    # Create theme record
    theme = %{
      colors: colors,
      high_contrast_colors: high_contrast_colors,
      variants: variants
    }
    
    # Update themes registry
    themes = Process.get(:color_system_themes, %{})
    updated_themes = Map.put(themes, theme_name, theme)
    Process.put(:color_system_themes, updated_themes)
    
    :ok
  end
  
  @doc """
  Apply a theme as the current theme.
  
  ## Parameters
  
  * `theme_name` - The name of the theme to apply
  * `opts` - Additional options
  
  ## Options
  
  * `:high_contrast` - Whether to apply high contrast version (default: current setting)
  
  ## Examples
  
      iex> ColorSystem.apply_theme(:dark)
      :ok
      
      iex> ColorSystem.apply_theme(:ocean, high_contrast: true)
      :ok
  """
  def apply_theme(theme_name, opts \\ []) do
    # Check if theme exists
    themes = Process.get(:color_system_themes, %{})
    
    if not Map.has_key?(themes, theme_name) do
      if theme_name != @default_theme do
        # Fall back to default theme if requested theme doesn't exist
        apply_theme(@default_theme, opts)
      else
        {:error, :theme_not_found}
      end
    else
      # Get high contrast setting
      current_high_contrast = Process.get(:color_system_high_contrast, false)
      high_contrast = Keyword.get(opts, :high_contrast, current_high_contrast)
      
      # Store current theme
      Process.put(:color_system_current_theme, theme_name)
      Process.put(:color_system_high_contrast, high_contrast)
      
      # Broadcast theme change event
      EventManager.broadcast({:theme_changed, theme_name, high_contrast})
      
      :ok
    end
  end
  
  @doc """
  Handle high contrast mode changes from the accessibility module.
  """
  def handle_high_contrast({:accessibility_high_contrast, enabled}) do
    # Update high contrast setting
    Process.put(:color_system_high_contrast, enabled)
    
    # Re-apply current theme with new high contrast setting
    current_theme = get_current_theme()
    apply_theme(current_theme, high_contrast: enabled)
    
    :ok
  end
  
  # Private functions
  
  defp get_current_theme do
    Process.get(:color_system_current_theme, @default_theme)
  end
  
  defp get_high_contrast do
    Process.get(:color_system_high_contrast, false)
  end
  
  defp get_standard_color(theme_name, color_name, variant) do
    themes = Process.get(:color_system_themes, %{})
    
    case Map.get(themes, theme_name) do
      nil -> "#000000" # Default to black if theme not found
      theme ->
        base_color = get_in(theme, [:colors, color_name])
        
        if variant == :base do
          base_color
        else
          # Get variant-specific color if available
          variant_color = get_in(theme, [:variants, color_name, variant])
          
          if variant_color do
            variant_color
          else
            # Generate variant color algorithmically
            generate_variant_color(base_color, variant)
          end
        end
    end
  end
  
  defp get_high_contrast_color(theme_name, color_name, variant) do
    themes = Process.get(:color_system_themes, %{})
    
    case Map.get(themes, theme_name) do
      nil -> "#FFFFFF" # Default to white if theme not found
      theme ->
        base_color = get_in(theme, [:high_contrast_colors, color_name])
        
        if variant == :base do
          base_color
        else
          # Get variant-specific high contrast color if available
          variant_color = get_in(theme, [:variants, String.to_atom("high_contrast_#{color_name}"), variant])
          
          if variant_color do
            variant_color
          else
            # Generate high contrast variant algorithmically
            generate_high_contrast_variant(base_color, variant)
          end
        end
    end
  end
  
  defp generate_variant_color(base_color, :hover) do
    # Make color slightly lighter
    Utilities.lighten(base_color, 0.1)
  end
  
  defp generate_variant_color(base_color, :active) do
    # Make color slightly darker
    Utilities.darken(base_color, 0.1)
  end
  
  defp generate_variant_color(base_color, :focus) do
    # Make color slightly more saturated
    Utilities.saturate(base_color, 0.1)
  end
  
  defp generate_variant_color(base_color, :disabled) do
    # Make color desaturated and lighter
    base_color
    |> Utilities.desaturate(0.3)
    |> Utilities.lighten(0.2)
  end
  
  defp generate_variant_color(base_color, _) do
    # Default to base color for unknown variants
    base_color
  end
  
  defp generate_high_contrast_variant(base_color, variant) do
    # For high contrast, we want more extreme differences between states
    case variant do
      :hover -> Utilities.lighten(base_color, 0.2)
      :active -> Utilities.darken(base_color, 0.2)
      :focus -> Utilities.saturate(base_color, 0.2)
      :disabled -> Utilities.desaturate(base_color, 0.5)
      _ -> base_color
    end
  end
  
  defp generate_high_contrast_colors(colors) do
    # Generate high contrast alternatives for each color
    Enum.reduce(colors, %{}, fn {name, color}, acc ->
      high_contrast_color = make_high_contrast(color)
      Map.put(acc, name, high_contrast_color)
    end)
  end
  
  defp make_high_contrast(color) do
    # Determine if color is dark or light
    is_dark = Utilities.is_dark?(color)
    
    if is_dark do
      # If color is dark, make it much lighter for high contrast
      Utilities.lighten(color, 0.5)
    else
      # If color is light, make it much darker for high contrast
      Utilities.darken(color, 0.5)
    end
  end
  
  defp register_standard_themes do
    # Register standard theme
    register_theme(:standard, %{
      primary: "#4B9CD3",
      secondary: "#5FBCD3",
      success: "#28A745",
      warning: "#FFC107",
      error: "#DC3545",
      info: "#17A2B8",
      background: "#FFFFFF",
      foreground: "#212529",
      border: "#DEE2E6",
      accent: "#FF5722"
    })
    
    # Register dark theme
    register_theme(:dark, %{
      primary: "#4B9CD3",
      secondary: "#5FBCD3",
      success: "#28A745",
      warning: "#FFC107",
      error: "#DC3545",
      info: "#17A2B8",
      background: "#121212",
      foreground: "#E1E1E1",
      border: "#333333",
      accent: "#FF5722"
    })
    
    # Register high contrast theme
    register_theme(:high_contrast, %{
      primary: "#FFFFFF",
      secondary: "#FFFF00",
      success: "#00FF00",
      warning: "#FFFF00",
      error: "#FF0000",
      info: "#00FFFF",
      background: "#000000",
      foreground: "#FFFFFF",
      border: "#FFFFFF",
      accent: "#FF00FF"
    })
  end
end 