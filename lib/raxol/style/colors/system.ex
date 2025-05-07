defmodule Raxol.Style.Colors.System do
  @moduledoc """
  Core color system for the Raxol terminal emulator.

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

  alias Raxol.Style.Colors.Utilities
  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Style.Colors.HSL
  alias Raxol.Style.Colors.Color

  defstruct [
    # ... existing code ...
  ]

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
    high_contrast =
      case Process.get(:accessibility_options) do
        nil ->
          Keyword.get(opts, :high_contrast, false)

        accessibility_options ->
          Keyword.get(
            opts,
            :high_contrast,
            accessibility_options[:high_contrast]
          )
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
    EventManager.register_handler(
      :accessibility_high_contrast,
      __MODULE__,
      :handle_high_contrast
    )

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
    high_contrast_colors =
      Keyword.get(opts, :high_contrast_colors) ||
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
  Applies a theme to the color system.

  ## Parameters

  - `theme` - The theme to apply
  - `opts` - Additional options
    - `:high_contrast` - Whether to apply high contrast mode (default: current setting)

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def apply_theme(theme, opts \\ []) do
    # Get high contrast setting from options or current state
    high_contrast =
      Keyword.get(
        opts,
        :high_contrast,
        Process.get(:color_system_high_contrast, false)
      )

    # Update current theme
    Process.put(:color_system_current_theme, theme)

    # Update high contrast state
    Process.put(:color_system_high_contrast, high_contrast)

    # Emit theme change event
    EventManager.dispatch(
      {:theme_changed, %{theme: theme, high_contrast: high_contrast}}
    )

    :ok
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

    EventManager.dispatch({:high_contrast_changed, enabled})
  end

  # Private functions

  defp get_current_theme do
    Process.get(:color_system_current_theme, @default_theme)
  end

  defp get_high_contrast do
    Process.get(:color_system_high_contrast, false)
  end

  defp get_standard_color(theme_name, color_name, variant) do
    case Process.get(:color_system_themes, %{}) do
      %{^theme_name => theme} ->
        # Try variant first, then base color
        Map.get(theme.variants, {color_name, variant}) ||
          Map.get(theme.colors, color_name) ||
          # Fallback to a default color if not found
          default_color(color_name)

      _ ->
        # Theme not found, fallback
        default_color(color_name)
    end
  end

  defp get_high_contrast_color(theme_name, color_name, variant) do
    case Process.get(:color_system_themes, %{}) do
      %{^theme_name => theme} ->
        # Try high contrast variant first, then high contrast base color
        Map.get(theme.variants, {color_name, variant, :high_contrast}) ||
          Map.get(theme.high_contrast_colors, color_name) ||
          # Fallback to standard color if high contrast not defined
          get_standard_color(theme_name, color_name, variant) ||
          # Further fallback
          default_color(color_name)

      _ ->
        # Theme not found, fallback
        default_color(color_name)
    end
  end

  defp generate_high_contrast_colors(colors) do
    # Assume background is either explicitly defined or defaults to black/white
    bg_color_hex = Map.get(colors, :background, "#000000")

    # Correctly handle the return from Color.from_hex for background
    bg_color_struct =
      case Color.from_hex(bg_color_hex) do
        %Color{} = color -> color
        {:error, _} -> Color.from_hex("#000000") # Fallback to black on error
      end

    bg_lightness = HSL.rgb_to_hsl(bg_color_struct.r, bg_color_struct.g, bg_color_struct.b) |> elem(2)

    # Adjust colors for high contrast based on background lightness
    Enum.into(colors, %{}, fn {name, color_hex} ->
      # Correctly handle the return from Color.from_hex in the loop
      case Color.from_hex(color_hex) do
        %Color{} = color_struct -> # Match the struct directly
          # Correctly assign the result from HSL functions
          contrast_color_struct =
            if bg_lightness > 0.5 do
              # Dark background: Darken colors (assuming light text)
              HSL.darken(color_struct, 0.5)
            else
              # Light background: Lighten colors (assuming dark text)
              HSL.lighten(color_struct, 0.5)
            end

          {name, Color.to_hex(contrast_color_struct)} # Convert back to hex for storage

        {:error, _} ->
          # Keep original if invalid
          {name, color_hex}
      end
    end)
  end

  defp default_color(color_name) do
    # Define some basic fallback colors
    case color_name do
      :foreground -> "#FFFFFF"
      :background -> "#000000"
      :primary -> "#0077CC"
      :secondary -> "#6C757D"
      :success -> "#28A745"
      :danger -> "#DC3545"
      :warning -> "#FFC107"
      :info -> "#17A2B8"
      _ -> "#CCCCCC" # Generic fallback
    end
  end

  defp register_standard_themes do
    # Define standard theme
    register_theme(
      :standard,
      %{
        foreground: "#333333",
        background: "#FFFFFF",
        primary: "#007bff",
        secondary: "#6c757d",
        success: "#28a745",
        danger: "#dc3545",
        warning: "#ffc107",
        info: "#17a2b8",
        light: "#f8f9fa",
        dark: "#343a40",
        accent: "#ff6b6b" # Example accent
      }
      # Define variants if needed
    )

    # Define dark theme
    register_theme(
      :dark,
      %{
        foreground: "#e9ecef",
        background: "#212529",
        primary: "#0d6efd", # Slightly brighter blue for dark mode
        secondary: "#6c757d",
        success: "#198754",
        danger: "#dc3545",
        warning: "#ffc107",
        info: "#0dcaf0",
        light: "#f8f9fa", # Often kept light for contrast elements
        dark: "#343a40", # Base dark color
        accent: "#f7a072" # Example accent
      }
    )

    # Define high contrast theme (often black and white with bright accents)
    register_theme(
      :high_contrast,
      %{
        foreground: "#FFFFFF",
        background: "#000000",
        primary: "#FFFF00", # Bright yellow
        secondary: "#00FFFF", # Bright cyan
        success: "#00FF00", # Bright green
        danger: "#FF0000", # Bright red
        warning: "#FF00FF", # Bright magenta
        info: "#00FFFF", # Bright cyan (reused)
        light: "#FFFFFF", # Pure white
        dark: "#000000", # Pure black
        accent: "#FF00FF" # Example accent
      }
    )
  end
end
