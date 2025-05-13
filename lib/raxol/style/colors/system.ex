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
  alias Raxol.UI.Theming.Theme

  defstruct [
    # ... existing code ...
  ]

  @default_theme :default

  @doc """
  Initialize the color system.

  This sets up the default themes, registers event handlers for accessibility changes,
  and establishes the default color palette.

  ## Options

  * `:theme` - The initial theme to use (default: `:default`)
  * `:high_contrast` - Whether to start in high contrast mode (default: from accessibility settings)

  ## Examples

      iex> ColorSystem.init()
      :ok

      iex> ColorSystem.init(theme: :dark)
      :ok
  """
  def init(opts \\ []) do
    # Get the initial theme (as an atom or struct)
    initial_theme_id = Keyword.get(opts, :theme, @default_theme)
    initial_theme = Theme.get(initial_theme_id)

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

    # Set current theme in process (optional, for compatibility)
    Process.put(:color_system_current_theme, initial_theme.id)
    Process.put(:color_system_high_contrast, high_contrast)

    # Register event handlers for accessibility changes
    EventManager.register_handler(
      :accessibility_high_contrast,
      __MODULE__,
      :handle_high_contrast
    )

    # Apply the initial theme
    apply_theme(initial_theme.id, high_contrast: high_contrast)

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

  * `theme_attrs` - Map of theme attributes

  ## Examples

      iex> ColorSystem.register_theme(%{
      ...>   primary: "#0077CC",
      ...>   secondary: "#00AAFF",
      ...>   background: "#001133",
      ...>   foreground: "#FFFFFF",
      ...>   accent: "#FF9900"
      ...> })
      :ok
  """
  def register_theme(theme_attrs) do
    theme = Theme.new(theme_attrs)
    Theme.register(theme)
  end

  @doc """
  Applies a theme to the color system.

  ## Parameters

  - `theme_id` - The ID of the theme to apply
  - `opts` - Additional options
    - `:high_contrast` - Whether to apply high contrast mode (default: current setting)

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def apply_theme(theme_id, opts \\ []) do
    high_contrast =
      Keyword.get(
        opts,
        :high_contrast,
        Process.get(:color_system_high_contrast, false)
      )

    theme = Theme.get(theme_id)
    Process.put(:color_system_current_theme, theme.id)
    Process.put(:color_system_high_contrast, high_contrast)

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
    apply_theme(current_theme.id, high_contrast: enabled)

    EventManager.dispatch({:high_contrast_changed, enabled})
  end

  # Private functions

  defp get_current_theme do
    theme_id = Process.get(:color_system_current_theme, @default_theme)
    Theme.get(theme_id)
  end

  defp get_high_contrast do
    Process.get(:color_system_high_contrast, false)
  end

  defp get_standard_color(theme, color_name, variant) do
    # Try variant first, then base color
    Map.get(theme.variants, {color_name, variant}) ||
      Map.get(theme.colors, color_name) ||
      default_color(color_name)
  end

  defp get_high_contrast_color(theme, color_name, variant) do
    # Try high contrast variant first, then high contrast base color
    Map.get(theme.variants, {color_name, variant, :high_contrast}) ||
      Map.get(theme.colors, color_name) ||
      get_standard_color(theme, color_name, variant) ||
      default_color(color_name)
  end

  defp generate_high_contrast_colors(colors) do
    # Assume background is either explicitly defined or defaults to black/white
    bg_color_hex = Map.get(colors, :background, "#000000")

    # Correctly handle the return from Color.from_hex for background
    bg_color_struct =
      case Color.from_hex(bg_color_hex) do
        %Color{} = color -> color
        # Fallback to black on error
        {:error, _} -> Color.from_hex("#000000")
      end

    bg_lightness =
      HSL.rgb_to_hsl(bg_color_struct.r, bg_color_struct.g, bg_color_struct.b)
      |> elem(2)

    # Adjust colors for high contrast based on background lightness
    Enum.into(colors, %{}, fn {name, color_hex} ->
      # Correctly handle the return from Color.from_hex in the loop
      case Color.from_hex(color_hex) do
        # Match the struct directly
        %Color{} = color_struct ->
          # Correctly assign the result from HSL functions
          contrast_color_struct =
            if bg_lightness > 0.5 do
              # Dark background: Darken colors (assuming light text)
              HSL.darken(color_struct, 0.5)
            else
              # Light background: Lighten colors (assuming dark text)
              HSL.lighten(color_struct, 0.5)
            end

          # Convert back to hex for storage
          {name, Color.to_hex(contrast_color_struct)}

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
      # Generic fallback
      _ -> "#CCCCCC"
    end
  end

  @spec get_current_theme_name() :: atom() | String.t()
  def get_current_theme_name do
    Process.get(:color_system_current_theme, @default_theme)
  end
end
