defmodule Raxol.UI.Components.Table do
  use Surface.Component
  require Raxol.Core.Renderer.View

  @moduledoc """
  Table component for displaying and interacting with tabular data.

  ## Features
  * Pagination
  * Sorting
  * Filtering
  * Custom column formatting
  * Row selection
  * **Custom theming and styling** (see below)

  ## Public API

  ### Props
  - `:id` (required): Unique identifier for the table.
  - `:columns` (required): List of column definitions. Each column is a map with:
    - `:id` (atom, required): Key for the column.
    - `:label` (string, required): Header label.
    - `:width` (integer or `:auto`, optional): Column width.
    - `:align` (`:left` | `:center` | `:right`, optional): Text alignment.
    - `:format` (function, optional): Custom formatting function for cell values.
    - `:style` (map, optional): Style overrides for all cells in this column.
    - `:header_style` (map, optional): Style overrides for this column's header cell.
  - `:data` (required): List of row maps (each map must have keys matching column ids).
  - `:options` (map, optional):
    - `:paginate` (boolean): Enable pagination.
    - `:searchable` (boolean): Enable filtering.
    - `:sortable` (boolean): Enable sorting.
    - `:page_size` (integer): Rows per page.
  - `:style` (map, optional): Style overrides for the table box and header (see below).
    - `:header` (map, optional): Style overrides for all header cells.
  - `:theme` (map, optional): Theme map for the table. Keys can include:
    - `:box` (map): Style for the outer box.
    - `:header` (map): Style for all header cells.
    - `:row` (map): Style for all rows.
    - `:selected_row` (map): Style for the selected row.

  ### Theming and Style Precedence
  - Per-column `:style` and `:header_style` override theme and table-level styles for their respective cells.
  - `:style` prop overrides theme for the box and header.
  - `:theme` provides defaults for box, header, row, and selected row.
  - Hardcoded defaults (e.g., header bold, selected row blue/white) are used if not overridden.

  ### Example: Custom Theming and Styling
  ```elixir
  columns = [
    %{id: :id, label: "ID", style: %{color: :magenta}, header_style: %{bg: :cyan}},
    %{id: :name, label: "Name"},
    %{id: :age, label: "Age"}
  ]
  data = [%{id: 1, name: "Alice", age: 30}, ...]
  theme = %{
    box: %{border_color: :green},
    header: %{underline: true},
    row: %{bg: :yellow},
    selected_row: %{bg: :red, fg: :black}
  }
  style = %{header: %{italic: true}}

  Table.init(%{
    id: :my_table,
    columns: columns,
    data: data,
    theme: theme,
    style: style,
    options: %{paginate: true, page_size: 5}
  })
  ```

  """

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
            selected_row: nil,
            style: %{},
            theme: nil

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

  @spec init(map()) :: {:ok, map()}
  @doc """
  Initializes the table component with the given props.
  """
  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    id = Map.get(props, :id, :table)
    columns = Map.get(props, :columns, [])
    data = Map.get(props, :data, [])

    options =
      Map.get(props, :options, %{
        paginate: false,
        searchable: false,
        sortable: false,
        page_size: 10
      })

    style = Map.get(props, :style, %{})
    theme = Map.get(props, :theme, nil)

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
      selected_row: nil,
      style: style,
      theme: theme
    }

    {:ok, state}
  end

  @spec mount(map()) :: {map(), list()}
  @impl Raxol.UI.Components.Base.Component
  def mount(state) do
    {state, []}
  end

  @spec update(term(), map()) :: {:ok, map()}
  @doc """
  Updates the table state based on the given message.
  """
  @impl Raxol.UI.Components.Base.Component
  def update({:filter, term}, state) do
    new_state = %{state | filter_term: term, current_page: 1, scroll_top: 0}
    {:ok, new_state}
  end

  def update({:sort, column}, state) do
    new_direction =
      if state.sort_by == column && state.sort_direction == :asc,
        do: :desc,
        else: :asc

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

  @spec render(map(), map()) :: any()
  @doc """
  Renders the table component.
  """
  @impl true
  def render(state, _context) do
    theme = state.theme || %{}
    style = state.style || %{}

    box_style =
      Map.merge(
        Map.get(theme, :box, %{}),
        style
      )

    # Apply filtering
    filtered_data = filter_data(state.data, state.filter_term)

    # Apply sorting
    sorted_data = sort_data(filtered_data, state.sort_by, state.sort_direction)

    # Apply pagination
    paginated_data =
      paginate_data(sorted_data, state.current_page, state.page_size)

    # Create header
    header = create_header(state.columns, state)

    # Create rows
    rows = create_rows(paginated_data, state.columns, state.selected_row, state)

    # Create pagination controls if enabled
    pagination =
      if state.options.paginate, do: create_pagination(state), else: []

    Raxol.Core.Renderer.View.box(
      border: :single,
      style: box_style,
      children: [
        header,
        Raxol.Core.Renderer.View.flex(
          direction: :column,
          do: rows
        ),
        Raxol.Core.Renderer.View.flex(
          direction: :row,
          justify: :space_between,
          do: pagination
        )
      ]
    )
  end

  @spec handle_event(term(), map(), map()) :: {:ok, map()}
  @doc """
  Handles events for the table component.
  """
  @impl Raxol.UI.Components.Base.Component
  def handle_event({:key, {:arrow_down, _}}, _context, state) do
    new_index = min(state.selected_row + 1, length(state.data) - 1)
    {:ok, %{state | selected_row: new_index}}
  end

  def handle_event({:key, {:arrow_up, _}}, _context, state) do
    new_index = max(state.selected_row - 1, 0)
    {:ok, %{state | selected_row: new_index}}
  end

  def handle_event({:key, {:page_down, _}}, _context, state) do
    new_index =
      min(state.selected_row + state.page_size, length(state.data) - 1)

    {:ok, %{state | selected_row: new_index}}
  end

  def handle_event({:key, {:page_up, _}}, _context, state) do
    new_index = max(state.selected_row - state.page_size, 0)
    {:ok, %{state | selected_row: new_index}}
  end

  def handle_event({:key, {:home, _}}, _context, state) do
    {:ok, %{state | selected_row: 0}}
  end

  def handle_event({:key, {:end, _}}, _context, state) do
    {:ok, %{state | selected_row: length(state.data) - 1}}
  end

  def handle_event({:key, {:enter, _}}, _context, state) do
    if state.selected_row do
      {:ok, state}
    else
      {:ok, state}
    end
  end

  def handle_event({:key, {:escape, _}}, _context, state) do
    {:ok, %{state | selected_row: nil}}
  end

  def handle_event({:key, {:backspace, _}}, _context, state) do
    if state.options.searchable do
      new_term = String.slice(state.filter_term, 0..-2//-1)
      {:ok, %{state | filter_term: new_term, current_page: 1}}
    else
      {:ok, state}
    end
  end

  def handle_event({:key, {:char, char}}, _context, state) do
    if state.options.searchable do
      new_term = state.filter_term <> char
      {:ok, %{state | filter_term: new_term, current_page: 1}}
    else
      {:ok, state}
    end
  end

  def handle_event({:mouse, {:click, {_x, y}}}, _context, state) do
    # Calculate row index based on y position
    # Assuming each row is 1 unit high
    row_index = div(y - 1, 1)

    if row_index >= 0 and row_index < length(state.data) do
      {:ok, %{state | selected_row: row_index}}
    else
      {:ok, state}
    end
  end

  def handle_event(_event, _context, state), do: {:ok, state}

  @spec unmount(map()) :: map()
  @impl Raxol.UI.Components.Base.Component
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
    theme = state.theme || %{}

    header_style =
      Map.merge(
        Map.get(theme, :header, %{}),
        Map.get(state.style, :header, %{})
      )

    header_cells =
      Enum.map(columns, fn column ->
        content =
          if state.options.sortable do
            "#{column.label} #{sort_indicator(state.sort_by, state.sort_direction, column.id)}"
          else
            column.label
          end

        cell_style =
          Map.merge(header_style, Map.get(column, :header_style, %{}))

        Raxol.Core.Renderer.View.text(
          content,
          style: [:bold | Enum.uniq(Keyword.keys(cell_style))],
          align: column.align
        )
      end)

    Raxol.Core.Renderer.View.flex(
      direction: :row,
      do: header_cells
    )
  end

  defp create_rows(data, columns, selected_row, state) do
    theme = state.theme || %{}
    row_style = Map.get(theme, :row, %{})
    selected_row_style = Map.get(theme, :selected_row, %{bg: :blue, fg: :white})

    Enum.map(Enum.with_index(data), fn {row, index} ->
      cells =
        create_cells(
          row,
          columns,
          index,
          selected_row,
          row_style,
          selected_row_style
        )

      Raxol.Core.Renderer.View.flex(
        direction: :row,
        do: cells
      )
    end)
  end

  defp create_cells(
         row,
         columns,
         index,
         selected_row,
         row_style,
         selected_row_style
       ) do
    Enum.map(columns, fn column ->
      value = row[column.id]

      formatted =
        if column.format, do: column.format.(value), else: to_string(value)

      style =
        determine_cell_style(
          column,
          row_style,
          selected_row_style,
          index,
          selected_row
        )

      Raxol.Core.Renderer.View.text(
        formatted,
        align: column.align,
        style: Enum.uniq(Keyword.keys(style))
      )
    end)
  end

  defp determine_cell_style(
         column,
         row_style,
         selected_row_style,
         index,
         selected_row
       ) do
    base_style = Map.merge(row_style, Map.get(column, :style, %{}))

    if index == selected_row do
      Map.merge(base_style, selected_row_style)
    else
      base_style
    end
  end

  defp create_pagination(state) do
    filtered_data = filter_data(state.data, state.filter_term)
    max_page = max(1, ceil(length(filtered_data) / state.page_size))

    Raxol.Core.Renderer.View.flex(
      direction: :row,
      align: :center,
      gap: 2,
      do: [
        Raxol.Core.Renderer.View.text(
          "Page #{state.current_page} of #{max_page}"
        ),
        Raxol.Core.Renderer.View.flex(
          direction: :row,
          gap: 1,
          do: [
            Raxol.Core.Renderer.View.text("←", id: "test_table_prev_page"),
            Raxol.Core.Renderer.View.text("→", id: "test_table_next_page")
          ]
        )
      ]
    )
  end

  defp sort_indicator(sort_by, sort_direction, column_id) do
    cond do
      sort_by != column_id -> ""
      sort_direction == :asc -> "↑"
      sort_direction == :desc -> "↓"
    end
  end

  @impl true
  def render(state) do
    render(state, %{})
  end
end
