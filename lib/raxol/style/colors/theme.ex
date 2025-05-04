defmodule Raxol.Style.Colors.Theme do
  @moduledoc """
  Manages color themes for the Raxol application.

  This module provides functionality for:
  - Creating and managing themes
  - Applying themes to the application
  - Accessing theme colors
  - Updating theme colors
  """

  alias Raxol.Style.Colors.{System, Persistence, Color}

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
        "primary" => Color.from_rgb(0, 119, 204),
        "secondary" => Color.from_rgb(102, 102, 102),
        "accent" => Color.from_rgb(255, 153, 0),
        "background" => Color.from_rgb(255, 255, 255),
        "surface" => Color.from_rgb(245, 245, 245),
        "error" => Color.from_rgb(204, 0, 0),
        "success" => Color.from_rgb(0, 153, 0),
        "warning" => Color.from_rgb(255, 153, 0),
        "info" => Color.from_rgb(0, 153, 204),
        "text" => Color.from_rgb(51, 51, 51)
      },
      ui_mappings: %{
        :app_background => "background",
        :surface_background => "surface",
        :primary_button => "primary",
        :secondary_button => "secondary",
        :accent_button => "accent",
        :error_text => "error",
        :success_text => "success",
        :warning_text => "warning",
        :info_text => "info",
        :text => "text"
      },
      dark_mode: false,
      high_contrast: false
    }
  end

  @doc """
  Creates a new theme from a given palette map and optional name.

  Assumes the input palette map contains Color structs or maps convertible to Color structs.

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
  @spec from_palette(map() | Raxol.Style.Colors.Palette.t(), String.t()) :: theme()
  def from_palette(palette_data, name \\ "Custom") do
    default_theme = standard_theme()

    # Handle both map and Palette struct input
    input_colors =
      case palette_data do
        %Raxol.Style.Colors.Palette{colors: colors} -> colors
        map when is_map(map) -> map
        _ -> %{} # Or raise error for invalid input
      end

    # Ensure input palette values are Color structs
    processed_palette =
      Enum.into(input_colors, %{}, fn {key, val} ->
        color_struct =
          case val do
            %Color{} = c -> c
            # Ensure :a for struct!
            map when is_map(map) -> struct!(Color, Map.put_new(map, :a, 1.0))
            hex when is_binary(hex) -> Color.from_hex(hex)
            # Or raise error?
            _ -> nil
          end

        {key, color_struct}
      end)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    %__MODULE__{
      name: name,
      palette: processed_palette,
      ui_mappings: default_theme.ui_mappings,
      dark_mode: default_theme.dark_mode,
      high_contrast: default_theme.high_contrast
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
    new_palette =
      Enum.reduce(colors, theme.palette, fn {element, color}, palette ->
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
    dark_palette =
      Enum.map(theme.palette, fn {name, color} ->
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
    high_contrast_palette =
      Enum.map(theme.palette, fn {name, color} ->
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
