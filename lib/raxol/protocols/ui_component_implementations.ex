defmodule Raxol.Protocols.UIComponentImplementations do
  @moduledoc """
  Protocol implementations for UI components.

  This module provides Renderable, Styleable, and EventHandler protocol
  implementations for various UI components in the Raxol framework.
  """

  alias Raxol.Protocols.{Renderable, Styleable, EventHandler}

  # Table Component Protocol Implementations
  defimpl Renderable, for: Raxol.UI.Components.Table do
    def render(table, opts \\ []) do
      width = Keyword.get(opts, :width, 80)
      show_borders = Keyword.get(opts, :borders, true)

      table
      |> render_table_structure(width, show_borders)
      |> apply_table_styling(table.theme, table.style)
    end

    def render_metadata(table) do
      # Calculate table dimensions
      header_height = 1
      data_height = length(filtered_data(table))
      pagination_height = if table.options.paginate, do: 2, else: 0

      total_width = calculate_table_width(table.columns)

      %{
        width: total_width,
        height: header_height + data_height + pagination_height,
        colors: true,
        scrollable: table.options.paginate || data_height > 20,
        interactive: true,
        component_type: :table
      }
    end

    defp render_table_structure(table, width, show_borders) do
      rows = filtered_data(table)

      header = render_table_header(table.columns, width, show_borders)
      body = render_table_body(rows, table.columns, table.selected_row, width, show_borders)
      pagination = if table.options.paginate do
        render_pagination(table)
      else
        ""
      end

      [header, body, pagination]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")
    end

    defp render_table_header(columns, width, show_borders) do
      column_widths = calculate_column_widths(columns, width)

      header_row = columns
      |> Enum.zip(column_widths)
      |> Enum.map(fn {col, col_width} ->
        label = String.pad_trailing(col.label, col_width)
        apply_column_header_style(label, col)
      end)
      |> Enum.join(if show_borders, do: " │ ", else: "  ")

      if show_borders do
        border_line = column_widths
        |> Enum.map(&String.duplicate("─", &1))
        |> Enum.join("─┼─")

        "#{header_row}\n#{border_line}"
      else
        header_row
      end
    end

    defp render_table_body(rows, columns, selected_row, width, show_borders) do
      column_widths = calculate_column_widths(columns, width)

      rows
      |> Enum.with_index()
      |> Enum.map(fn {row, index} ->
        is_selected = selected_row == index

        row_content = columns
        |> Enum.zip(column_widths)
        |> Enum.map(fn {col, col_width} ->
          value = Map.get(row, col.id, "")
          formatted_value = format_cell_value(value, col)
          padded_value = String.pad_trailing(to_string(formatted_value), col_width)
          apply_column_cell_style(padded_value, col, is_selected)
        end)
        |> Enum.join(if show_borders, do: " │ ", else: "  ")

        if is_selected do
          apply_selected_row_style(row_content)
        else
          row_content
        end
      end)
      |> Enum.join("\n")
    end

    defp render_pagination(table) do
      total_pages = calculate_total_pages(table)
      current = table.current_page

      "Page #{current}/#{total_pages} | #{table.page_size} per page"
    end

    defp filtered_data(table) do
      data = table.data

      # Apply filtering if enabled
      data = if table.options.searchable and table.filter_term != "" do
        filter_table_data(data, table.filter_term, table.columns)
      else
        data
      end

      # Apply sorting if enabled
      data = if table.options.sortable and table.sort_by do
        sort_table_data(data, table.sort_by, table.sort_direction)
      else
        data
      end

      # Apply pagination if enabled
      if table.options.paginate do
        paginate_data(data, table.current_page, table.page_size)
      else
        data
      end
    end

    defp calculate_table_width(columns) do
      columns
      |> Enum.map(fn col ->
        case col[:width] do
          nil -> 15  # default width
          :auto -> 15
          width when is_integer(width) -> width
        end
      end)
      |> Enum.sum()
      |> Kernel.+(length(columns) * 3)  # borders and spacing
    end

    defp calculate_column_widths(columns, total_width) do
      # Simple equal distribution for now
      available_width = total_width - (length(columns) * 3)
      col_width = div(available_width, length(columns))
      Enum.map(columns, fn _ -> col_width end)
    end

    defp format_cell_value(value, col) do
      case col[:format] do
        nil -> to_string(value)
        formatter when is_function(formatter, 1) -> formatter.(value)
        _ -> to_string(value)
      end
    end

    defp apply_column_header_style(text, col) do
      style = col[:header_style] || %{}
      apply_style_to_text(text, Map.merge(%{bold: true}, style))
    end

    defp apply_column_cell_style(text, col, is_selected) do
      base_style = col[:style] || %{}
      style = if is_selected do
        Map.merge(base_style, %{background: :blue, foreground: :white})
      else
        base_style
      end
      apply_style_to_text(text, style)
    end

    defp apply_selected_row_style(text) do
      apply_style_to_text(text, %{background: :blue, foreground: :white})
    end

    defp apply_table_styling(content, _theme, _style_override) do
      # Apply theme and style overrides
      # For now, return content as-is
      content
    end

    defp apply_style_to_text(text, style) do
      if style == %{} do
        text
      else
        ansi_codes = Styleable.to_ansi(%{style: style})
        if ansi_codes == "" do
          text
        else
          "#{ansi_codes}#{text}\e[0m"
        end
      end
    end

    # Helper functions for data operations
    defp filter_table_data(data, term, columns) do
      Enum.filter(data, fn row ->
        Enum.any?(columns, fn col ->
          value = Map.get(row, col.id, "")
          String.contains?(String.downcase(to_string(value)), String.downcase(term))
        end)
      end)
    end

    defp sort_table_data(data, sort_by, direction) do
      Enum.sort(data, fn a, b ->
        val_a = Map.get(a, sort_by)
        val_b = Map.get(b, sort_by)

        case direction do
          :asc -> val_a <= val_b
          :desc -> val_a >= val_b
        end
      end)
    end

    defp paginate_data(data, page, page_size) do
      start_index = (page - 1) * page_size
      Enum.slice(data, start_index, page_size)
    end

    defp calculate_total_pages(table) do
      total_items = length(table.data)
      ceil(total_items / table.page_size)
    end
  end

  # Styleable implementation for Table
  defimpl Styleable, for: Raxol.UI.Components.Table do
    def apply_style(table, style) do
      updated_style = Map.merge(table.style, style)
      %{table | style: updated_style}
    end

    def get_style(table) do
      Map.merge(table.theme || %{}, table.style)
    end

    def merge_styles(table, new_style) do
      current_style = get_style(table)
      merged = Map.merge(current_style, new_style)
      %{table | style: merged}
    end

    def reset_style(table) do
      %{table | style: %{}, theme: nil}
    end

    def to_ansi(table) do
      style = get_style(table)
      Styleable.to_ansi(%{style: style})
    end
  end

  # EventHandler implementation for Table
  defimpl EventHandler, for: Raxol.UI.Components.Table do
    def handle_event(table, %{type: :key_press, data: %{key: key}}, state) do
      case key do
        :arrow_up ->
          new_table = move_selection(table, -1)
          {:ok, new_table, state}

        :arrow_down ->
          new_table = move_selection(table, 1)
          {:ok, new_table, state}

        :page_up when table.options.paginate ->
          new_table = change_page(table, -1)
          {:ok, new_table, state}

        :page_down when table.options.paginate ->
          new_table = change_page(table, 1)
          {:ok, new_table, state}

        :enter ->
          {:ok, table, Map.put(state, :selected_item, get_selected_item(table))}

        _ ->
          {:unhandled, table, state}
      end
    end

    def handle_event(table, %{type: :click, data: %{row: row_index}}, state) do
      new_table = %{table | selected_row: row_index}
      {:ok, new_table, state}
    end

    def handle_event(table, %{type: :filter, data: %{term: term}}, state) do
      new_table = %{table | filter_term: term, current_page: 1}
      {:ok, new_table, state}
    end

    def handle_event(table, %{type: :sort, data: %{column: column}}, state) do
      {sort_by, direction} = if table.sort_by == column do
        {column, toggle_sort_direction(table.sort_direction)}
      else
        {column, :asc}
      end

      new_table = %{table | sort_by: sort_by, sort_direction: direction}
      {:ok, new_table, state}
    end

    def handle_event(table, _event, state) do
      {:unhandled, table, state}
    end

    def can_handle?(table, %{type: type}) do
      allowed_events = [:key_press, :click, :filter, :sort]

      # Add pagination events if enabled
      allowed_events = if table.options.paginate do
        [:page_up, :page_down | allowed_events]
      else
        allowed_events
      end

      type in allowed_events
    end

    def get_event_listeners(_table) do
      [:key_press, :click, :filter, :sort, :page_up, :page_down]
    end

    def subscribe(table, _event_types) do
      # Tables don't maintain subscription state
      table
    end

    def unsubscribe(table, _event_types) do
      # Tables don't maintain subscription state
      table
    end

    # Helper functions
    defp move_selection(table, direction) do
      current = table.selected_row || 0
      data_length = length(table.data)
      new_selection = max(0, min(data_length - 1, current + direction))
      %{table | selected_row: new_selection}
    end

    defp change_page(table, direction) do
      total_pages = ceil(length(table.data) / table.page_size)
      new_page = max(1, min(total_pages, table.current_page + direction))
      %{table | current_page: new_page}
    end

    defp get_selected_item(table) do
      if table.selected_row do
        Enum.at(table.data, table.selected_row)
      else
        nil
      end
    end

    defp toggle_sort_direction(:asc), do: :desc
    defp toggle_sort_direction(:desc), do: :asc
  end
end