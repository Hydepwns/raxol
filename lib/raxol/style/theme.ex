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
  """
  def register_variant(name, variant_styles) when is_atom(name) do
    current = current()

    updated = %{
      current
      | variants: Map.put(current.variants, name, variant_styles)
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
  Gets a color from the current theme's palette.
  """
  def get_color(name) when is_atom(name) do
    Map.get(current().color_palette, name)
  end

  @doc """
  Creates a high-contrast version of the current theme.
  """
  def create_high_contrast_variant do
    high_contrast_styles = %Style{
      text_decoration: [:bold]
    }

    register_variant(:high_contrast, high_contrast_styles)
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
end
