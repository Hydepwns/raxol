defmodule Raxol.Style.Colors.PaletteManager do
  @moduledoc """
  Manages color palettes for the Raxol terminal emulator.

  This module provides functionality to create, store, and retrieve color palettes.
  It works with the ColorSystem to provide a comprehensive color management solution
  that respects user preferences and accessibility settings.

  ## Features

  - Create and manage named color palettes
  - Generate color scales (light to dark variations)
  - Create accessible color combinations
  - Calculate contrast ratios
  - Support for user preference persistence
  - Integration with the accessibility system

  ## Usage

  ```elixir
  # Initialize the palette manager
  PaletteManager.init()

  # Register a custom palette
  PaletteManager.register_palette(:brand, %{
    main: "#0077CC",
    accent: "#FF5722",
    neutral: "#F0F0F0"
  })

  # Generate a color scale
  scale = PaletteManager.generate_scale("#0077CC", 9)
  ```
  """

  alias Raxol.Style.Colors.Utilities
  alias Raxol.Style.Colors.Color

  defstruct palettes: %{},
            scales: %{},
            user_preferences: %{}

  @doc """
  Initialize the palette manager.

  This sets up the necessary state for managing color palettes and
  integrates with the ColorSystem.

  ## Examples

      iex> PaletteManager.init()
      :ok
  """
  def init do
    # Initialize palettes registry
    Process.put(:palette_manager_palettes, %{})

    # Initialize palette scales registry
    Process.put(:palette_manager_scales, %{})

    # Initialize user preferences
    Process.put(:palette_manager_user_preferences, %{})

    # Register default palettes
    register_default_palettes()

    :ok
  end

  @doc """
  Register a color palette.

  ## Parameters

  * `palette_name` - Unique identifier for the palette
  * `colors` - Map of color names to color values
  * `opts` - Additional options

  ## Options

  * `:description` - Description of the palette
  * `:category` - Category for organizing palettes
  * `:tags` - List of tags for filtering
  * `:accessible` - Whether the palette is designed for accessibility

  ## Examples

      iex> PaletteManager.register_palette(:ocean, %{
      ...>   main: "#0077CC",
      ...>   accent: "#00AAFF",
      ...>   background: "#F0F7FF"
      ...> })
      :ok
  """
  def register_palette(palette_name, colors, opts \\ []) do
    # Create palette record
    palette = %{
      colors: colors,
      description: Keyword.get(opts, :description, ""),
      category: Keyword.get(opts, :category, :user),
      tags: Keyword.get(opts, :tags, []),
      accessible: Keyword.get(opts, :accessible, false),
      created_at: DateTime.utc_now()
    }

    # Update palettes registry
    palettes = Process.get(:palette_manager_palettes, %{})
    updated_palettes = Map.put(palettes, palette_name, palette)
    Process.put(:palette_manager_palettes, updated_palettes)

    :ok
  end

  @doc """
  Generate a color scale from a base color.

  Creates a series of color variations from light to dark based on the given color.

  ## Parameters

  * `base_color` - The starting color (hex string like "#0077CC")
  * `steps` - The number of steps in the scale (default: 9)
  * `opts` - Additional options

  ## Options

  * `:name` - Name to identify this scale
  * `:lightness_range` - Tuple of {min_lightness, max_lightness} (default: {0.1, 0.9})
  * `:saturation_adjust` - Adjustment to saturation for each step (default: 0.05)

  ## Examples

      iex> PaletteManager.generate_scale("#0077CC", 9)
      [
        "#E6F0FA", "#CCE0F5", "#B3D1F0", "#99C2EB",
        "#80B3E6", "#66A3E0", "#4D94DB", "#3385D6", "#0077CC"
      ]
  """
  def generate_scale(base_color, steps \\ 9, opts \\ []) do
    # Default range of lightness from light to dark
    {min_lightness, max_lightness} =
      Keyword.get(opts, :lightness_range, {0.1, 0.9})

    # Get saturation adjustment (slightly more saturated for midtones)
    saturation_adjust = Keyword.get(opts, :saturation_adjust, 0.05)

    # Convert base color to HSL to get starting values
    {_base_h, base_s, base_l} =
      Utilities.rgb_to_hsl(
        Color.from_hex(base_color).r,
        Color.from_hex(base_color).g,
        Color.from_hex(base_color).b
      )

    # Calculate lightness step size
    lightness_step = (max_lightness - min_lightness) / (steps - 1)

    # Generate colors
    scale =
      for i <- 0..(steps - 1) do
        # Calculate target lightness for this step (start from lightest)
        target_lightness = max_lightness - i * lightness_step
        lightness_diff = target_lightness - base_l

        # Calculate target saturation (parabolic curve, peaked in middle)
        target_saturation_factor =
          1.0 +
            saturation_adjust *
              (1.0 - :math.pow(2.0 * (i / (steps - 1)) - 1.0, 2))

        target_saturation = base_s * target_saturation_factor
        saturation_diff = target_saturation - base_s

        # Adjust lightness
        adjusted_lightness_color =
          cond do
            lightness_diff > 0 ->
              Utilities.lighten(base_color, lightness_diff)

            lightness_diff < 0 ->
              Utilities.darken(base_color, abs(lightness_diff))

            true ->
              base_color
          end

        # Adjust saturation on the lightness-adjusted color
        final_color =
          cond do
            saturation_diff > 0 ->
              Utilities.saturate(adjusted_lightness_color, saturation_diff)

            saturation_diff < 0 ->
              Utilities.desaturate(
                adjusted_lightness_color,
                abs(saturation_diff)
              )

            true ->
              adjusted_lightness_color
          end

        final_color
      end

    # Store the scale if a name was provided
    if name = Keyword.get(opts, :name) do
      scales = Process.get(:palette_manager_scales, %{})
      updated_scales = Map.put(scales, name, scale)
      Process.put(:palette_manager_scales, updated_scales)
    end

    scale
  end

  @doc """
  Get a color from a registered palette.

  ## Parameters

  * `palette_name` - The name of the palette
  * `color_name` - The name of the color within the palette

  ## Examples

      iex> PaletteManager.get_color(:ocean, :main)
      "#0077CC"
  """
  def get_color(palette_name, color_name) do
    palettes = Process.get(:palette_manager_palettes, %{})

    case Map.get(palettes, palette_name) do
      nil -> nil
      palette -> get_in(palette, [:colors, color_name])
    end
  end

  @doc """
  Get all registered palettes.

  ## Options

  * `:category` - Filter palettes by category
  * `:tags` - Filter palettes by tags
  * `:accessible` - Filter by accessibility

  ## Examples

      iex> PaletteManager.get_palettes()
      %{ocean: %{colors: %{main: "#0077CC", ...}, ...}, ...}

      iex> PaletteManager.get_palettes(category: :brand)
      %{brand: %{colors: %{main: "#FF5722", ...}, ...}}
  """
  def get_palettes(opts \\ []) do
    palettes = Process.get(:palette_manager_palettes, %{})

    # Apply filters
    Enum.reduce(opts, palettes, fn {key, value}, acc ->
      case key do
        :category ->
          Map.filter(acc, fn {_, palette} -> palette.category == value end)

        :tags ->
          Map.filter(acc, fn {_, palette} ->
            Enum.any?(value, &Enum.member?(palette.tags, &1))
          end)

        :accessible ->
          Map.filter(acc, fn {_, palette} -> palette.accessible == value end)

        _ ->
          acc
      end
    end)
  end

  @doc """
  Save user color preferences.

  ## Parameters

  * `user_id` - Identifier for the user
  * `preferences` - Map of color preferences

  ## Examples

      iex> PaletteManager.save_user_preferences("user123", %{
      ...>   theme: :dark,
      ...>   accent_color: "#FF5722"
      ...> })
      :ok
  """
  def save_user_preferences(user_id, preferences) do
    # Get current preferences
    user_preferences = Process.get(:palette_manager_user_preferences, %{})

    # Update preferences for user
    updated_preferences = Map.put(user_preferences, user_id, preferences)
    Process.put(:palette_manager_user_preferences, updated_preferences)

    :ok
  end

  @doc """
  Get user color preferences.

  ## Parameters

  * `user_id` - Identifier for the user

  ## Examples

      iex> PaletteManager.get_user_preferences("user123")
      %{theme: :dark, accent_color: "#FF5722"}
  """
  def get_user_preferences(user_id) do
    # Get current preferences
    user_preferences = Process.get(:palette_manager_user_preferences, %{})

    # Get preferences for user
    Map.get(user_preferences, user_id, %{})
  end

  @doc """
  Suggest an accessible color alternative for a given color.

  ## Parameters

  * `color` - The original color
  * `background` - The background color the text will appear on
  * `level` - The WCAG level to achieve (`:aa` or `:aaa`) (default: `:aa`)

  ## Examples

      iex> PaletteManager.suggest_accessible_color("#777777", "#FFFFFF")
      "#595959"
  """
  def suggest_accessible_color(color, background, level \\ :aa) do
    # Get current contrast ratio
    ratio = Utilities.contrast_ratio(color, background)

    # Determine minimum required ratio
    min_ratio = if level == :aa, do: 4.5, else: 7.0

    # If already sufficient, return original color
    if ratio >= min_ratio do
      color
    else
      # Determine if we need to lighten or darken
      bg_luminance = Utilities.relative_luminance(background)

      if bg_luminance > 0.5 do
        # Dark text on light background
        Utilities.darken_until_contrast(color, background, min_ratio)
      else
        # Light text on dark background
        Utilities.lighten_until_contrast(color, background, min_ratio)
      end
    end
  end

  # Private functions

  defp register_default_palettes do
    # Register default palettes

    # Primary palette for common UI elements
    register_palette(
      :primary,
      %{
        main: "#4B9CD3",
        light: "#73B4E0",
        dark: "#2D7FB6",
        contrast: "#FFFFFF"
      },
      description: "Primary UI colors",
      category: :system,
      accessible: true
    )

    # Neutral palette for backgrounds, borders, etc.
    register_palette(
      :neutral,
      %{
        main: "#808080",
        light: "#F0F0F0",
        lighter: "#F8F8F8",
        dark: "#404040",
        darker: "#202020",
        contrast: "#FFFFFF"
      },
      description: "Neutral UI colors",
      category: :system,
      accessible: true
    )

    # Semantic colors for status and feedback
    register_palette(
      :semantic,
      %{
        success: "#28A745",
        warning: "#FFC107",
        error: "#DC3545",
        info: "#17A2B8"
      },
      description: "Semantic status colors",
      category: :system,
      accessible: true
    )
  end
end
