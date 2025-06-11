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

  @derive Jason.Encoder
  defstruct [
    :id,
    :name,
    :description,
    :colors,
    :component_styles,
    :variants,
    :metadata,
    :fonts,
    :ui_mappings
  ]

  @behaviour Access

  # Access behaviour implementation
  @impl true
  def fetch(%__MODULE__{} = theme, key) when is_atom(key) or is_binary(key) do
    Map.fetch(theme, key)
  end

  @impl true
  def get_and_update(%__MODULE__{} = theme, key, fun)
      when is_atom(key) or is_binary(key) do
    Map.get_and_update(theme, key, fun)
  end

  @impl true
  def pop(%__MODULE__{} = theme, key) when is_atom(key) or is_binary(key) do
    Map.pop(theme, key)
  end

  @doc """
  Creates a new theme with the given attributes.
  """
  def new(), do: new(default_attrs())

  def new(attrs) when is_map(attrs) do
    attrs =
      if Map.has_key?(attrs, :colors) do
        Map.update!(attrs, :colors, fn colors ->
          Enum.into(colors, %{}, fn
            {k, v} when is_binary(v) ->
              {k, Raxol.Style.Colors.Color.from_hex(v)}

            {k, v} ->
              {k, v}
          end)
        end)
      else
        attrs
      end

    struct(__MODULE__, attrs)
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
    case get_in(theme, [:component_styles, component_type]) do
      nil ->
        require Raxol.Core.Runtime.Log

        Raxol.Core.Runtime.Log.warning(
          "Theme missing component style for #{inspect(component_type)}; returning empty map.",
          []
        )

        %{}

      style ->
        style
    end
  end

  def get_component_style(theme_map, component_type) when is_map(theme_map) do
    case get_in(theme_map, [component_type]) do
      nil -> %{}
      style -> style
    end
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

    %{
      theme
      | colors: high_contrast_colors,
        variants:
          Map.put(theme.variants, :high_contrast, %{
            colors: high_contrast_colors
          })
    }
  end

  @doc """
  Returns a high-contrast version of the given theme, for accessibility support.
  If the theme is already high-contrast, returns it unchanged.
  """
  def adjust_for_high_contrast(%__MODULE__{} = theme) do
    create_high_contrast_variant(theme)
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
  Returns the current theme.
  """
  def current do
    Application.get_env(:raxol, :current_theme, default_theme())
  end

  @doc """
  Returns the default theme.
  """
  def default_theme do
    new(%{
      id: :default,
      name: "default",
      colors: %{
        background: "#000000",
        foreground: "#FFFFFF",
        accent: "#4A9CD5",
        error: "#FF5555",
        warning: "#FFB86C",
        success: "#50FA7B",
        fuschia: "#FF00FF"
      },
      component_styles: %{
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
        },
        text_field: %{
          border: :single,
          padding: {0, 1}
        },
        table: %{
          border: :single,
          header_background: Color.from_hex("#222831"),
          header_foreground: Color.from_hex("#FFFFFF"),
          row_background: Color.from_hex("#1E1E1E"),
          row_foreground: Color.from_hex("#FFFFFF"),
          selected_row_background: Color.from_hex("#4A9CD5"),
          selected_row_foreground: Color.from_hex("#FFFFFF")
        }
      }
    })
  end

  @doc """
  Returns the dark theme.
  """
  def dark_theme do
    new(%{
      id: :dark,
      name: "dark",
      colors: %{
        background: "#1E1E1E",
        foreground: "#FFFFFF",
        accent: "#4A9CD5",
        error: "#FF5555",
        warning: "#FFB86C",
        success: "#50FA7B",
        fuschia: "#FF00FF"
      },
      component_styles: %{
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
    })
  end

  def component_style(theme, component_type),
    do: get_component_style(theme, component_type)

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
      },
      ui_mappings: %{
        app_background: :background,
        surface_background: :surface,
        primary_button: :primary,
        secondary_button: :secondary,
        accent_button: :accent,
        error_text: :error,
        success_text: :success,
        warning_text: :warning,
        info_text: :info,
        text: :text
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

  @doc """
  Applies a theme by name or struct.
  """
  def apply_theme(%__MODULE__{} = theme) do
    Application.put_env(:raxol, :current_theme, theme)
    :ok
  end

  def apply_theme(theme_name) when is_atom(theme_name) do
    case get(theme_name) do
      nil -> {:error, :theme_not_found}
      theme -> apply_theme(theme)
    end
  end

  @doc """
  Lists all available themes.
  """
  def list_themes do
    case Application.get_env(:raxol, :themes) do
      nil -> [default_theme()]
      themes -> Map.values(themes)
    end
  end

  def default_theme_id(), do: :default

  # Implement String.Chars protocol for Theme
  if Code.ensure_loaded?(String.Chars) do
    defimpl String.Chars, for: __MODULE__ do
      def to_string(theme) do
        "#<Theme id=#{inspect(theme.id)} name=#{inspect(theme.name)} colors=#{inspect(Map.keys(theme.colors))}>"
      end
    end
  end
end
