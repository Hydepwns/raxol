defmodule Raxol.UI.Components.Display.Table do
  @moduledoc '''
  A component for displaying tabular data with sorting, filtering, and pagination.
  '''
  require Raxol.Core.Runtime.Log
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

  @doc 'Initializes the Table component state from props.'
  @spec init(map()) :: {:ok, state()}
  @impl true
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

    {:ok, internal_state}
  end

  @doc 'Mounts the Table component, performing any setup needed.'
  @spec mount(state()) :: {:ok, state(), list()}
  @impl true
  def mount(state) do
    # Initialize any subscriptions or setup needed
    {:ok, state, []}
  end

  @doc 'Updates the Table component state in response to messages. Handles prop updates, sorting, filtering, and selection.'
  @spec update(term(), state()) :: {:noreply, state()}
  @impl true
  def update(message, state) do
    case message do
      {:update_props, new_props} ->
        # Update state with new props while preserving internal state
        updated_state = Map.merge(state, Map.new(new_props))
        # Recalculate column widths if data or headers change
        updated_state = update_column_widths(updated_state)
        {:noreply, updated_state}

      {:sort, column} ->
        new_direction =
          if state.sort_by == column do
            if state.sort_direction == :asc, do: :desc, else: :asc
          else
            :asc
          end

        updated_state = %{
          state
          | sort_by: column,
            sort_direction: new_direction
        }

        {:noreply, updated_state}

      {:filter, term} ->
        updated_state = %{state | filter_term: term}
        {:noreply, updated_state}

      {:select_row, row_index} ->
        updated_state = %{state | selected_row: row_index}
        {:noreply, updated_state}

      _ ->
        Raxol.Core.Runtime.Log.warning(
          "Unhandled Table update: #{inspect(message)}"
        )

        {:noreply, state}
    end
  end

  @doc 'Handles events for the Table component.'
  @spec handle_event(state(), term(), map()) ::
          {:noreply, state()} | {:noreply, state(), list()}
  @impl true
  def handle_event(state, event, context) do
    attrs = context.attrs
    data = Map.get(attrs, :data, [])
    component_style = Map.get(attrs, :style, %{})
    theme = context.theme
    theme_style_def = Theme.component_style(theme, :table)
    theme_style_struct = Raxol.Style.new(theme_style_def)
    component_style_struct = Raxol.Style.new(component_style)
    base_style = Raxol.Style.merge(theme_style_struct, component_style_struct)
    max_height = base_style.layout.height
    current_visible_height = visible_height(%{max_height: max_height})

    case event do
      # Scrolling events
      {:keypress, :arrow_up} ->
        new_scroll_top = max(0, state.scroll_top - 1)
        {:noreply, %{state | scroll_top: new_scroll_top}}

      {:keypress, :arrow_down} ->
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

      # Row selection events
      {:click, {:row, row_index}} ->
        if Map.get(attrs, :selectable, false) do
          {:noreply, %{state | selected_row: row_index}}
        else
          {:noreply, state}
        end

      # Sorting events
      {:click, {:header, column}} ->
        if Map.get(attrs, :sortable, false) do
          {:noreply, state, [{:update, {:sort, column}}]}
        else
          {:noreply, state}
        end

      # Filtering events
      {:input, {:filter, term}} ->
        if Map.get(attrs, :filterable, false) do
          {:noreply, state, [{:update, {:filter, term}}]}
        else
          {:noreply, state}
        end

      # Focus events
      {:focus, {:row, row_index}} ->
        {:noreply, %{state | focused_row: row_index}}

      {:focus, {:cell, {row_index, col_index}}} ->
        {:noreply, %{state | focused_row: row_index, focused_col: col_index}}

      _ ->
        {:noreply, state}
    end
  end

  @doc 'Renders the Table component.'
  @spec render(state(), map()) :: any()
  @impl true
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

  @spec unmount(state()) :: {:ok, state()}
  @impl true
  def unmount(state) do
    # Clean up any resources
    {:ok, state}
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
    # Calculate widths based on headers and data
    header_widths =
      case state.columns do
        nil ->
          []

        [] ->
          []

        columns when is_list(columns) ->
          Enum.map(columns, fn col ->
            String.length(Map.get(col, :header, ""))
          end)

        _ ->
          []
      end

    data_widths =
      case state.data do
        nil ->
          []

        [] ->
          []

        data when is_list(data) ->
          Enum.reduce(data, List.duplicate(0, length(state.columns)), fn row,
                                                                         acc ->
            Enum.zip_with(acc, state.columns, fn max_width, col ->
              value = Map.get(row, Map.get(col, :key))
              max(max_width, String.length(to_string(value)))
            end)
          end)

        _ ->
          []
      end

    # Combine header and data widths
    column_widths = Enum.zip_with(header_widths, data_widths, &max/2)

    # Update state with calculated widths
    %{state | column_widths: column_widths}
  end

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
      if direction == :asc, do: value, else: -value
    end)
  end

  # Helper to get theme style for either Theme type
  defp get_theme_style(theme, component_type) do
    cond do
      is_struct(theme, Raxol.UI.Theming.Theme) ->
        Raxol.UI.Theming.Theme.get_component_style(theme, component_type)

      is_map(theme) and Map.has_key?(theme, :component_styles) ->
        Raxol.UI.Theming.Theme.get_component_style(theme, component_type)

      true ->
        %{}
    end
  end

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
      cond do
        # Selected row style
        state.selected_row == index ->
          [bg: :blue, fg: :white]

        # Striped row style
        state.striped and rem(index, 2) == 1 ->
          [bg: :bright_black]

        # Default row style
        true ->
          []
      end
    end
  end

  defp ensure_disabled_focused(element, state) do
    if is_map(element) do
      element
      |> Map.put_new(:disabled, Map.get(state, :disabled, false))
      |> Map.put_new(:focused, Map.get(state, :focused, false))
    else
      element
    end
  end
end
