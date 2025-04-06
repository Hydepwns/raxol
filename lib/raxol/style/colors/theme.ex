defmodule Raxol.Style.Colors.Theme do
  @moduledoc """
  Manages color themes for the Raxol application.

  This module provides functionality for:
  - Creating and managing themes
  - Applying themes to the application
  - Accessing theme colors
  - Updating theme colors
  """

  alias Raxol.Style.Colors.{System, Persistence}

  @type color :: %{
    r: integer(),
    g: integer(),
    b: integer(),
    a: float()
  }

  @derive Jason.Encoder
  defstruct name: "Default",
            palette: %{},
            ui_mappings: %{},
            dark_mode: false,
            high_contrast: false

  @type theme :: %__MODULE__{
    name: String.t(),
    palette: %{String.t() => color()},
    ui_mappings: %{atom() => String.t()},
    dark_mode: boolean(),
    high_contrast: boolean()
  }

  @doc """
  Creates a standard theme with default colors.

  ## Returns

  - A new theme with default colors
  """
  def standard_theme do
    %__MODULE__{
      name: "Default",
      palette: %{
        "primary" => %{r: 0, g: 119, b: 204, a: 1.0},
        "secondary" => %{r: 102, g: 102, b: 102, a: 1.0},
        "accent" => %{r: 255, g: 153, b: 0, a: 1.0},
        "background" => %{r: 255, g: 255, b: 255, a: 1.0},
        "surface" => %{r: 245, g: 245, b: 245, a: 1.0},
        "error" => %{r: 204, g: 0, b: 0, a: 1.0},
        "success" => %{r: 0, g: 153, b: 0, a: 1.0},
        "warning" => %{r: 255, g: 153, b: 0, a: 1.0},
        "info" => %{r: 0, g: 153, b: 204, a: 1.0}
      },
      ui_mappings: %{
        app_background: "background",
        surface_background: "surface",
        primary_button: "primary",
        secondary_button: "secondary",
        accent_button: "accent",
        error_text: "error",
        success_text: "success",
        warning_text: "warning",
        info_text: "info"
      },
      dark_mode: false,
      high_contrast: false
    }
  end

  @doc """
  Creates a new theme from a given palette map and optional name.

  Uses default UI mappings.

  ## Parameters

  - `palette` - A map representing the color palette (e.g., %{"primary" => %{r: 0, g: 119, b: 204, a: 1.0}, ...})
  - `name` (optional) - The name for the theme. Defaults to "Custom".

  ## Returns

  - A new theme struct.

  ## Examples

      iex> nord_palette = Raxol.Style.Colors.Palette.nord()
      iex> theme = Raxol.Style.Colors.Theme.from_palette(nord_palette, "Nord Theme")
      iex> theme.name
      "Nord Theme"
      iex> theme.palette["polar_night_1"]
      %{r: 46, g: 52, b: 64, a: 1.0}
  """
  @spec from_palette(map(), String.t()) :: theme()
  def from_palette(palette, name \\ "Custom") when is_map(palette) do
    # Use the standard theme to get default UI mappings and structure
    default_theme = standard_theme()
    %__MODULE__{
      name: name,
      palette: palette, # Use the provided palette
      ui_mappings: default_theme.ui_mappings, # Keep default mappings
      dark_mode: default_theme.dark_mode, # Default dark mode setting
      high_contrast: default_theme.high_contrast # Default contrast setting
    }
  end

  @doc """
  Applies a theme to the application.

  ## Parameters

  - `theme` - The theme to apply

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def apply_theme(theme) do
    # Save theme for persistence
    case Persistence.save_theme(theme) do
      :ok ->
        # Update color system
        System.apply_theme(theme)
        :ok
      error ->
        error
    end
  end

  @doc """
  Gets a UI color from a theme.

  ## Parameters

  - `theme` - The theme to get the color from
  - `element` - The UI element to get the color for

  ## Returns

  - The color for the specified UI element
  """
  def get_ui_color(theme, element) do
    case Map.get(theme.ui_mappings, element) do
      nil ->
        nil
      color_name ->
        Map.get(theme.palette, color_name)
    end
  end

  @doc """
  Gets all UI colors from a theme.

  ## Parameters

  - `theme` - The theme to get the colors from

  ## Returns

  - A map of UI elements to their colors
  """
  def get_all_ui_colors(theme) do
    Enum.map(theme.ui_mappings, fn {element, color_name} ->
      {element, Map.get(theme.palette, color_name)}
    end)
    |> Map.new()
  end

  @doc """
  Updates UI colors in a theme.

  ## Parameters

  - `theme` - The theme to update
  - `colors` - A map of UI elements to their new colors

  ## Returns

  - The updated theme
  """
  def update_ui_colors(theme, colors) do
    # Update palette with new colors
    new_palette = Enum.reduce(colors, theme.palette, fn {element, color}, palette ->
      case Map.get(theme.ui_mappings, element) do
        nil ->
          palette
        color_name ->
          Map.put(palette, color_name, color)
      end
    end)

    # Return updated theme
    %{theme | palette: new_palette}
  end

  @doc """
  Creates a dark mode version of a theme.

  ## Parameters

  - `theme` - The theme to create a dark mode version of

  ## Returns

  - A new theme with dark mode colors
  """
  def create_dark_theme(theme) do
    # Create dark mode palette
    dark_palette = Enum.map(theme.palette, fn {name, color} ->
      dark_color = darken_color(color, 0.8)
      {name, dark_color}
    end)
    |> Map.new()

    # Return dark theme
    %{theme | palette: dark_palette, dark_mode: true}
  end

  @doc """
  Creates a high contrast version of a theme.

  ## Parameters

  - `theme` - The theme to create a high contrast version of

  ## Returns

  - A new theme with high contrast colors
  """
  def create_high_contrast_theme(theme) do
    # Create high contrast palette
    high_contrast_palette = Enum.map(theme.palette, fn {name, color} ->
      high_contrast_color = increase_contrast(color)
      {name, high_contrast_color}
    end)
    |> Map.new()

    # Return high contrast theme
    %{theme | palette: high_contrast_palette, high_contrast: true}
  end

  # Private functions

  defp darken_color(color, factor) do
    %{
      r: round(color.r * factor),
      g: round(color.g * factor),
      b: round(color.b * factor),
      a: color.a
    }
  end

  defp increase_contrast(color) do
    # Increase contrast by making colors more extreme
    %{
      r: if(color.r > 127, do: 255, else: 0),
      g: if(color.g > 127, do: 255, else: 0),
      b: if(color.b > 127, do: 255, else: 0),
      a: color.a
    }
  end
end
