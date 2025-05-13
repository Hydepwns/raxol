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

  @behaviour Raxol.UI.Components.Base.Component

  alias Raxol.Core.Renderer.View
  require Logger

  defstruct columns: [],
            data: [],
            border: :single,
            striped: true,
            selectable: false,
            selected: nil,
            header_style: [:bold],
            row_style: [],
            # Internal, calculated state
            calculated_widths: [],
            title: nil

  @type column :: %{
          header: String.t(),
          key: atom() | (map() -> term()),
          width: non_neg_integer() | :auto,
          align: :left | :center | :right,
          format: (term() -> String.t()) | nil
        }

  @type props :: %{
          columns: [column()],
          data: [map()],
          border: View.border_style(),
          striped: boolean(),
          selectable: boolean(),
          selected: non_neg_integer() | nil,
          header_style: View.style(),
          row_style: View.style()
        }

  @doc """
  Initializes the Table component with props.
  Props are expected to be a map.
  """
  @impl Raxol.UI.Components.Base.Component
  def init(props) when is_map(props) do
    columns = Map.get(props, :columns, [])
    data = Map.get(props, :data, [])
    border = Map.get(props, :border, :single)
    striped = Map.get(props, :striped, true)
    selectable = Map.get(props, :selectable, false)
    selected = Map.get(props, :selected)
    header_style = Map.get(props, :header_style, [:bold])
    # row_style can be a list or a function (index, row_data) -> style_list
    row_style = Map.get(props, :row_style, [])
    title = Map.get(props, :title)

    # Calculate column widths during init
    calculated_widths = calculate_column_widths(columns, data)

    initial_state = %__MODULE__{
      columns: columns,
      data: data,
      border: border,
      striped: striped,
      selectable: selectable,
      selected: selected,
      header_style: header_style,
      row_style: row_style,
      calculated_widths: calculated_widths,
      title: title
    }

    {:ok, initial_state}
  end

  @doc """
  Called when the component is mounted.
  """
  @impl Raxol.UI.Components.Base.Component
  def mount(state) do
    # No commands on mount for now
    {:ok, state, []}
  end

  @doc """
  Renders the Table component based on its current state.
  """
  @impl Raxol.UI.Components.Base.Component
  def render(state = %__MODULE__{}) do
    header =
      create_header_row(
        state.columns,
        state.calculated_widths,
        state.header_style
      )

    rows =
      create_data_rows(
        state.columns,
        state.data,
        state.calculated_widths,
        state.striped,
        state.selectable,
        state.selected,
        state.row_style
      )

    content = [header | rows]

    if state.border != :none do
      View.border_wrap(state.border, do: content)
    else
      View.box(children: content)
    end
  end

  @doc """
  Handles updates to the component state.
  """
  @impl Raxol.UI.Components.Base.Component
  def update(message, state = %__MODULE__{}) do
    Logger.info(
      "Table component [#{inspect(self())}] received update: #{inspect(message)}"
    )

    # TODO: Implement actual update logic based on message
    {:ok, state, []}
  end

  @doc """
  Handles dispatched events.
  """
  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, state = %__MODULE__{}) do
    Logger.info(
      "Table component [#{inspect(self())}] received event: #{inspect(event)}"
    )

    # TODO: Implement event handling logic
    {:ok, state, []}
  end

  @doc """
  Called when the component is about to be unmounted.
  """
  @impl Raxol.UI.Components.Base.Component
  def unmount(state = %__MODULE__{}) do
    # No specific cleanup for now
    {:ok, state}
  end

  # Private Helpers

  defp calculate_column_widths(columns, data) do
    Enum.map(columns, fn column ->
      case column.width do
        :auto ->
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
    View.row style: style do
      Enum.zip(columns, widths)
      |> Enum.map(fn {column, width} ->
        View.text(
          pad_text(column.header, width, column.align),
          style: style
        )
      end)
    end
  end

  defp create_data_rows(
         columns,
         data,
         widths,
         striped,
         selectable,
         selected,
         row_style
       ) do
    data
    |> Enum.with_index()
    |> Enum.map(fn {row, index} ->
      style =
        get_row_style(index, row, striped, selectable, selected, row_style)

      create_data_row(columns, row, widths, style)
    end)
  end

  defp create_data_row(columns, row, widths, style) do
    View.row style: style do
      Enum.zip(columns, widths)
      |> Enum.map(fn {column, width} ->
        value = get_column_value(row, column)
        formatted = format_value(value, column)

        View.text(
          pad_text(formatted, width, column.align),
          style: style
        )
      end)
    end
  end

  defp get_column_value(row, column) do
    case column.key do
      key when is_atom(key) -> Map.get(row, key)
      fun when is_function(fun, 1) -> fun.(row)
    end
  end

  defp format_value(value, column) do
    case column.format do
      nil -> to_string(value)
      fun when is_function(fun, 1) -> fun.(value)
    end
  end

  defp get_row_style(index, row, striped, selectable, selected, row_style) do
    base_style = get_base_row_style(index, row, row_style)
    selection_style = get_selection_style(index, selectable, selected)
    stripe_style = get_stripe_style(index, striped)

    Enum.uniq(base_style ++ selection_style ++ stripe_style)
  end

  defp get_base_row_style(index, row, row_style) do
    case row_style do
      style when is_list(style) -> style
      fun when is_function(fun, 2) -> fun.(index, row)
      _ -> []
    end
  end

  defp get_selection_style(index, true, selected) when index == selected do
    [:bold, :bg_blue, :fg_white]
  end

  defp get_selection_style(_index, _selectable, _selected), do: []

  defp get_stripe_style(index, true) when rem(index, 2) == 1 do
    [:bg_bright_black]
  end

  defp get_stripe_style(_index, _striped), do: []

  defp pad_text(text, width, align) do
    text = to_string(text)
    padding = width - String.length(text)

    case align do
      :left ->
        text <> String.duplicate(" ", padding)

      :right ->
        String.duplicate(" ", padding) <> text

      :center ->
        left_pad = div(padding, 2)
        right_pad = padding - left_pad

        String.duplicate(" ", left_pad) <>
          text <> String.duplicate(" ", right_pad)
    end
  end

  defp render_content(state) do
    header =
      create_header_row(
        state.columns,
        state.calculated_widths,
        state.header_style
      )

    rows =
      create_data_rows(
        state.columns,
        state.data,
        state.calculated_widths,
        state.striped,
        state.selectable,
        state.selected,
        state.row_style
      )

    content = [header | rows]

    if state.border != :none do
      View.border_wrap(state.border, do: content)
    else
      View.box(children: content)
    end
  end
end
