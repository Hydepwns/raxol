defmodule Raxol.UI.Renderer do
  @moduledoc """
  Translates a positioned element tree into a flat list of renderable cells.

  Takes the output of the Layout Engine and converts UI primitives (text, boxes, etc.)
  into styled characters at specific coordinates.
  """

  require Logger

  alias Raxol.UI.Theming.Theme
  alias Raxol.UI.Theme
  # alias Raxol.Terminal.Cell # Unused
  # alias Raxol.Core.Renderer.Color # Unused

  # Map representing an element with x, y, width, height, type, attrs, etc.
  @type positioned_element :: map()
  @type cell ::
          {x :: integer(), y :: integer(), char :: String.t(), fg :: term(),
           bg :: term(), attrs :: list(atom())}
  # The theme is expected to be %Raxol.UI.Theming.Theme{} but we use map() for flexibility
  @type theme :: map()

  # Define a default foreground and background for fallback
  @default_fg :default # Or use theme.colors.foreground? Requires theme passed everywhere
  @default_bg :default # Or use theme.colors.background?

  @doc """
  Renders a tree of positioned elements into a list of cells.

  Args:
    - `elements`: A list or single map representing positioned elements from the Layout Engine.
    - `theme`: The current theme map (expected %Theme{}).

  Returns:
    - `list(cell())`
  """
  @spec render_to_cells(
          positioned_element() | list(positioned_element()),
          theme()
        ) :: list(cell())
  # Accept theme struct or map, provide default theme if needed
  def render_to_cells(elements_or_element, theme \\ Theme.default_theme())

  # Clause for list of elements
  def render_to_cells(elements, theme) when is_list(elements) do
    Enum.flat_map(elements, &render_element(&1, theme))
  end

  # Clause for single element
  def render_to_cells(element, theme) when is_map(element) do
    render_element(element, theme)
  end

  # --- Private Element Rendering Functions ---

  defp render_element(element, theme) do
    # Dispatch based on element type found in the layout engine output
    case element do
      %{type: :text, x: x, y: y, text: text, attrs: attrs} ->
        render_text(x, y, text, attrs, theme)

      %{type: :box, x: x, y: y, width: w, height: h, attrs: attrs} ->
        render_box(x, y, w, h, attrs, theme)

      # TODO: Add cases for other element types (:panel, :button, :input, :table etc.)
      # These might be decomposed into :text and :box primitives by the layout engine,
      # or we might need to handle them directly here, applying component-specific styles.

      _other ->
        Logger.warning(
          "[#{__MODULE__}] Unknown or unhandled element type for rendering: #{inspect(Map.get(element, :type))} - Element: #{inspect(element)}"
        )

        []
    end
  end

  defp render_text(x, y, text, attrs, theme) when is_binary(text) do
    # Determine component type from attrs for specific styling
    component_type = Map.get(attrs, :component_type) || Map.get(attrs, :original_type)

    # Resolve styles using component-specific theme styles if available
    {fg, bg, style_attrs} = resolve_styles(attrs, component_type, theme)

    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.map(fn {char, index} ->
      {x + index, y, char, fg, bg, style_attrs}
    end)
  end

  defp render_text(_x, _y, text, _attrs, _theme) do
    Logger.warning(
      "[#{__MODULE__}] Invalid text content for rendering: #{inspect(text)}. Expected binary."
    )

    []
  end

  defp render_box(x, y, w, h, attrs, theme) do
    # Determine component type from attrs
    component_type = Map.get(attrs, :component_type) || Map.get(attrs, :original_type)

    # Resolve styles using component-specific theme styles
    {fg, bg, style_attrs} = resolve_styles(attrs, component_type, theme)

    # TODO: Implement actual border drawing based on theme/attrs
    # (e.g., :border type :single, :double from theme.component_styles[component_type].border)
    # For now, just fills the background

    for cur_y <- y..(y + h - 1), cur_x <- x..(x + w - 1) do
      # Use space character for filling
      {cur_x, cur_y, " ", fg, bg, style_attrs}
    end
  end

  # --- Theme Helper Functions ---

  @doc false
  # Resolves fg, bg, and style attributes based on element attrs, component type, and theme.
  # Priority:
  # 1. Explicit attrs (:fg, :bg, :style)
  # 2. Component-specific theme styles (e.g., theme.component_styles.button.fg)
  # 3. General theme colors (theme.colors.foreground / :background)
  # 4. Global defaults (@default_fg / @default_bg / [])
  defp resolve_styles(attrs, component_type, theme) do
    # Fetch component styles from theme if component_type is known
    component_styles =
      if component_type && is_map(theme) && Map.has_key?(theme, :component_styles) do
        Map.get(theme.component_styles, component_type, %{})
      else
        %{}
      end

    # Special handling for text_input placeholder
    is_placeholder = Map.get(attrs, :is_placeholder, false)
    component_styles =
      if is_placeholder and Map.has_key?(component_styles, :placeholder) do
        # Use placeholder color if defined, merge with base component styles
        placeholder_styles = %{fg: Map.get(component_styles, :placeholder)}
        Map.merge(component_styles, placeholder_styles)
      else
        component_styles
      end

    # Resolve foreground color
    fg =
      Map.get(attrs, :fg)
      |> default_if_nil(Map.get(component_styles, :fg))
      |> resolve_color(theme, :foreground)

    # Resolve background color
    bg =
      Map.get(attrs, :bg)
      |> default_if_nil(Map.get(component_styles, :bg))
      |> resolve_color(theme, :background)

    # Resolve style attributes (e.g., [:bold])
    style_attrs =
      Map.get(attrs, :style)
      |> default_if_nil(Map.get(component_styles, :style, []))

    {fg, bg, style_attrs}
  end

  @doc false
  # Helper to return default value if primary is nil
  defp default_if_nil(primary, default), do: primary || default

  @doc false
  # Resolves a potential color name/value from the theme palette.
  # Priority:
  # 1. Provided color value (if not nil or :default)
  # 2. Theme component style (implicitly handled by caller using default_if_nil)
  # 3. Theme general color (e.g., theme.colors.foreground)
  # 4. Global default (@default_fg or @default_bg)
  defp resolve_color(color_name_or_value, theme, theme_default_key) do
    cond do
      # Explicit color set (and not :default)
      color_name_or_value != nil and color_name_or_value != :default ->
        get_theme_color(color_name_or_value, theme, color_name_or_value)

      # No explicit color, try theme default for this context (e.g., :foreground)
      theme_default_key != nil ->
        get_theme_color(Map.get(theme.colors, theme_default_key), theme, @default_fg)

      # Fallback to global default
      true ->
        # Use specific default based on key
        if theme_default_key == :background, do: @default_bg, else: @default_fg
    end
  end

  @doc false
  # Looks up a color name in the theme's color palette.
  # If the color is already resolved (not an atom), returns it directly.
  # If the color name (atom) exists in theme.colors, returns the resolved theme color.
  # Otherwise, returns the fallback.
  defp get_theme_color(color_name_or_value, theme, fallback) do
    cond do
      # Already resolved (e.g., a direct hex value - unlikely here but good practice)
      not is_atom(color_name_or_value) ->
        color_name_or_value

      # Is an atom, check theme palette
      is_map(theme) and Map.has_key?(theme, :colors) and
          Map.has_key?(theme.colors, color_name_or_value) ->
        Map.get(theme.colors, color_name_or_value)

      # Color name not in theme, return fallback
      true ->
        fallback
    end
  end

  # TODO: Add private helper functions for resolving styles (bold, italic etc.) from theme if needed.
end
