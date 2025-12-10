defmodule Raxol.UI.Components.Display.Table do
  @moduledoc """
  A component for displaying tabular data with sorting, filtering, and pagination.
  """

  require Raxol.Core.Runtime.Log

  # alias Raxol.Core.Renderer.Element
  alias Raxol.UI.Theming.Theme
  alias Raxol.View.Elements

  @behaviour Raxol.UI.Components.Base.Component

  @type header :: String.t()
  # Allow various cell types
  @type cell :: String.t() | number() | atom()
  @type message :: term()
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
          optional(:alignments) => [:left | :center | :right | [atom()]],
          optional(:sortable) => boolean(),
          optional(:filterable) => boolean(),
          optional(:selectable) => boolean(),
          optional(:striped) => boolean(),
          optional(:selected) => integer() | nil,
          optional(:type) => :table | :header | :footer,
          optional(:focused) => boolean(),
          optional(:disabled) => boolean()
        }

  # Tables are typically display-only, so state might be minimal or nil
  @type state :: %{
          id: String.t() | atom(),
          columns: list(),
          data: list(),
          style: map(),
          row_style: map() | nil,
          cell_style: map() | nil,
          header_style: map(),
          footer: map() | nil,
          scroll_top: integer(),
          scroll_left: integer(),
          focused_row: integer() | nil,
          focused_col: integer() | nil,
          max_height: integer() | nil,
          max_width: integer() | nil,
          sort_by: atom() | nil,
          sort_direction: :asc | :desc | nil,
          filter_term: String.t(),
          selected_row: integer() | nil,
          striped: boolean(),
          border_style: :single | :double | :none | map(),
          mounted: boolean(),
          render_count: integer(),
          type: :table | :header | :footer,
          focused: boolean(),
          disabled: boolean()
        }

  defstruct id: nil,
            columns: [],
            data: [],
            style: %{},
            row_style: nil,
            cell_style: nil,
            header_style: %{bold: true},
            footer: nil,
            scroll_top: 0,
            scroll_left: 0,
            focused_row: nil,
            focused_col: nil,
            max_height: nil,
            max_width: nil,
            sort_by: nil,
            sort_direction: nil,
            filter_term: "",
            selected_row: nil,
            striped: true,
            border_style: :single,
            mounted: false,
            render_count: 0,
            type: :table,
            focused: false,
            disabled: false

  # --- Component Implementation ---

  @doc "Initializes the Table component state from props."
  @spec init(props()) :: %__MODULE__{}
  @impl Raxol.UI.Components.Base.Component
  def init(attrs) do
    id = Map.get(attrs, :id) || Raxol.Core.ID.generate()

    # Initialize all state fields with proper defaults
    internal_state = %__MODULE__{
      id: id,
      columns: Map.get(attrs, :columns, []),
      data: Map.get(attrs, :data, []),
      style: Map.get(attrs, :style, %{}),
      row_style: Map.get(attrs, :row_style),
      cell_style: Map.get(attrs, :cell_style),
      header_style: Map.get(attrs, :header_style, %{bold: true}),
      footer: Map.get(attrs, :footer),
      scroll_top: 0,
      scroll_left: 0,
      focused_row: nil,
      focused_col: nil,
      max_height: Map.get(attrs, :max_height),
      max_width: Map.get(attrs, :max_width),
      sort_by: nil,
      sort_direction: nil,
      filter_term: "",
      selected_row: Map.get(attrs, :selected),
      striped: Map.get(attrs, :striped, true),
      border_style: Map.get(attrs, :border_style, :single),
      type: :table,
      focused: Map.get(attrs, :focused, false),
      disabled: Map.get(attrs, :disabled, false)
    }

    internal_state
  end

  @doc "Mounts the Table component, performing any setup needed."
  @spec mount(state()) :: {state(), [term()]}
  @impl Raxol.UI.Components.Base.Component
  def mount(state) do
    # Initialize any subscriptions or setup needed
    {state, []}
  end

  @doc "Updates the Table component state in response to messages. Handles prop updates, sorting, filtering, and selection."
  @spec update(message(), state()) :: state()
  @impl Raxol.UI.Components.Base.Component
  def update(message, state) do
    case message do
      {:update_props, new_props} ->
        # Update state with new props while preserving internal state
        updated_state = Map.merge(state, Map.new(new_props))
        # Recalculate column widths if data or headers change
        update_column_widths(updated_state)

      {:sort, column} ->
        new_direction =
          determine_sort_direction(state.sort_by, state.sort_direction, column)

        %{
          state
          | sort_by: column,
            sort_direction: new_direction
        }

      {:filter, term} ->
        %{state | filter_term: term}

      {:select_row, row_index} ->
        %{state | selected_row: row_index}

      _ ->
        _ =
          Raxol.Core.Runtime.Log.warning(
            "Unhandled Table update: #{inspect(message)}"
          )

        state
    end
  end

  @doc "Handles events for the Table component."
  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, state, context) do
    attrs = context.attrs
    current_visible_height = get_visible_height(context)

    result =
      case event do
        {:keypress, key} ->
          handle_keypress(state, key, attrs, current_visible_height)

        {:click, click_data} ->
          handle_click(state, click_data, attrs)

        {:input, input_data} ->
          handle_input(state, input_data, attrs)

        {:focus, focus_data} ->
          handle_focus(state, focus_data)

        _ ->
          {:noreply, state}
      end

    # Convert {:noreply, state} to expected format, pass through other results
    case result do
      {:noreply, new_state} ->
        {new_state, []}

      other ->
        other
    end
  end

  @doc "Renders the Table component."
  @spec render(state(), map()) :: any()
  @impl Raxol.UI.Components.Base.Component
  def render(state, context) do
    attrs = context.attrs
    id = Map.get(attrs, :id)
    original_data = Map.get(attrs, :data, [])
    columns_config = Map.get(attrs, :columns, [])

    # Process data based on current state
    processed_data = process_data(original_data, state)

    # Use style from attrs, merge with theme default
    component_style = Map.get(attrs, :style, %{})
    theme = context.theme
    theme_style_def = get_theme_style(theme, :table)
    theme_style_struct = Raxol.Style.new(theme_style_def)
    component_style_struct = Raxol.Style.new(component_style)
    base_style = Raxol.Style.merge(theme_style_struct, component_style_struct)

    # Apply border style
    base_style = apply_border_style(base_style, state.border_style)

    # Apply row styles
    row_styles = get_row_styles(state)

    table_element =
      Elements.table(
        id: id,
        style: base_style,
        data: processed_data,
        columns: columns_config,
        _scroll_top: state.scroll_top,
        _selected_row: state.selected_row,
        _focused_row: state.focused_row,
        _focused_col: state.focused_col,
        _row_styles: row_styles,
        _header_style: state.header_style
      )

    # At the end of render, ensure :disabled and :focused are present in the returned map if possible
    ensure_disabled_focused(table_element, state)
  end

  @spec unmount(state()) :: state()
  @impl Raxol.UI.Components.Base.Component
  def unmount(state) do
    # Clean up any resources
    state
  end

  # --- Private Helpers ---

  # Removed unused helper
  # defp default_row_style(_row_data, _index), do: %{}
  # Removed unused helper
  # defp default_cell_style(_cell_data, _row_index, _col_index), do: %{}

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
    header_widths = calculate_header_widths(state.columns)
    data_widths = calculate_data_widths(state.data, state.columns)
    column_widths = Enum.zip_with(header_widths, data_widths, &max/2)
    %{state | column_widths: column_widths}
  end

  defp calculate_header_widths(nil), do: []
  defp calculate_header_widths([]), do: []

  defp calculate_header_widths(columns) when is_list(columns) do
    Enum.map(columns, fn col -> String.length(Map.get(col, :header, "")) end)
  end

  defp calculate_header_widths(_), do: []

  defp calculate_data_widths(nil, _columns), do: []
  defp calculate_data_widths([], _columns), do: []

  defp calculate_data_widths(data, columns)
       when is_list(data) and is_list(columns) do
    Enum.reduce(data, List.duplicate(0, length(columns)), fn row, acc ->
      Enum.zip_with(acc, columns, fn max_width, col ->
        value = Map.get(row, Map.get(col, :key))
        max(max_width, String.length(to_string(value)))
      end)
    end)
  end

  defp calculate_data_widths(_, _), do: []

  defp determine_sort_direction(current_sort_by, _current_direction, new_column)
       when current_sort_by != new_column,
       do: :asc

  defp determine_sort_direction(_current_sort_by, :asc, _new_column), do: :desc

  defp determine_sort_direction(
         _current_sort_by,
         _current_direction,
         _new_column
       ),
       do: :asc

  defp process_data(data, state) do
    data
    |> filter_data(state.filter_term)
    |> sort_data(state.sort_by, state.sort_direction)
  end

  defp filter_data(data, ""), do: data

  defp filter_data(data, term) do
    term = String.downcase(term)

    Enum.filter(data, fn row ->
      Enum.any?(row, fn {_key, value} ->
        String.contains?(String.downcase(to_string(value)), term)
      end)
    end)
  end

  defp sort_data(data, nil, _direction), do: data

  defp sort_data(data, column, direction) do
    Enum.sort_by(data, fn row ->
      value = Map.get(row, column)

      case direction do
        :asc -> value
        _ -> -value
      end
    end)
  end

  # Helper to get theme style for either Theme type
  defp get_theme_style(%Raxol.UI.Theming.Theme{} = theme, component_type) do
    Raxol.UI.Theming.Theme.get_component_style(theme, component_type)
  end

  defp get_theme_style(%{component_styles: _} = theme, component_type) do
    Raxol.UI.Theming.Theme.get_component_style(theme, component_type)
  end

  defp get_theme_style(_theme, _component_type), do: %{}

  defp apply_border_style(style, :none) do
    %{style | border: %{style.border | style: :none, width: 0}}
  end

  defp apply_border_style(style, :single) do
    %{style | border: %{style.border | style: :solid, width: 1}}
  end

  defp apply_border_style(style, :solid) do
    %{style | border: %{style.border | style: :solid, width: 1}}
  end

  defp apply_border_style(style, :double) do
    %{style | border: %{style.border | style: :double, width: 1}}
  end

  defp apply_border_style(style, custom_border) when is_map(custom_border) do
    %{style | border: Map.merge(style.border, custom_border)}
  end

  defp get_row_styles(state) do
    fn index, _row ->
      get_row_style_for_index(state, index)
    end
  end

  defp get_row_style_for_index(%{selected_row: index} = _state, index) do
    [bg: :blue, fg: :white]
  end

  defp get_row_style_for_index(%{striped: true} = _state, index)
       when rem(index, 2) == 1 do
    [bg: :bright_black]
  end

  defp get_row_style_for_index(_state, _index), do: []

  defp ensure_disabled_focused(element, state) do
    # element is always a map based on upstream type constraints
    element
    |> Map.put_new(:disabled, Map.get(state, :disabled, false))
    |> Map.put_new(:focused, Map.get(state, :focused, false))
  end

  defp get_visible_height(context) do
    attrs = context.attrs
    component_style = Map.get(attrs, :style, %{})
    theme = context.theme
    theme_style_def = Theme.component_style(theme, :table)
    theme_style_struct = Raxol.Style.new(theme_style_def)
    component_style_struct = Raxol.Style.new(component_style)
    base_style = Raxol.Style.merge(theme_style_struct, component_style_struct)
    # Height is in layout.margin.height after Raxol.Style.merge
    max_height = Map.get(base_style.layout.margin, :height, nil)
    visible_height(%{max_height: max_height})
  end

  defp handle_keypress(state, key, attrs, current_visible_height) do
    data = Map.get(attrs, :data, [])

    case key do
      :arrow_up ->
        new_scroll_top = max(0, state.scroll_top - 1)
        {%{state | scroll_top: new_scroll_top}, []}

      :arrow_down ->
        max_scroll = max(0, length(data) - current_visible_height)
        new_scroll_top = min(max_scroll, state.scroll_top + 1)
        {%{state | scroll_top: new_scroll_top}, []}

      :page_up ->
        page_size = current_visible_height
        new_scroll_top = max(0, state.scroll_top - page_size)
        {%{state | scroll_top: new_scroll_top}, []}

      :page_down ->
        max_scroll = max(0, length(data) - current_visible_height)
        page_size = current_visible_height
        new_scroll_top = min(max_scroll, state.scroll_top + page_size)
        {%{state | scroll_top: new_scroll_top}, []}

      _ ->
        {state, []}
    end
  end

  defp handle_click(state, {:row, row_index}, attrs) do
    case Map.get(attrs, :selectable, false) do
      true ->
        {%{state | selected_row: row_index}, []}

      false ->
        {state, []}
    end
  end

  defp handle_click(state, {:header, column}, attrs) do
    case Map.get(attrs, :sortable, false) do
      true ->
        {state, [{:update, {:sort, column}}]}

      false ->
        {state, []}
    end
  end

  defp handle_input(state, {:filter, term}, attrs) do
    case Map.get(attrs, :filterable, false) do
      true ->
        {state, [{:update, {:filter, term}}]}

      false ->
        {state, []}
    end
  end

  defp handle_focus(state, {:row, row_index}) do
    {%{state | focused_row: row_index}, []}
  end

  defp handle_focus(state, {:cell, {row_index, col_index}}) do
    {%{state | focused_row: row_index, focused_col: col_index}, []}
  end
end
