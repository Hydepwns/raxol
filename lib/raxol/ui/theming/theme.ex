defmodule Raxol.UI.Theming.Theme do
  @moduledoc """
  Defines and manages UI themes for the Raxol system.

  This module provides:
  * Theme definition and registration
  * Default theme settings
  * Theme application to UI elements
  * Color scheme management
  """

  @type t :: %__MODULE__{
          id: atom(),
          name: String.t(),
          description: String.t(),
          colors: map(),
          fonts: map(),
          component_styles: map()
        }

  defstruct id: :default,
            name: "Default Theme",
            description: "The default Raxol theme",
            colors: %{},
            fonts: %{},
            component_styles: %{}

  # Store registered themes
  @themes_table :themes

  @doc """
  Initializes the theme system.
  """
  def init do
    # Set up ETS table for themes
    :ets.new(@themes_table, [:set, :public, :named_table])

    # Register built-in themes
    register(default_theme())
    register(dark_theme())

    :ok
  end

  @doc """
  Registers a theme for use in the application.

  ## Parameters

  * `theme` - The theme struct to register

  ## Returns

  `:ok`
  """
  def register(%__MODULE__{} = theme) do
    :ets.insert(@themes_table, {theme.id, theme})
    :ok
  end

  @doc """
  Gets a theme by ID.

  ## Parameters

  * `theme_id` - The ID of the theme to retrieve

  ## Returns

  The theme struct or nil if not found
  """
  def get(theme_id) do
    case :ets.lookup(@themes_table, theme_id) do
      [{^theme_id, theme}] -> theme
      [] -> nil
    end
  end

  @doc """
  Lists all registered themes.

  ## Returns

  A list of theme structs
  """
  def list do
    :ets.tab2list(@themes_table)
    |> Enum.map(fn {_id, theme} -> theme end)
  end

  @doc """
  Gets the default theme.

  ## Returns

  The default theme struct
  """
  def default_theme do
    %__MODULE__{
      id: :default,
      name: "Default Theme",
      description: "The default Raxol theme",
      colors: %{
        primary: :blue,
        secondary: :cyan,
        success: :green,
        warning: :yellow,
        error: :red,
        info: :blue,
        background: :black,
        foreground: :white,
        accent: :magenta,
        border: :gray,
        text: :white,
        muted: :dark_gray
      },
      fonts: %{
        default: %{weight: :normal},
        heading: %{weight: :bold},
        code: %{family: :monospace}
      },
      component_styles: %{
        panel: %{
          border: :single,
          fg: :white,
          bg: :black
        },
        button: %{
          fg: :white,
          bg: :blue,
          focused_bg: :light_blue,
          disabled_bg: :dark_gray
        },
        text_field: %{
          fg: :white,
          bg: :black,
          border: :gray,
          focused_border: :blue,
          placeholder: :dark_gray
        },
        table: %{
          header_fg: :white,
          header_bg: :dark_blue,
          row_fg: :white,
          row_bg: :black,
          alternate_row_bg: :dark_gray,
          border: :gray
        }
      }
    }
  end

  @doc """
  Gets the dark theme.

  ## Returns

  The dark theme struct
  """
  def dark_theme do
    %__MODULE__{
      id: :dark,
      name: "Dark Theme",
      description: "A dark theme for Raxol",
      colors: %{
        primary: :blue,
        secondary: :cyan,
        success: :green,
        warning: :yellow,
        error: :red,
        info: :blue,
        background: :black,
        foreground: :light_gray,
        accent: :magenta,
        border: :dark_gray,
        text: :light_gray,
        muted: :dark_gray
      },
      fonts: %{
        default: %{weight: :normal},
        heading: %{weight: :bold},
        code: %{family: :monospace}
      },
      component_styles: %{
        panel: %{
          border: :single,
          fg: :dark_gray,
          bg: :black
        },
        button: %{
          fg: :black,
          bg: :blue,
          focused_bg: :light_blue,
          disabled_bg: :dark_gray
        },
        text_field: %{
          fg: :light_gray,
          bg: :black,
          border: :dark_gray,
          focused_border: :blue,
          placeholder: :dark_gray
        },
        table: %{
          header_fg: :black,
          header_bg: :dark_blue,
          row_fg: :light_gray,
          row_bg: :black,
          alternate_row_bg: :dark_gray,
          border: :dark_gray
        }
      }
    }
  end

  @doc """
  Gets a component style from a theme.

  ## Parameters

  * `theme` - The theme to get styles from
  * `component_type` - The type of component to get styles for

  ## Returns

  A map of style properties for the component, or an empty map if not found
  """
  def component_style(%__MODULE__{} = theme, component_type) do
    Map.get(theme.component_styles, component_type, %{})
  end

  @doc """
  Gets a color from a theme.

  ## Parameters

  * `theme` - The theme to get colors from
  * `color_name` - The name of the color to get

  ## Returns

  The color value, or a default color if not found
  """
  def color(%__MODULE__{} = theme, color_name) do
    Map.get(theme.colors, color_name, :white)
  end

  @doc """
  Applies a theme to an element tree.

  ## Parameters

  * `element` - The element tree to apply the theme to
  * `theme` - The theme to apply

  ## Returns

  The element tree with theme applied
  """
  def apply_theme(element, %__MODULE__{} = theme) do
    apply_theme_to_element(element, theme)
  end

  # Private helpers

  defp apply_theme_to_element(%{type: type, attrs: attrs} = element, theme)
       when is_atom(type) do
    # Get component style for this element type
    comp_style = component_style(theme, type)

    # Apply component style to element attributes
    themed_attrs = Map.merge(attrs, Map.drop(comp_style, [:children]))

    # Apply theme to children recursively
    themed_children =
      if Map.has_key?(element, :children) do
        apply_theme_to_children(Map.get(element, :children), theme)
      else
        nil
      end

    # Return themed element
    element
    |> Map.put(:attrs, themed_attrs)
    |> Map.put(:children, themed_children)
  end

  defp apply_theme_to_element(element, _theme), do: element

  defp apply_theme_to_children(children, theme) when is_list(children) do
    Enum.map(children, &apply_theme_to_element(&1, theme))
  end

  defp apply_theme_to_children(child, theme) do
    apply_theme_to_element(child, theme)
  end
end
