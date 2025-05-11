defmodule Raxol.Components.Table do
  @moduledoc """
  Table component for displaying and interacting with tabular data.

  Features:
  * Pagination
  * Sorting
  * Filtering
  * Custom column formatting
  * Row selection
  """

  alias Raxol.Core.Renderer.View
  alias Raxol.Core.Renderer.Views.Table, as: TableView

  defstruct id: nil,
            columns: [],
            data: [],
            options: %{
              paginate: false,
              searchable: false,
              sortable: false,
              page_size: 10
            },
            current_page: 1,
            page_size: 10,
            filter_term: "",
            sort_by: nil,
            sort_direction: :asc,
            scroll_top: 0,
            selected_row: nil

  @type column :: %{
          id: atom(),
          label: String.t(),
          width: non_neg_integer() | :auto,
          align: :left | :center | :right,
          format: (term() -> String.t()) | nil
        }

  @type options :: %{
          paginate: boolean(),
          searchable: boolean(),
          sortable: boolean(),
          page_size: non_neg_integer()
        }

  @behaviour Raxol.UI.Components.Base.Component

  @doc """
  Initializes the table component with the given props.
  """
  def init(%{id: id, columns: columns, data: data} = props) do
    options = Map.get(props, :options, %{
      paginate: false,
      searchable: false,
      sortable: false,
      page_size: 10
    })

    state = %{
      id: id,
      columns: columns,
      data: data,
      options: options,
      current_page: 1,
      page_size: options.page_size,
      filter_term: "",
      sort_by: nil,
      sort_direction: :asc,
      scroll_top: 0,
      selected_row: nil
    }

    {:ok, state}
  end

  def mount(state) do
    {state, []}
  end

  @doc """
  Updates the table state based on the given message.
  """
  def update({:filter, term}, state) do
    new_state = %{state | filter_term: term, current_page: 1, scroll_top: 0}
    {:ok, new_state}
  end

  def update({:sort, column}, state) do
    new_direction = if state.sort_by == column && state.sort_direction == :asc, do: :desc, else: :asc
    new_state = %{state | sort_by: column, sort_direction: new_direction}
    {:ok, new_state}
  end

  def update({:set_page, page}, state) do
    filtered_data = filter_data(state.data, state.filter_term)
    max_page = max(1, ceil(length(filtered_data) / state.page_size))
    new_page = max(1, min(page, max_page))
    new_state = %{state | current_page: new_page, scroll_top: 0}
    {:ok, new_state}
  end

  def update({:select_row, row_index}, state) do
    new_state = %{state | selected_row: row_index}
    {:ok, new_state}
  end

  @doc """
  Renders the table component.
  """
  def render(state, _context) do
    # Apply filtering
    filtered_data = filter_data(state.data, state.filter_term)

    # Apply sorting
    sorted_data = sort_data(filtered_data, state.sort_by, state.sort_direction)

    # Apply pagination
    paginated_data = paginate_data(sorted_data, state.current_page, state.page_size)

    # Create header
    header = create_header(state.columns, state)

    # Create rows
    rows = create_rows(paginated_data, state.columns, state.selected_row)

    # Create pagination controls if enabled
    pagination = if state.options.paginate, do: create_pagination(state), else: []

    # Combine all elements
    Raxol.Core.Renderer.View.box(
      border: :single,
      children: [
        header,
        Raxol.Core.Renderer.View.flex(
          direction: :column,
          children: rows
        ),
        Raxol.Core.Renderer.View.flex(
          direction: :row,
          justify: :space_between,
          children: pagination
        )
      ]
    )
  end

  @doc """
  Handles events for the table component.
  """
  def handle_event({:key, {:arrow_down, _}}, _context, state) do
    filtered_data = filter_data(state.data, state.filter_term)
    visible_rows = state.page_size - 1  # Account for header
    max_scroll = max(0, length(filtered_data) - visible_rows)
    new_scroll = min(state.scroll_top + 1, max_scroll)
    new_state = %{state | scroll_top: new_scroll}

    # Update selected row if selection is enabled
    if state.selected_row != nil do
      new_selected = min(state.selected_row + 1, length(filtered_data) - 1)
      new_state = %{new_state | selected_row: new_selected}
    end

    {:ok, new_state}
  end

  def handle_event({:key, {:arrow_up, _}}, _context, state) do
    new_scroll = max(0, state.scroll_top - 1)
    new_state = %{state | scroll_top: new_scroll}

    # Update selected row if selection is enabled
    if state.selected_row != nil do
      new_selected = max(0, state.selected_row - 1)
      new_state = %{new_state | selected_row: new_selected}
    end

    {:ok, new_state}
  end

  def handle_event({:key, {:page_down, _}}, _context, state) do
    filtered_data = filter_data(state.data, state.filter_term)
    visible_rows = state.page_size - 1  # Account for header
    max_scroll = max(0, length(filtered_data) - visible_rows)
    new_scroll = min(state.scroll_top + visible_rows, max_scroll)
    new_state = %{state | scroll_top: new_scroll}

    # Update selected row if selection is enabled
    if state.selected_row != nil do
      new_selected = min(state.selected_row + visible_rows, length(filtered_data) - 1)
      new_state = %{new_state | selected_row: new_selected}
    end

    {:ok, new_state}
  end

  def handle_event({:key, {:page_up, _}}, _context, state) do
    visible_rows = state.page_size - 1  # Account for header
    new_scroll = max(0, state.scroll_top - visible_rows)
    new_state = %{state | scroll_top: new_scroll}

    # Update selected row if selection is enabled
    if state.selected_row != nil do
      new_selected = max(0, state.selected_row - visible_rows)
      new_state = %{new_state | selected_row: new_selected}
    end

    {:ok, new_state}
  end

  def handle_event({:mouse, {:click, {_x, y}}}, _context, state) do
    # Convert y coordinate to row index, accounting for header
    row_index = y - 1
    if row_index >= 0 and row_index < length(state.data) do
      {:ok, %{state | selected_row: row_index}}
    else
      {:ok, state}
    end
  end

  def handle_event({:button_click, button_id}, _context, state) do
    case button_id do
      "test_table_next_page" ->
        filtered_data = filter_data(state.data, state.filter_term)
        max_page = max(1, ceil(length(filtered_data) / state.page_size))
        new_page = min(state.current_page + 1, max_page)
        {:ok, %{state | current_page: new_page, scroll_top: 0}}

      "test_table_prev_page" ->
        new_page = max(1, state.current_page - 1)
        {:ok, %{state | current_page: new_page, scroll_top: 0}}

      "test_table_sort_" <> column ->
        column = String.to_existing_atom(column)
        new_direction = if state.sort_by == column && state.sort_direction == :asc, do: :desc, else: :asc
        {:ok, %{state | sort_by: column, sort_direction: new_direction}}

      _ ->
        {:ok, state}
    end
  end

  def unmount(state) do
    state
  end

  # Private Helpers

  defp filter_data(data, term) when term == "", do: data
  defp filter_data(data, term) do
    term = String.downcase(term)
    Enum.filter(data, fn row ->
      Enum.any?(row, fn {_key, value} ->
        to_string(value) |> String.downcase() |> String.contains?(term)
      end)
    end)
  end

  defp sort_data(data, nil, _direction), do: data
  defp sort_data(data, column, direction) do
    Enum.sort_by(data, fn row -> row[column] end, fn a, b ->
      case direction do
        :asc -> compare_values(a, b)
        :desc -> compare_values(b, a)
      end
    end)
  end

  defp compare_values(a, b) when is_number(a) and is_number(b), do: a <= b
  defp compare_values(a, b) when is_binary(a) and is_binary(b), do: a <= b
  defp compare_values(a, b) when is_atom(a) and is_atom(b), do: a <= b
  defp compare_values(a, b) when is_binary(a), do: to_string(a) <= to_string(b)
  defp compare_values(a, b) when is_binary(b), do: to_string(a) <= to_string(b)
  defp compare_values(a, b), do: to_string(a) <= to_string(b)

  defp paginate_data(data, page, page_size) do
    start_index = (page - 1) * page_size
    Enum.slice(data, start_index, page_size)
  end

  defp create_header(columns, state) do
    header_cells = Enum.map(columns, fn column ->
      content = if state.options.sortable do
        "#{column.label} #{sort_indicator(state.sort_by, state.sort_direction, column.id)}"
      else
        column.label
      end

      Raxol.Core.Renderer.View.text(
        content,
        style: [:bold],
        align: column.align
      )
    end)

    Raxol.Core.Renderer.View.flex(
      direction: :row,
      children: header_cells
    )
  end

  defp create_rows(data, columns, selected_row) do
    Enum.map(Enum.with_index(data), fn {row, index} ->
      cells = Enum.map(columns, fn column ->
        value = row[column.id]
        formatted = if column.format, do: column.format.(value), else: to_string(value)

        # Apply selection style if this row is selected
        style = if index == selected_row, do: [bg: :blue, fg: :white], else: []

        Raxol.Core.Renderer.View.text(
          formatted,
          align: column.align,
          style: style
        )
      end)

      Raxol.Core.Renderer.View.flex(
        direction: :row,
        children: cells
      )
    end)
  end

  defp create_pagination(state) do
    filtered_data = filter_data(state.data, state.filter_term)
    max_page = max(1, ceil(length(filtered_data) / state.page_size))
    [
      Raxol.Core.Renderer.View.text("Page #{state.current_page} of #{max_page}"),
      Raxol.Core.Renderer.View.flex(
        direction: :row,
        gap: 1,
        children: [
          Raxol.Core.Renderer.View.text("←", id: "test_table_prev_page"),
          Raxol.Core.Renderer.View.text("→", id: "test_table_next_page")
        ]
      )
    ]
  end

  defp sort_indicator(sort_by, sort_direction, column_id) do
    cond do
      sort_by != column_id -> ""
      sort_direction == :asc -> "↑"
      sort_direction == :desc -> "↓"
    end
  end
end
