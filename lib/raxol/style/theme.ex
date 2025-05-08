defmodule Raxol.Style.Theme do
  @moduledoc """
  Theme management for Raxol applications.

  This module provides functionality for creating, switching, and customizing themes.
  Themes define the visual appearance of the application, including colors, borders,
  and component-specific styles.
  """

  alias Raxol.Style

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          styles: map(),
          variants: map(),
          color_palette: map(),
          metadata: map()
        }

  defstruct name: "default",
            description: "Default theme",
            styles: %{},
            variants: %{},
            color_palette: %{},
            metadata: %{}

  # Process dictionary key for current theme
  @theme_key :raxol_current_theme

  @doc """
  Creates a new theme with the specified attributes.
  """
  def new(attrs \\ %{}) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Gets the current active theme.
  Returns the default theme if none is set.
  """
  def current do
    Process.get(@theme_key) || default_theme()
  end

  @doc """
  Sets the current active theme.
  """
  def set_current(theme) do
    Process.put(@theme_key, theme)
    :ok
  end

  @doc """
  Registers a new style in the current theme.
  """
  def register_style(name, style) when is_atom(name) do
    current = current()
    updated = %{current | styles: Map.put(current.styles, name, style)}
    set_current(updated)
    :ok
  end

  @doc """
  Registers a theme variant.
  Theme variants allow for alternate visual styles like high-contrast, dark mode, etc.
  A variant can include overrides for both :styles and :color_palette.
  """
  def register_variant(name, variant_overrides)
      when is_atom(name) and is_map(variant_overrides) do
    current = current()

    # Ensure variant_overrides has :styles and :color_palette keys, even if empty
    validated_overrides =
      Map.merge(%{styles: %{}, color_palette: %{}}, variant_overrides)

    updated = %{
      current
      | variants: Map.put(current.variants, name, validated_overrides)
    }

    set_current(updated)
    :ok
  end

  @doc """
  Sets the color palette for the current theme.
  """
  def set_color_palette(palette) when is_map(palette) do
    current = current()
    updated = %{current | color_palette: palette}
    set_current(updated)
    :ok
  end

  @doc """
  Gets a style from the current theme by name.
  """
  def get_style(name) when is_atom(name) do
    Map.get(current().styles, name, Style.new())
  end

  @doc """
  Gets a color from the current theme's palette, considering active variants.
  Checks the active variant first, then the base palette.
  (Note: Need a way to know the active variant - maybe from Accessibility state?)
  This is a placeholder - the logic to check active variant needs refinement.
  """
  def get_color(name, active_variant \\ nil) when is_atom(name) do
    theme = current()

    # 1. Try active variant palette
    variant_color =
      if active_variant do
        theme.variants
        |> Map.get(active_variant, %{})
        |> Map.get(:color_palette, %{})
        |> Map.get(name)
      end

    # 2. Try base theme palette if variant color not found
    variant_color || Map.get(theme.color_palette, name)
  end

  @doc """
  Creates and registers a high-contrast variant based on predefined high-contrast colors.
  This variant overrides the color palette.
  """
  def create_high_contrast_variant do
    # Define the high-contrast palette (similar to ThemeIntegration's old one)
    high_contrast_palette = %{
      background: :black,
      foreground: :white,
      accent: :yellow,
      focus: :white,
      button: :yellow,
      error: :red,
      success: :green,
      warning: :yellow,
      info: :cyan,
      border: :white,
      # Add other semantic colors as needed
      primary: :yellow,
      secondary: :cyan,
      disabled: :dark_gray
    }

    # Define any style overrides for high contrast (e.g., bold text)
    high_contrast_styles = %{
      # Example: make all default text bold
      default: %Style{text_decoration: [:bold]}
    }

    variant_overrides = %{
      styles: high_contrast_styles,
      color_palette: high_contrast_palette
    }

    register_variant(:high_contrast, variant_overrides)
  end

  @doc """
  Exports the current theme as a map suitable for serialization.
  """
  def export do
    current()
    |> Map.from_struct()
  end

  @doc """
  Imports a theme from the given map data.
  """
  def import(data) when is_map(data) do
    theme = struct(__MODULE__, data)
    set_current(theme)
    :ok
  end

  # TODO: Implement dynamic theme discovery (e.g., from config or files)
  @spec available_themes() :: %{String.t() => t()}
  def available_themes do
    %{
      "default" => default_theme(),
      "dark" => dark_theme(),
      "light" => light_theme()
      # Add more themes here as needed
    }
  end

  @doc """
  Returns a list of available theme structs.
  """
  @spec list_themes() :: list(t())
  def list_themes do
    available_themes() |> Map.values()
  end

  @doc """
  Gets a specific theme struct by its name.
  Returns nil if the theme name is not found.
  """
  @spec get_theme_by_name(String.t()) :: t() | nil
  def get_theme_by_name(name) do
    Map.get(available_themes(), name)
  end

  @doc """
  Applies a theme by its name, setting it as the current theme for the process.

  Returns `:ok` if the theme was found and applied, `:error` otherwise.
  """
  @spec apply_theme(String.t()) :: :ok | :error
  def apply_theme(name) do
    case get_theme_by_name(name) do
      nil ->
        # Optionally log a warning here
        :error

      theme ->
        set_current(theme)
    end
  end

  # Private helpers

  defp default_theme do
    # Create a basic default theme
    %__MODULE__{
      name: "default",
      description: "Default Raxol theme",
      styles: %{
        default: %Style{},
        primary: %Style{color: :blue, text_decoration: [:bold]},
        secondary: %Style{color: :cyan},
        success: %Style{color: :green},
        warning: %Style{color: :yellow},
        error: %Style{color: :red, text_decoration: [:bold]},
        info: %Style{color: :white},
        disabled: %Style{color: :gray}
      },
      variants: %{},
      color_palette: %{
        primary: :blue,
        secondary: :cyan,
        success: :green,
        warning: :yellow,
        error: :red,
        info: :white,
        disabled: :gray,
        background: :black,
        foreground: :white
      },
      metadata: %{
        author: "Raxol",
        version: "1.0.0"
      }
    }
  end

  # Example additional themes
  defp dark_theme do
    %__MODULE__{
      name: "dark",
      description: "A dark Raxol theme",
      styles: %{
        default: %Style{color: :light_gray, background: :black},
        primary: %Style{
          color: :cyan,
          text_decoration: [:bold],
          background: :black
        },
        secondary: %Style{color: :magenta, background: :black},
        success: %Style{color: :green, background: :black},
        warning: %Style{color: :yellow, background: :black},
        error: %Style{color: :red, text_decoration: [:bold], background: :black},
        info: %Style{color: :white, background: :black},
        disabled: %Style{color: :dark_gray, background: :black}
      },
      variants: %{},
      color_palette: %{
        primary: :cyan,
        secondary: :magenta,
        success: :green,
        warning: :yellow,
        error: :red,
        info: :white,
        disabled: :dark_gray,
        background: :black,
        foreground: :light_gray
      },
      metadata: %{author: "Raxol", version: "1.0.0"}
    }
  end

  defp light_theme do
    %__MODULE__{
      name: "light",
      description: "A light Raxol theme",
      styles: %{
        default: %Style{color: :dark_gray, background: :white},
        primary: %Style{
          color: :blue,
          text_decoration: [:bold],
          background: :white
        },
        secondary: %Style{color: :purple, background: :white},
        success: %Style{color: :dark_green, background: :white},
        warning: %Style{color: :dark_yellow, background: :white},
        error: %Style{
          color: :dark_red,
          text_decoration: [:bold],
          background: :white
        },
        info: %Style{color: :black, background: :white},
        disabled: %Style{color: :light_gray, background: :white}
      },
      variants: %{},
      color_palette: %{
        primary: :blue,
        secondary: :purple,
        success: :dark_green,
        warning: :dark_yellow,
        error: :dark_red,
        info: :black,
        disabled: :light_gray,
        background: :white,
        foreground: :dark_gray
      },
      metadata: %{
        author: "Raxol",
        version: "1.0.0"
      }
    }
  end
end
