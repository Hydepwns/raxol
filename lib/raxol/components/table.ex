defmodule Raxol.Components.Table do
  alias Raxol.View

  @moduledoc """
  Table component for displaying tabular data in terminal UI applications.

  This module provides a flexible table component with support for:
  - Custom column configurations
  - Row/column highlighting
  - Sorting
  - Selection
  - Pagination

  ## Examples

  ```elixir
  alias Raxol.Components.Table

  # Simple table with default configuration
  Table.render(
    [
      %{id: 1, name: "Alice", age: 32, role: "Developer"},
      %{id: 2, name: "Bob", age: 28, role: "Designer"},
      %{id: 3, name: "Charlie", age: 41, role: "Manager"}
    ],
    [:id, :name, :age, :role]
  )

  # Table with custom column config and sorting
  Table.render(
    model.users,
    [
      %{key: :id, label: "ID", width: 5},
      %{key: :name, label: "Full Name", width: 20},
      %{key: :age, label: "Age", width: 5, alignment: :right},
      %{key: :role, label: "Position", width: 15}
    ],
    selected: model.selected_user_id,
    sort_by: model.sort_column,
    sort_dir: model.sort_direction,
    on_sort: fn col -> {:sort, col} end,
    on_select: fn id -> {:select_user, id} end
  )
  """

  @doc """
  Renders a table with the provided data and columns.

  ## Parameters

  * `data` - List of maps, each representing a row of data
  * `columns` - List of column specifications (atoms or maps)
  * `opts` - Options for customizing the table appearance and behavior

  ## Column Specification

  Columns can be specified as:
  - A simple atom representing the key in the data maps
  - A map with the following possible keys:
    * `:key` - The key in the data maps (required)
    * `:label` - Column header text (defaults to string version of key)
    * `:width` - Column width in characters (optional)
    * `:min_width` - Minimum column width (optional)
    * `:max_width` - Maximum column width (optional)
    * `:alignment` - Text alignment (:left, :center, :right, default: :left)
    * `:format` - Function to format the cell value (fn value -> formatted_string end)
    * `:sortable` - Whether the column is sortable (default: true)
    * `:style` - Style for the column cells

  ## Options

  * `:id` - Table identifier (default: "table")
  * `:style` - Style for the table container
  * `:header_style` - Style for the header row
  * `:row_style` - Style for data rows
  * `:selected_style` - Style for the selected row
  * `:zebra_stripe` - Whether to use alternating row styles (default: true)
  * `:zebra_style` - Style for alternate rows when zebra striping
  * `:border` - Border style (:none, :simple, :heavy, default: :simple)
  * `:selected` - Value to match against for the selected row
  * `:select_key` - Key to use for selection matching (default: first column key)
  * `:on_select` - Function called when a row is selected
  * `:sort_by` - Key of the column to sort by
  * `:sort_dir` - Sort direction (:asc or :desc)
  * `:on_sort` - Function called when a sortable column header is clicked
  * `:max_height` - Maximum height of the table body
  * `:footer` - Function that renders a footer row or rows

  ## Returns

  A view element representing the table.

  ## Example

  ```elixir
  Table.render(
    users,
    [
      %{key: :id, label: "#", width: 5},
      %{key: :name, label: "Name", min_width: 10},
      %{key: :email, label: "Email Address", width: 25}
    ],
    selected: selected_user_id,
    on_select: &handle_user_selection/1,
    sort_by: :name,
    sort_dir: :asc,
    max_height: 10,
    zebra_stripe: true
  )
  ```
  """
  def render(data, columns, opts \\ []) do
    # Extract and normalize options
    id = Keyword.get(opts, :id, "table")
    style = Keyword.get(opts, :style, %{})
    header_style = Keyword.get(opts, :header_style, %{fg: :white, bold: true})
    row_style = Keyword.get(opts, :row_style, %{})

    selected_style =
      Keyword.get(opts, :selected_style, %{bg: :blue, fg: :white})

    zebra_stripe = Keyword.get(opts, :zebra_stripe, true)
    zebra_style = Keyword.get(opts, :zebra_style, %{bg: :black})
    border_style = Keyword.get(opts, :border, :simple)
    selected = Keyword.get(opts, :selected, nil)
    sort_by = Keyword.get(opts, :sort_by, nil)
    sort_dir = Keyword.get(opts, :sort_dir, :asc)
    on_sort = Keyword.get(opts, :on_sort, nil)
    on_select = Keyword.get(opts, :on_select, nil)
    max_height = Keyword.get(opts, :max_height, nil)
    footer_fn = Keyword.get(opts, :footer, nil)

    # Normalize columns into map format
    normalized_columns = normalize_columns(columns)

    # Determine select_key if not specified
    select_key =
      Keyword.get(
        opts,
        :select_key,
        case List.first(normalized_columns) do
          %{key: key} -> key
          _ -> nil
        end
      )

    # Sort data if sort parameters are provided
    sorted_data =
      if sort_by do
        Enum.sort_by(data, &Map.get(&1, sort_by), sort_dir)
      else
        data
      end

    # Apply border style
    table_style =
      case border_style do
        :simple -> Map.put(style, :border, "1px solid #ddd")
        :none -> style
        :thick -> Map.put(style, :border, "2px solid #333")
        _ -> Map.put(style, :border, "1px solid #ddd")
      end

    # Render the table by constructing the map directly (bypassing box macro)
    table_opts = [id: id, style: table_style]

    table_children = fn ->
      View.column([], fn ->
        # Render table header
        render_header(
          normalized_columns,
          header_style,
          sort_by,
          sort_dir,
          on_sort
        )

        # Render table body
        body_props =
          if max_height do
            [style: %{height: max_height, overflow: :scroll}]
          else
            []
          end

        # Construct body map directly
        body_children = fn ->
          View.column([], fn ->
            # Render each row
            sorted_data
            |> Enum.with_index()
            |> Enum.each(fn {row_data, index} ->
              # Determine if this row is selected
              is_selected =
                selected && Map.get(row_data, select_key) == selected

              # Determine row style based on zebra striping and selection
              row_final_style =
                cond do
                  is_selected ->
                    Map.merge(row_style, selected_style)

                  zebra_stripe && rem(index, 2) == 1 ->
                    Map.merge(row_style, zebra_style)

                  true ->
                    row_style
                end

              # Create click handler for row selection
              row_click_handler =
                if on_select do
                  fn -> on_select.(Map.get(row_data, select_key)) end
                else
                  nil
                end

              # Render the row
              row_props = [
                id: "#{id}_row_#{index}",
                style: row_final_style
              ]

              # Add click handler if provided
              row_props =
                if row_click_handler do
                  Keyword.put(row_props, :on_click, row_click_handler)
                else
                  row_props
                end

              View.row(row_props, fn ->
                # Render each cell in the row
                normalized_columns
                |> Enum.each(fn column ->
                  render_cell(row_data, column, index)
                end)
              end)
            end)
          end)
        end

        %{type: :box, opts: body_props, children: List.wrap(body_children.())}

        # Render footer if provided
        if footer_fn do
          footer_fn.()
        end
      end)
    end

    %{type: :box, opts: table_opts, children: List.wrap(table_children.())}
  end

  @doc """
  Renders a table with pagination controls.

  This is a higher-level component that combines the table with
  pagination controls for navigating through large datasets.

  ## Parameters

  * `data` - List of maps for the current page
  * `columns` - List of column specifications (same as `render/3`)
  * `page` - Current page number (1-based)
  * `total_pages` - Total number of pages
  * `on_page_change` - Function called when page changes
  * `opts` - Options for customizing the table (same as `render/3`)

  ## Options

  All options from `render/3` plus:
  * `:pagination_style` - Style for the pagination controls
  * `:page_info` - Whether to show page info text (default: true)
  * `:page_size` - Number of items per page (for display only)
  * `:total_items` - Total number of items (for display only)

  ## Returns

  A view element representing the paginated table.

  ## Example

  ```elixir
  Table.paginated(
    model.current_page_data,
    [
      %{key: :id, label: "ID", width: 5},
      %{key: :name, label: "Name", width: 15}
    ],
    model.current_page,
    model.total_pages,
    fn page -> {:change_page, page} end,
    sort_by: model.sort_column,
    page_size: model.page_size,
    total_items: model.total_items
  )
  ```
  """
  def paginated(data, columns, page, total_pages, on_page_change, opts \\ []) do
    # Extract additional pagination options
    pagination_style = Keyword.get(opts, :pagination_style, %{})
    show_page_info = Keyword.get(opts, :page_info, true)
    page_size = Keyword.get(opts, :page_size, nil)
    total_items = Keyword.get(opts, :total_items, nil)
    id = Keyword.get(opts, :id, "paginated_table")

    # Create footer function for pagination controls
    footer_fn = fn ->
      View.row([id: "#{id}_pagination", style: pagination_style], fn ->
        # Page info display
        if show_page_info do
          info_text = "Page #{page} of #{total_pages}"

          if page_size && total_items do
            start_item = (page - 1) * page_size + 1
            end_item = min(page * page_size, total_items)

            ^info_text =
              "#{info_text} (#{start_item}-#{end_item} of #{total_items})"
          end

          View.text(info_text, style: %{marginRight: "1rem"})
        end

        # Spacer - construct map directly
        %{
          type: :box,
          opts: [style: %{width: :flex}],
          children: List.wrap(View.text(""))
        }

        # Pagination buttons
        View.row([style: %{gap: 1}], fn ->
          # First page button
          View.button(
            [
              id: "#{id}_first_page",
              style: %{},
              disabled: page <= 1,
              on_click: fn -> on_page_change.(1) end
            ],
            "<<"
          )

          # Previous page button
          View.button(
            [
              id: "#{id}_prev_page",
              style: %{},
              disabled: page <= 1,
              on_click: fn -> on_page_change.(page - 1) end
            ],
            "<"
          )

          # Page number buttons
          page_numbers = calculate_page_numbers(page, total_pages)

          Enum.map(page_numbers, fn p ->
            is_current = p == page

            if p == :ellipsis do
              View.text("...")
            else
              View.button(
                [
                  id: "#{id}_page_#{p}",
                  style:
                    if(is_current, do: %{bg: :blue, fg: :white}, else: %{}),
                  disabled: is_current,
                  on_click: fn -> on_page_change.(p) end
                ],
                to_string(p)
              )
            end
          end)

          # Next page button
          View.button(
            [
              id: "#{id}_next_page",
              style: %{},
              disabled: page >= total_pages,
              on_click: fn -> on_page_change.(page + 1) end
            ],
            ">"
          )

          # Last page button
          View.button(
            [
              id: "#{id}_last_page",
              style: %{},
              disabled: page >= total_pages,
              on_click: fn -> on_page_change.(total_pages) end
            ],
            ">>"
          )
        end)
      end)
    end

    # Render the table with pagination footer
    render(data, columns, Keyword.put(opts, :footer, footer_fn))
  end

  # Private helper functions

  # Normalize columns to map format
  defp normalize_columns(columns) do
    Enum.map(columns, &normalize_column/1)
  end

  defp normalize_column(col) when is_atom(col) do
    %{
      key: col,
      label: to_string(col) |> String.capitalize(),
      alignment: :left,
      sortable: true
    }
  end

  defp normalize_column(%{key: _} = column) do
    defaults = %{
      alignment: :left,
      sortable: true,
      label: to_string(column.key) |> String.capitalize()
    }

    Map.merge(defaults, column)
  end

  # Render table header row
  defp render_header(columns, style, sort_by, sort_dir, on_sort) do
    View.row([style: style], fn ->
      columns
      |> Enum.map(fn column ->
        is_sorted = column.key == sort_by

        header_click =
          if column.sortable && on_sort do
            fn ->
              new_dir = if is_sorted && sort_dir == :asc, do: :desc, else: :asc
              on_sort.(%{column: column.key, direction: new_dir})
            end
          else
            nil
          end

        # Base props
        header_props_map = %{id: "header_#{column.key}", style: %{}}

        # Add style constraints
        style_constraints = %{}

        style_constraints =
          if Map.has_key?(column, :width),
            do: Map.put(style_constraints, :width, column.width),
            else: style_constraints

        style_constraints =
          if Map.has_key?(column, :min_width),
            do: Map.put(style_constraints, :min_width, column.min_width),
            else: style_constraints

        style_constraints =
          if Map.has_key?(column, :max_width),
            do: Map.put(style_constraints, :max_width, column.max_width),
            else: style_constraints

        header_props_map =
          Map.put(
            header_props_map,
            :style,
            Map.merge(header_props_map.style, style_constraints)
          )

        # Add click handler
        header_props_map =
          if header_click,
            do: Map.put(header_props_map, :on_click, header_click),
            else: header_props_map

        # Calculate sort indicator label
        sort_indicator_label =
          if is_sorted do
            case sort_dir do
              :asc -> " ↑"
              :desc -> " ↓"
              _ -> ""
            end
          else
            ""
          end

        # Render using View.text for now, applying final props
        cell_content = column.label <> sort_indicator_label
        %{type: :text, text: cell_content, attrs: header_props_map}
      end)
    end)
  end

  # Render a data cell
  defp render_cell(row_data, column, row_index) do
    # Get cell value
    value = Map.get(row_data, column.key)

    # Format value if formatter is provided
    display_value =
      if Map.has_key?(column, :format) && is_function(column.format, 1) do
        column.format.(value)
      else
        to_string(value)
      end

    # Cell style
    cell_style = Map.get(column, :style, %{})

    # Add alignment to style
    cell_style = Map.put(cell_style, :text_align, column.alignment)

    # Cell properties
    cell_props = [
      id: "cell_#{column.key}_#{row_index}",
      style: cell_style
    ]

    # Add width constraint if specified
    cell_props =
      if Map.has_key?(column, :width) do
        Keyword.put(
          cell_props,
          :style,
          Map.put(cell_style, :width, column.width)
        )
      else
        constraints = []

        constraints =
          if Map.has_key?(column, :min_width) do
            Keyword.put(constraints, :min_width, column.min_width)
          else
            constraints
          end

        constraints =
          if Map.has_key?(column, :max_width) do
            Keyword.put(constraints, :max_width, column.max_width)
          else
            constraints
          end

        if constraints != [] do
          Keyword.put(
            cell_props,
            :style,
            Map.merge(cell_style, Map.new(constraints))
          )
        else
          cell_props
        end
      end

    # Render the cell
    cell_children = fn ->
      # Render custom or default cell content
      case column do
        %{render: render_fun} when is_function(render_fun, 1) ->
          render_fun.(row_data)

        _ ->
          View.text(display_value, style: cell_style)
      end
    end

    %{type: :box, opts: cell_props, children: List.wrap(cell_children.())}
  end

  # Calculate which page numbers to show in pagination
  defp calculate_page_numbers(current_page, total_pages) do
    cond do
      # If 7 or fewer pages, show all
      total_pages <= 7 ->
        Enum.to_list(1..total_pages)

      # If current page is close to start
      current_page <= 3 ->
        Enum.to_list(1..5) ++ [:ellipsis, total_pages]

      # If current page is close to end
      current_page >= total_pages - 2 ->
        [1, :ellipsis] ++ Enum.to_list((total_pages - 4)..total_pages)

      # Current page is in the middle
      true ->
        [1, :ellipsis] ++
          Enum.to_list((current_page - 1)..(current_page + 1)) ++
          [:ellipsis, total_pages]
    end
  end
end
