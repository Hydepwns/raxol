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
            theme: nil,
            mounted: false,
            render_count: 0

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
  def mount(state) do
    {state, []}
  end

  @spec update(term(), map()) :: {:ok, map()}
  @doc """
  Updates the table state based on the given message.
  """
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

  @spec render(map()) :: any()
  @doc """
  Renders the table component with the given state.
  """
  def render(state) do
    render(state, %{})
  end

  @spec render(map(), map()) :: any()
  @doc """
  Renders the table component with the given state and context.
  """
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
        Raxol.Core.Renderer.View.flex direction: :column do
          rows
        end,
        Raxol.Core.Renderer.View.flex direction: :row,
                                      justify: :space_between do
          pagination
        end
      ]
    )
  end

  @spec handle_event(term(), map(), map()) :: {:ok, map()}
  @doc """
  Handles events for the table component.
  """
  def handle_event(event, state, _context) do
    case event do
      {:filter, term} ->
        update({:filter, term}, state)

      {:sort, column} ->
        update({:sort, column}, state)

      {:set_page, page} ->
        update({:set_page, page}, state)

      {:select_row, row_index} ->
        update({:select_row, row_index}, state)

      _ ->
        {:ok, state}
    end
  end

  @spec unmount(map()) :: :ok
  def unmount(_state) do
    :ok
  end

  # Private helper functions

  defp filter_data(data, term) when term == "" or is_nil(term), do: data

  defp filter_data(data, term) do
    term = String.downcase(term)

    Enum.filter(data, fn row ->
      Enum.any?(row, fn {_key, value} ->
        value
        |> to_string()
        |> String.downcase()
        |> String.contains?(term)
      end)
    end)
  end

  defp sort_data(data, nil, _direction), do: data

  defp sort_data(data, column, direction) do
    Enum.sort_by(data, fn row ->
      value = Map.get(row, column)
      if direction == :asc, do: value, else: {:desc, value}
    end)
  end

  defp paginate_data(data, page, page_size) do
    start_index = (page - 1) * page_size
    end_index = start_index + page_size - 1

    data
    |> Enum.with_index()
    |> Enum.filter(fn {_item, index} ->
      index >= start_index and index <= end_index
    end)
    |> Enum.map(fn {item, _index} -> item end)
  end

  defp create_header(columns, state) do
    theme = state.theme || %{}
    style = state.style || %{}
    header_style = Map.get(style, :header, %{})

    Raxol.Core.Renderer.View.flex direction: :row,
                                  style:
                                    Map.merge(
                                      Map.get(theme, :header, %{}),
                                      header_style
                                    ) do
      Enum.map(columns, fn column ->
        Raxol.Core.Renderer.View.text(
          column.label,
          style:
            Map.merge(
              Map.get(theme, :header, %{}),
              Map.get(column, :header_style, %{})
            )
        )
      end)
    end
  end

  defp create_rows(rows, columns, selected_row, state) do
    theme = state.theme || %{}
    row_style = Map.get(theme, :row, %{})
    selected_style = Map.get(theme, :selected_row, %{})

    Enum.map(rows, fn row ->
      style =
        if row == selected_row,
          do: Map.merge(row_style, selected_style),
          else: row_style

      Raxol.Core.Renderer.View.flex direction: :row,
                                    style: style do
        Enum.map(columns, fn column ->
          value = Map.get(row, column.id)
          formatted_value = format_value(value, column)

          Raxol.Core.Renderer.View.text(
            formatted_value,
            style:
              Map.merge(
                row_style,
                Map.get(column, :style, %{})
              )
          )
        end)
      end
    end)
  end

  defp create_pagination(state) do
    filtered_data = filter_data(state.data, state.filter_term)
    total_pages = max(1, ceil(length(filtered_data) / state.page_size))

    [
      Raxol.Core.Renderer.View.button(
        "Previous",
        on_click: {:set_page, state.current_page - 1},
        disabled: state.current_page <= 1
      ),
      Raxol.Core.Renderer.View.text(
        "Page #{state.current_page} of #{total_pages}"
      ),
      Raxol.Core.Renderer.View.button(
        "Next",
        on_click: {:set_page, state.current_page + 1},
        disabled: state.current_page >= total_pages
      )
    ]
  end

  defp format_value(value, column) do
    case column do
      %{format: format} when is_function(format, 1) -> format.(value)
      _ -> to_string(value)
    end
  end
end
