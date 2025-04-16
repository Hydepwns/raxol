defmodule Raxol.Core.Renderer.Views.Table do
  @moduledoc """
  Table view component for displaying tabular data.

  Features:
  * Column headers
  * Row striping
  * Column alignment
  * Border styles
  * Column resizing
  * Row selection
  """

  alias Raxol.Core.Renderer.View

  @type column :: %{
          header: String.t(),
          key: atom() | (map() -> term()),
          width: non_neg_integer() | :auto,
          align: :left | :center | :right,
          format: (term() -> String.t()) | nil
        }

  @type options :: [
          columns: [column()],
          data: [map()],
          border: View.border_style(),
          striped: boolean(),
          selectable: boolean(),
          selected: non_neg_integer() | nil,
          header_style: View.style(),
          row_style: View.style()
        ]

  @doc """
  Creates a new table view.
  """
  def new(opts) do
    columns = Keyword.get(opts, :columns, [])
    data = Keyword.get(opts, :data, [])
    border = Keyword.get(opts, :border, :single)
    striped = Keyword.get(opts, :striped, true)
    selectable = Keyword.get(opts, :selectable, false)
    selected = Keyword.get(opts, :selected)
    header_style = Keyword.get(opts, :header_style, [:bold])
    row_style = Keyword.get(opts, :row_style, [])

    # Calculate column widths
    widths = calculate_column_widths(columns, data)

    # Create header row
    header = create_header_row(columns, widths, header_style)

    # Create data rows
    rows =
      create_data_rows(
        columns,
        data,
        widths,
        striped,
        selectable,
        selected,
        row_style
      )

    # Wrap in border if needed
    content = [header | rows]

    if border != :none do
      View.border(border, do: content)
    else
      View.box(children: content)
    end
  end

  # Private Helpers

  defp calculate_column_widths(columns, data) do
    Enum.map(columns, fn column ->
      case column.width do
        :auto ->
          # Calculate based on content
          header_width = String.length(column.header)

          content_width =
            Enum.reduce(data, 0, fn row, max ->
              value = get_column_value(row, column)
              len = String.length(to_string(value))
              if len > max, do: len, else: max
            end)

          max(header_width, content_width)

        width when is_integer(width) ->
          width
      end
    end)
  end

  defp create_header_row(columns, widths, style) do
    cells =
      Enum.zip(columns, widths)
      |> Enum.map(fn {column, width} ->
        View.text(pad_text(column.header, width, column.align),
          style: style
        )
      end)

    View.flex(direction: :row, children: cells)
  end

  defp create_data_rows(
         columns,
         data,
         widths,
         striped,
         selectable,
         selected,
         style
       ) do
    data
    |> Enum.with_index()
    |> Enum.map(fn {row, index} ->
      # Calculate row style
      row_style =
        style ++
          if striped and rem(index, 2) == 1 do
            [bg: :bright_black]
          else
            []
          end ++
          if selectable and selected == index do
            [bg: :blue, fg: :white]
          else
            []
          end

      # Create row cells
      cells =
        Enum.zip(columns, widths)
        |> Enum.map(fn {column, width} ->
          value =
            get_column_value(row, column)
            |> format_value(column.format)
            |> pad_text(width, column.align)

          View.text(value)
        end)

      View.flex(direction: :row, style: row_style, children: cells)
    end)
  end

  defp get_column_value(row, column) do
    case column.key do
      key when is_atom(key) -> Map.get(row, key)
      fun when is_function(fun, 1) -> fun.(row)
    end
  end

  defp format_value(value, nil), do: to_string(value)
  defp format_value(value, formatter), do: formatter.(value)

  defp pad_text(text, width, align) do
    text = String.slice(to_string(text), 0, width)

    case align do
      :left ->
        String.pad_trailing(text, width)

      :right ->
        String.pad_leading(text, width)

      :center ->
        left = div(width - String.length(text), 2)

        String.pad_leading(text, left + String.length(text))
        |> String.pad_trailing(width)
    end
  end
end
