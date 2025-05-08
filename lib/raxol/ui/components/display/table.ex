defmodule Raxol.UI.Components.Display.Table do
  @moduledoc """
  A component for displaying tabular data with sorting, filtering, and pagination.
  """
  require Logger
  require Raxol.View.Elements

  # alias Raxol.Core.Renderer.Element
  alias Raxol.UI.Theming.Theme
  alias Raxol.View.Elements

  @behaviour Raxol.UI.Components.Base.Component

  @type header :: String.t()
  # Allow various cell types
  @type cell :: String.t() | number() | atom()
  @type row :: [cell()]
  @type headers :: [header()]
  @type rows :: [row()]
  @type props :: %{
          optional(:id) => String.t(),
          # From macro
          optional(:columns) => list(),
          # From macro
          optional(:data) => list(),
          # From macro
          optional(:style) => map(),
          # Internal state props, maybe?
          optional(:headers) => [header()],
          optional(:rows) => [row()],
          # :auto or list of widths/auto
          optional(:column_widths) => [:auto | [integer() | :auto]],
          optional(:theme) => map(),
          # Predefined or custom border chars
          optional(:border_style) => :single | :double | :none | map(),
          # Overall table width - ADDED COMMA
          optional(:width) => integer() | :auto,
          # Alignment per column
          optional(:alignments) => [:left | :center | :right | [atom()]]
        }

  # Tables are typically display-only, so state might be minimal or nil
  @type state :: map()

  @type t :: %{
          # props: props(), # Maybe remove direct props field if passed via render
          state: state(),
          # Or maybe attrs are merged into state? Need clarification
          id: String.t() | atom(),
          columns: list(),
          data: list(),
          style: map(),
          # Default set in init
          row_style: nil,
          # Default set in init
          cell_style: nil,
          header_style: %{bold: true},
          footer: nil,
          # Internal state
          scroll_top: 0,
          scroll_left: 0,
          focused_row: nil,
          focused_col: nil,
          max_height: nil,
          max_width: nil
        }

  defstruct id: nil,
            columns: [],
            data: [],
            style: %{},
            # Default set in init
            row_style: nil,
            # Default set in init
            cell_style: nil,
            header_style: %{bold: true},
            footer: nil,
            # Internal state
            scroll_top: 0,
            scroll_left: 0,
            focused_row: nil,
            focused_col: nil,
            max_height: nil,
            max_width: nil

  # --- Component Implementation ---

  @impl true
  def init(attrs) do
    # Initialize only internal state, not data/columns passed via macro
    id = Map.get(attrs, :id) || Raxol.Core.ID.generate()
    # Don't merge all attrs into state struct blindly
    internal_state = %{
      id: id,
      scroll_top: 0,
      scroll_left: 0,
      # ... other non-data internal defaults ...
      # Base style state, specific styles come from attrs
      style: %{}
    }

    {:ok, internal_state}
  end

  @impl true
  # No mount needed
  def mount(_state), do: {:ok, []}

  @impl true
  def update({:update_props, new_props}, state) do
    updated_state = Map.merge(state, Map.new(new_props))
    # Recalculate column widths if data or headers change
    updated_state = update_column_widths(updated_state)
    {:noreply, updated_state}
  end

  @impl true
  def update(message, state) do
    IO.inspect(message, label: "Unhandled Table update")
    {:noreply, state}
  end

  @impl true
  def handle_event(state, event, context) do
    # Get necessary info from context attrs
    attrs = context.attrs
    data = Map.get(attrs, :data, [])
    # Calculate max_height based on style in attrs
    component_style = Map.get(attrs, :style, %{})
    theme = context.theme
    theme_style_def = Theme.component_style(theme, :table)
    # Convert style definitions to Style structs before merging
    theme_style_struct = Raxol.Style.new(theme_style_def)
    component_style_struct = Raxol.Style.new(component_style)
    base_style = Raxol.Style.merge(theme_style_struct, component_style_struct)
    # Correctly access height from the layout field of the Style struct
    max_height = base_style.layout.height
    current_visible_height = visible_height(%{max_height: max_height})

    case event do
      {:keypress, :arrow_up} ->
        new_scroll_top = max(0, state.scroll_top - 1)
        {:noreply, %{state | scroll_top: new_scroll_top}}

      {:keypress, :arrow_down} ->
        # Use actual data length and visible height
        max_scroll = max(0, length(data) - current_visible_height)
        new_scroll_top = min(max_scroll, state.scroll_top + 1)
        {:noreply, %{state | scroll_top: new_scroll_top}}

      {:keypress, :page_up} ->
        page_size = current_visible_height
        new_scroll_top = max(0, state.scroll_top - page_size)
        {:noreply, %{state | scroll_top: new_scroll_top}}

      {:keypress, :page_down} ->
        max_scroll = max(0, length(data) - current_visible_height)
        page_size = current_visible_height
        new_scroll_top = min(max_scroll, state.scroll_top + page_size)
        {:noreply, %{state | scroll_top: new_scroll_top}}

      # TODO: Add horizontal scrolling, row/cell focus
      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def render(state, context) do
    # ** Crucial Change: Use attrs from context/state for data **
    # Attributes are typically passed via context
    attrs = context.attrs

    id = Map.get(attrs, :id)
    # Get the ORIGINAL data and columns config from attrs
    original_data = Map.get(attrs, :data, [])
    columns_config = Map.get(attrs, :columns, [])

    # Use style from attrs, merge with theme default
    component_style = Map.get(attrs, :style, %{})
    theme = context.theme

    # Handle different theme types
    theme_style_def = get_theme_style(theme, :table)

    # Convert style definitions to Style structs before merging
    theme_style_struct = Raxol.Style.new(theme_style_def)
    component_style_struct = Raxol.Style.new(component_style)
    base_style = Raxol.Style.merge(theme_style_struct, component_style_struct)

    # Use the Elements.table macro, passing the original data and columns definition
    # The Layout.Table module will extract headers and calculate layout.
    # The Renderer will handle displaying the correct visible portion based on scroll state (passed via attrs?).
    Elements.table(
      id: id,
      style: base_style,
      # Pass the ORIGINAL data
      data: original_data,
      # Pass the column definitions
      columns: columns_config,
      # Pass scroll state so Renderer can use it
      _scroll_top: state.scroll_top
    )
  end

  @impl true
  # No unmount needed
  def unmount(_state), do: :ok

  # --- Private Helpers ---

  # Removed unused helper
  # defp default_row_style(_row_data, _index), do: %{}
  # Removed unused helper
  # defp default_cell_style(_cell_data, _row_index, _col_index), do: %{}

  # Helper to get style property, handling list or map format
  defp get_style_prop(style, key) when is_list(style) do
    Keyword.get(style, key)
  end

  defp get_style_prop(style, key) when is_map(style) do
    Map.get(style, key)
  end

  defp get_style_prop(_, _), do: nil

  defp visible_height(state)
  # Effectively infinite if not set
  defp visible_height(%{max_height: nil}), do: 1_000_000
  # Subtract 1 for header row?
  # Needs border calculation too if borders take space
  # Corrected: Ensure height is at least 1 if set
  # Adjust for header, ensure min 1
  defp visible_height(%{max_height: h}) when is_integer(h) and h >= 1,
    do: max(1, h - 1)

  # Minimum 1 row if height is set
  defp visible_height(%{max_height: _}), do: 1

  defp update_column_widths(state) do
    # Calculate widths based on headers and potentially sample data rows
    # TODO: This state update might not be necessary if widths calculated in render
    header_widths =
      case state.headers do
        nil -> []
        [] -> []
        headers when is_list(headers) -> Enum.map(headers, &str_width/1)
        _ -> []
      end

    # TODO: Sample data rows for more accurate widths?
    # For now, just use header widths
    %{state | column_widths: header_widths}
  end

  # Calculate string width, handling wide characters
  defp str_width(str) when is_binary(str) do
    String.length(str)
  end

  defp str_width(value) do
    value |> to_string() |> String.length()
  end

  # Helper to get theme style for either Theme type
  defp get_theme_style(theme, component_type) do
    cond do
      # Check for Raxol.UI.Theming.Theme
      is_map(theme) && Map.has_key?(theme, :component_styles) ->
        Map.get(theme.component_styles, component_type, %{})

      # Check for Raxol.Style.Colors.Theme
      is_map(theme) && Map.has_key?(theme, :palette) ->
        %{
          header_fg: :cyan,
          header_bg: :default,
          row_fg: :default,
          row_bg: :default,
          alternate_row_bg: :default,
          # Return a default border struct instead of just an atom
          border: %Raxol.Style.Borders{color: :white, style: :solid, width: 1}
        }

      # Fallback
      true ->
        %{}
    end
  end
end
