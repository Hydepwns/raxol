defmodule Raxol.UI.Components.Display.Table do
  @moduledoc """
  A component for displaying tabular data with sorting, filtering, and pagination.
  """
  # alias Raxol.UI.Components.Base.Component # Unused
  # alias Raxol.UI.Style
  # alias Raxol.UI.Element
  # alias Raxol.UI.Layout.Constraints # Unused
  # alias Raxol.UI.Theme
  # alias Raxol.Terminal.Cell # Unused

  require Logger

  alias Raxol.Core.Renderer.Element
  alias Raxol.UI.Theming.Theme

  @behaviour Raxol.UI.Components.Base.Component

  @type header :: String.t()
  # Allow various cell types
  @type cell :: String.t() | number() | atom()
  @type row :: [cell()]
  @type headers :: [header()]
  @type rows :: [row()]
  @type props :: %{
          optional(:id) => String.t(),
          headers => [header()],
          rows => [row()],
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
          props: props(),
          state: state()
        }

  defstruct [
    id: nil,
    headers: [],
    rows: [],
    style: %{},
    row_style: nil, # Default set in init
    cell_style: nil, # Default set in init
    header_style: %{bold: true},
    footer: nil,
    # Internal state
    column_widths: [],
    scroll_top: 0,
    scroll_left: 0,
    focused_row: nil,
    focused_col: nil,
    max_height: nil,
    max_width: nil
  ]

  # --- Component Implementation ---

  @impl true
  def init(props) do
    id = props[:id] || Raxol.Core.ID.generate()
    # Merge props first to allow overrides
    initial_state = Keyword.merge([id: id], props)
    state = struct!(__MODULE__, initial_state)

    # Set default style functions if not provided
    state = %{
      state
      | row_style: Map.get(initial_state, :row_style, &default_row_style/2),
        cell_style: Map.get(initial_state, :cell_style, &default_cell_style/3)
    }

    state = update_column_widths(state)
    {:ok, state}
  end

  @impl true
  def mount(_state), do: {:ok, []} # No mount needed

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
  def handle_event(state, event, _context) do
    case event do
      {:keypress, :arrow_up} ->
        new_scroll_top = max(0, state.scroll_top - 1)
        {:noreply, %{state | scroll_top: new_scroll_top}}

      {:keypress, :arrow_down} ->
        max_scroll = max(0, length(state.rows) - visible_height(state))
        new_scroll_top = min(max_scroll, state.scroll_top + 1)
        {:noreply, %{state | scroll_top: new_scroll_top}}

      {:keypress, :page_up} ->
        page_size = visible_height(state)
        new_scroll_top = max(0, state.scroll_top - page_size)
        {:noreply, %{state | scroll_top: new_scroll_top}}

      {:keypress, :page_down} ->
        max_scroll = max(0, length(state.rows) - visible_height(state))
        page_size = visible_height(state)
        new_scroll_top = min(max_scroll, state.scroll_top + page_size)
        {:noreply, %{state | scroll_top: new_scroll_top}}

      # TODO: Add horizontal scrolling, row/cell focus
      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def render(state, context) do
    theme = context.theme
    component_theme_style = Theme.component_style(theme, :table)
    base_style = Raxol.Style.merge(component_theme_style, state.style)

    # Calculate visible rows/cols based on scroll and max_height/max_width
    _visible_rows_data = Enum.slice(state.rows, state.scroll_top, visible_height(state))

    header_element = render_header(state, theme)
    row_elements = render_rows(state, theme, base_style)
    # footer_elements = render_footer(state, base_style)

    Element.new(
      :vbox,
      %{style: base_style, id: state.id},
      [header_element | row_elements]
    )
  end

  @impl true
  def unmount(_state), do: :ok # No unmount needed

  # --- Private Helpers ---

  defp default_row_style(_row_data, _index), do: %{}
  defp default_cell_style(_cell_data, _row_index, _col_index), do: %{}

  defp visible_height(state)
  defp visible_height(%{max_height: nil}), do: 1_000_000 # Effectively infinite
  defp visible_height(%{max_height: h}) when is_integer(h), do: h

  defp update_column_widths(state) do
    # Calculate widths based on headers and potentially sample data rows
    header_widths = Enum.map(state.headers, &str_width/1)
    # TODO: Sample data rows for more accurate widths?
    # For now, just use header widths
    %{state | column_widths: header_widths}
  end

  defp str_width(s) when is_binary(s), do: String.length(s)
  defp str_width(_), do: 0

  defp render_header(state, theme) do
    header_style = Map.get(state.style, :header, %{})
    component_theme_style = Theme.component_style(theme, :table_header)
    style = Raxol.Style.merge(component_theme_style, header_style)
    [render_row(state.headers, state.columns, style, -1, state.id)]
  end

  defp render_rows(state, _theme, base_style) do
    row_style = Map.get(state.style, :row, %{})
    alt_row_style = Map.get(state.style, :alternate_row, row_style)

    Enum.with_index(state.rows, fn row_data, index ->
      actual_index = index + state.scroll_top

      # Determine style: alternating or standard
      applied_row_style =
        if rem(actual_index, 2) == 1 and alt_row_style != %{} do
          alt_row_style
        else
          row_style
        end

      # Merge base style with the determined row style
      style = Raxol.Style.merge(base_style, applied_row_style)
      render_row(row_data, state.columns, style, actual_index, state.id)
    end)
  end

  defp render_row(row_data, columns, style, row_index, table_id) do
    cell_elements =
      Enum.with_index(row_data, fn cell_data, col_index ->
        column_config = Enum.at(columns, col_index, %{}) # Default to empty map if index out of bounds
        render_cell(cell_data, column_config, style)
      end)

    Element.new(
      :hbox,
      %{style: style, id: "#{table_id}-row-#{row_index}"},
      cell_elements
    )
  end

  defp render_cell(cell_data, column_config, style) do
    cell_style = Map.get(column_config, :style, %{})
    final_style = Raxol.Style.merge(style, cell_style)
    Element.new(:text, %{style: final_style}, to_string(cell_data))
  end
end
