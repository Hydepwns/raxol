defmodule Raxol.UI.Theming.Theme do
  @moduledoc """
  Theme management for Raxol UI components.

  This module provides functionality for:
  - Theme definition and management
  - Color palette integration
  - Component styling
  - Theme variants and accessibility
  """

  alias Raxol.Style.Colors.{Color, Utilities}
  alias Raxol.Core.ColorSystem

  @type color_value :: Color.t() | atom() | String.t()
  @type style_map :: %{atom() => any()}

  defstruct [
    :id,
    :name,
    :description,
    :colors,
    :component_styles,
    :variants,
    :metadata,
    :fonts
  ]

  @doc """
  Creates a new theme with the given attributes.
  """
  def new(attrs \\ %{}) do
    struct!(__MODULE__, Map.merge(default_attrs(), attrs))
  end

  @doc """
  Gets a color from the theme, respecting variants and accessibility settings.
  """
  def get_color(theme, color_name, arg3 \\ nil)
  def get_color(%__MODULE__{} = theme, color_name, variant) do
    ColorSystem.get_color(theme.id, color_name, variant)
  end
  def get_color(theme, color_name, default) do
    get_in(theme, [:colors, color_name]) || default
  end

  @doc """
  Gets a component style from the theme.
  """
  def get_component_style(%__MODULE__{} = theme, component_type) do
    Map.get(theme.component_styles, component_type, %{})
  end

  @doc """
  Creates a high contrast variant of the theme.
  """
  def create_high_contrast_variant(%__MODULE__{} = theme) do
    high_contrast_colors =
      Enum.map(theme.colors, fn {name, color} ->
        {name, Utilities.increase_contrast(color)}
      end)
      |> Map.new()

    %{theme |
      colors: high_contrast_colors,
      variants: Map.put(theme.variants, :high_contrast, %{
        colors: high_contrast_colors
      })
    }
  end

  @doc """
  Gets a theme by ID.
  """
  def get(theme_id) do
    case Application.get_env(:raxol, :themes) do
      nil -> default_theme()
      themes -> Map.get(themes, theme_id, default_theme())
    end
  end

  @doc """
  Returns the default theme.
  """
  def default_theme do
    %{
      name: "default",
      colors: %{
        background: "#000000",
        foreground: "#FFFFFF",
        accent: "#4A9CD5",
        error: "#FF5555",
        warning: "#FFB86C",
        success: "#50FA7B"
      },
      styles: %{
        text_input: %{
          background: "#1E1E1E",
          foreground: "#FFFFFF",
          border: "#4A9CD5",
          focus: "#4A9CD5"
        },
        button: %{
          background: "#4A9CD5",
          foreground: "#FFFFFF",
          hover: "#5FB0E8",
          active: "#3A8CC5"
        },
        checkbox: %{
          background: "#1E1E1E",
          foreground: "#FFFFFF",
          border: "#4A9CD5",
          checked: "#4A9CD5"
        }
      }
    }
  end

  @doc """
  Returns the dark theme.
  """
  def dark_theme do
    %{
      name: "dark",
      colors: %{
        background: "#1E1E1E",
        foreground: "#FFFFFF",
        accent: "#4A9CD5",
        error: "#FF5555",
        warning: "#FFB86C",
        success: "#50FA7B"
      },
      styles: %{
        text_input: %{
          background: "#2D2D2D",
          foreground: "#FFFFFF",
          border: "#4A9CD5",
          focus: "#4A9CD5"
        },
        button: %{
          background: "#4A9CD5",
          foreground: "#FFFFFF",
          hover: "#5FB0E8",
          active: "#3A8CC5"
        },
        checkbox: %{
          background: "#2D2D2D",
          foreground: "#FFFFFF",
          border: "#4A9CD5",
          checked: "#4A9CD5"
        }
      }
    }
  end

  @doc """
  Gets the component style for a specific component type.
  """
  def get_component_style(theme, component_type) do
    get_in(theme, [:styles, component_type]) || %{}
  end

  # Private helpers

  defp default_attrs do
    %{
      id: :default,
      name: "Default Theme",
      description: "The default Raxol theme",
      colors: %{
        primary: Color.from_hex("#0077CC"),
        secondary: Color.from_hex("#666666"),
        accent: Color.from_hex("#FF9900"),
        background: Color.from_hex("#FFFFFF"),
        surface: Color.from_hex("#F5F5F5"),
        error: Color.from_hex("#CC0000"),
        success: Color.from_hex("#009900"),
        warning: Color.from_hex("#FF9900"),
        info: Color.from_hex("#0099CC"),
        text: Color.from_hex("#333333")
      },
      component_styles: %{
        panel: %{
          border: :single,
          padding: 1
        },
        button: %{
          padding: {0, 1},
          text_style: [:bold]
        },
        text_field: %{
          border: :single,
          padding: {0, 1}
        }
      },
      variants: %{},
      metadata: %{
        author: "Raxol",
        version: "1.0.0"
      },
      fonts: %{
        default: %{
          family: "monospace",
          size: 12,
          weight: "normal"
        }
      }
    }
  end

  @doc """
  Initializes the theme system and registers the default theme.
  This should be called during application startup.
  """
  def init do
    # Create and register the default theme
    default_theme = new()
    register(default_theme)
    :ok
  end

  @doc """
  Registers a theme in the application environment.
  """
  def register(%__MODULE__{} = theme) do
    current_themes = Application.get_env(:raxol, :themes, %{})
    new_themes = Map.put(current_themes, theme.id, theme)
    Application.put_env(:raxol, :themes, new_themes)
    :ok
  end
end
