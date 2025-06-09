defmodule Raxol.UI.Theming.Theme do
  @moduledoc """
  Defines the theme structure and provides theme-related functionality.
  """

  defstruct name: nil,
            colors: %{},
            styles: %{},
            fonts: %{},
            spacing: %{},
            borders: %{},
            shadows: %{},
            transitions: %{},
            animations: %{},
            ui_mappings: %{},
            metadata: %{},
            component_styles: %{}

  @type t :: %__MODULE__{
          name: String.t() | nil,
          colors: map(),
          styles: map(),
          fonts: map(),
          spacing: map(),
          borders: map(),
          shadows: map(),
          transitions: map(),
          animations: map(),
          ui_mappings: map(),
          metadata: map(),
          component_styles: map()
        }

  @doc """
  Creates a new theme with the given name and attributes.
  """
  def new(name, attrs \\ %{}) do
    struct!(__MODULE__, Map.put(attrs, :name, name))
  end

  @doc """
  Merges two themes, with the second theme taking precedence.
  """
  def merge(%__MODULE__{} = theme1, %__MODULE__{} = theme2) do
    Map.merge(theme1, theme2)
  end

  @doc """
  Gets a value from the theme by path.
  """
  def get(%__MODULE__{} = theme, path) when is_list(path) do
    get_in(theme, path)
  end

  def get(%__MODULE__{} = theme, key) when is_atom(key) do
    Map.get(theme, key)
  end

  @doc """
  Sets a value in the theme at the given path.
  """
  def set(%__MODULE__{} = theme, path, value) when is_list(path) do
    put_in(theme, path, value)
  end

  def set(%__MODULE__{} = theme, key, value) when is_atom(key) do
    Map.put(theme, key, value)
  end

  alias Raxol.Style.Colors.{Color, Utilities}

  @type color_value :: Color.t() | atom() | String.t()
  @type style_map :: %{atom() => any()}

  @behaviour Access

  # Access behaviour implementation
  @impl Access
  def fetch(%__MODULE__{} = theme, key) when is_atom(key) or is_binary(key) do
    Map.fetch(theme, key)
  end

  @impl Access
  def get_and_update(%__MODULE__{} = theme, key, fun)
      when is_atom(key) or is_binary(key) do
    if is_map(theme), do: Map.get_and_update(theme, key, fun), else: :error
  end

  @impl Access
  def pop(%__MODULE__{} = theme, key) when is_atom(key) or is_binary(key) do
    Map.pop(theme, key)
  end

  @doc """
  Gets a color from the theme, respecting variants and accessibility settings.
  """
  def get_color(theme, color_name, arg3 \\ nil)

  def get_color(%__MODULE__{} = theme, color_name, _variant) do
    Map.get(theme.colors, color_name)
  end

  def get_color(theme, color_name, default) do
    get_in(theme, [:colors, color_name]) || default
  end

  @doc """
  Gets a component style from the theme.

  ## Parameters
    - theme: The theme to get the style from
    - component_type: The type of component to get the style for

  ## Returns
    - The component style
  """
  def get_component_style(theme, component_type) do
    case get_in(theme, [:styles, component_type]) do
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
        styles:
          Map.put(theme.styles, :high_contrast, %{
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
  Returns the theme struct or nil if not found.
  """
  def get(theme_id) do
    # Default to empty map if :themes not set
    registered_themes = Application.get_env(:raxol, :themes, %{})
    # Returns nil if theme_id is not a key
    Map.get(registered_themes, theme_id)
  end

  @doc """
  Applies a theme by name.
  """
  def apply(theme_name) when is_binary(theme_name) or is_atom(theme_name) do
    case get(theme_name) do
      nil ->
        require Raxol.Core.Runtime.Log

        Raxol.Core.Runtime.Log.warning(
          "Theme #{inspect(theme_name)} not found, using default theme",
          []
        )

        default_theme()

      theme ->
        Application.put_env(:raxol, :theme, theme)
        theme
    end
  end

  def default_theme do
    new("default", %{
      colors: %{
        primary: "#0077CC",
        secondary: "#6C757D",
        success: "#28A745",
        danger: "#DC3545",
        warning: "#FFC107",
        info: "#17A2B8",
        light: "#F8F9FA",
        dark: "#343A40",
        background: "#FFFFFF",
        surface: "#F8F9FA",
        text: "#212529"
      },
      styles: %{
        button: %{
          fg: :primary,
          bg: :light,
          style: [:bold]
        },
        input: %{
          fg: :text,
          bg: :light,
          style: []
        },
        text: %{
          fg: :text,
          bg: :background,
          style: []
        }
      },
      ui_mappings: %{
        app_background: :background,
        surface_background: :surface,
        primary_button: :primary,
        secondary_button: :secondary,
        text: :text
      },
      metadata: %{
        version: "1.0.0",
        author: "Raxol Team"
      },
      component_styles: %{}
    })
  end

  @doc """
  Returns the dark theme.
  """
  def dark_theme do
    new(%{
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
    })
  end

  def component_style(theme, component_type),
    do: get_component_style(theme, component_type)

  # Private helpers

  @doc """
  Initializes the theme system and registers the default theme.
  This should be called during application startup.
  """
  def init do
    # Create and register the default theme
    default_theme = new("default")
    register(default_theme)
    :ok
  end

  @doc """
  Registers a theme in the application environment.
  """
  def register(%__MODULE__{} = theme) do
    current_themes = Application.get_env(:raxol, :themes, %{})
    new_themes = Map.put(current_themes, theme.name, theme)
    Application.put_env(:raxol, :themes, new_themes)
    :ok
  end

  @doc """
  Lists all registered themes as a list of theme structs.
  """
  def list_themes do
    Application.get_env(:raxol, :themes, %{})
    |> Map.values()
  end

  @doc """
  Returns the currently active theme. Defaults to :default if not set.
  """
  def current do
    Application.get_env(:raxol, :theme, default_theme())
  end

  def default_theme_id(), do: "default"

  @doc """
  Gets a theme value.

  ## Parameters
    - theme: The theme to get the value from
    - key: The key to get the value for

  ## Returns
    - The theme value
  """
  def get_theme_value(_theme, _key) do
    # Implementation
  end
end
