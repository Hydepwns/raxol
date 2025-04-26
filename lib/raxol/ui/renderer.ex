defmodule Raxol.UI.Renderer do
  @moduledoc """
  Translates a positioned element tree into a flat list of renderable cells.

  Takes the output of the Layout Engine and converts UI primitives (text, boxes, etc.)
  into styled characters at specific coordinates.
  """

  require Logger

  # Map representing an element with x, y, width, height, type, attrs, etc.
  @type positioned_element :: map()
  @type cell ::
          {x :: integer(), y :: integer(), char :: String.t(), fg :: term(),
           bg :: term(), attrs :: list(atom())}
  # The theme is expected to be %Raxol.UI.Theming.Theme{} but we use map() for flexibility
  @type theme :: map()

  # Define a default foreground and background for fallback
  # Or use theme.colors.foreground? Requires theme passed everywhere
  @default_fg :default
  # Or use theme.colors.background?
  @default_bg :default

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
  # Use the full module name for clarity and to avoid alias issues
  def render_to_cells(elements_or_element, theme \\ Raxol.UI.Theming.Theme.default_theme())

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
    component_type =
      Map.get(attrs, :component_type) || Map.get(attrs, :original_type)

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
    component_type =
      Map.get(attrs, :component_type) || Map.get(attrs, :original_type)

    # Resolve styles using component-specific theme styles
    {fg, bg, style_attrs} = resolve_styles(attrs, component_type, theme)

    # Get border style from component styles or attrs
    border_style =
      Map.get(attrs, :border) ||
        Map.get(theme.component_styles[component_type] || %{}, :border, :none)

    # Initialize cell lists
    # background_cells = [] # Removed - assigned below
    # border_cells = [] # Removed - assigned below

    # Draw background first
    background_cells =
      if w > 0 and h > 0 do
        for cur_y <- y..(y + h - 1), cur_x <- x..(x + w - 1) do
          {cur_x, cur_y, " ", fg, bg, style_attrs}
        end
      else
        []
      end

    # Draw border if style is not :none and dimensions allow
    border_cells =
      if border_style != :none and w > 0 and h > 0 do
        border_chars = get_border_chars(border_style)

        # Draw corners
        corner_cells =
          [
            # Top-left
            {x, y, border_chars.top_left, fg, bg, style_attrs},
            # Top-right
            {x + w - 1, y, border_chars.top_right, fg, bg, style_attrs},
            # Bottom-left
            {x, y + h - 1, border_chars.bottom_left, fg, bg, style_attrs},
            # Bottom-right
            {x + w - 1, y + h - 1, border_chars.bottom_right, fg, bg,
             style_attrs}
          ]

        # Draw horizontal lines (if width > 1)
        horizontal_cells =
          if w > 1 do
            (for cur_x <- (x + 1)..(x + w - 2) do
               [
                 # Top
                 {cur_x, y, border_chars.horizontal, fg, bg, style_attrs},
                 # Bottom
                 {cur_x, y + h - 1, border_chars.horizontal, fg, bg, style_attrs}
               ]
             end)
            |> List.flatten()
          else
            []
          end

        # Draw vertical lines (if height > 1)
        vertical_cells =
          if h > 1 do
            (for cur_y <- (y + 1)..(y + h - 2) do
               [
                 # Left
                 {x, cur_y, border_chars.vertical, fg, bg, style_attrs},
                 # Right
                 {x + w - 1, cur_y, border_chars.vertical, fg, bg, style_attrs}
               ]
             end)
            |> List.flatten()
          else
            []
          end

        # Combine border cells
        corner_cells ++ horizontal_cells ++ vertical_cells
      else
        # No border
        []
      end

    # Return combined background and border cells
    # Border cells should render 'on top' of background due to list order
    background_cells ++ border_cells
  end

  # Helper to get border characters based on style
  defp get_border_chars(:single) do
    %{
      top_left: "┌",
      top_right: "┐",
      bottom_left: "└",
      bottom_right: "┘",
      horizontal: "─",
      vertical: "│"
    }
  end

  defp get_border_chars(:double) do
    %{
      top_left: "╔",
      top_right: "╗",
      bottom_left: "╚",
      bottom_right: "╝",
      horizontal: "═",
      vertical: "║"
    }
  end

  defp get_border_chars(:rounded) do
    %{
      top_left: "╭",
      top_right: "╮",
      bottom_left: "╰",
      bottom_right: "╯",
      horizontal: "─",
      vertical: "│"
    }
  end

  # Fallback for unknown or :none
  defp get_border_chars(_) do
    %{
      top_left: " ",
      top_right: " ",
      bottom_left: " ",
      bottom_right: " ",
      horizontal: " ",
      vertical: " "
    }
  end

  # --- Theme Helper Functions ---

  @doc false
  # Resolves fg, bg, and style attributes based on element attrs, component type, and theme.
  # Priority:
  # 1. Explicit attrs (:fg, :bg, :style)
  # 2. Component-specific theme styles (e.g., theme.component_styles.button.fg)
  # 3. General theme colors (looked up via ColorSystem.get)
  # 4. Global defaults (@default_fg / @default_bg / [])
  defp resolve_styles(attrs, component_type, %Raxol.UI.Theming.Theme{} = theme) do
    # Theme ID is needed for ColorSystem
    theme_id = theme.id

    # Fetch component styles from theme if component_type is known
    component_styles =
      if component_type do
        Map.get(theme.component_styles, component_type, %{})
      else
        %{}
      end

    # Determine fg color
    fg_color =
      cond do
        Map.has_key?(attrs, :fg) -> Map.get(attrs, :fg)
        Map.has_key?(component_styles, :fg) -> Map.get(component_styles, :fg)
        # Use ColorSystem for semantic lookup
        true -> Raxol.Core.ColorSystem.get(theme_id, :foreground) || @default_fg
      end

    # Determine bg color
    bg_color =
      cond do
        Map.has_key?(attrs, :bg) -> Map.get(attrs, :bg)
        Map.has_key?(component_styles, :bg) -> Map.get(component_styles, :bg)
        # Use ColorSystem for semantic lookup
        true -> Raxol.Core.ColorSystem.get(theme_id, :background) || @default_bg
      end

    # Determine style attributes (bold, underline, etc.)
    # Priority: explicit attrs -> component styles
    explicit_style_attrs = Map.get(attrs, :style, [])
    component_style_attrs = Map.get(component_styles, :style, []) # Assuming style is list of atoms
    # Merge: explicit attrs take precedence (simple list concatenation for now)
    # A proper merge might be needed depending on how styles are defined
    final_style_attrs = explicit_style_attrs ++ component_style_attrs |> Enum.uniq()

    {fg_color, bg_color, final_style_attrs}
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
        get_theme_color(
          Map.get(theme.colors, theme_default_key),
          theme,
          @default_fg
        )

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
