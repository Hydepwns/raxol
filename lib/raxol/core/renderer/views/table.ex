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
  require Raxol.Core.Renderer.View

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

  defmodule RowContext do
    defstruct index: nil, row: nil, style: [], columns: [], widths: []
  end

  @doc """
  Initializes the Table component with props.
  Props are expected to be a map.
  """
  @impl Raxol.UI.Components.Base.Component
  def init(props) when is_map(props) do
    fields = extract_table_fields(props)
    initial_state = build_initial_state(fields)
    {:ok, initial_state}
  end

  defp extract_table_fields(props) do
    %{
      columns: Map.get(props, :columns, []),
      data: Map.get(props, :data, []),
      border: Map.get(props, :border, :single),
      striped: Map.get(props, :striped, true),
      selectable: Map.get(props, :selectable, false),
      selected: Map.get(props, :selected),
      header_style: Map.get(props, :header_style, [:bold]),
      row_style: Map.get(props, :row_style, []),
      title: Map.get(props, :title)
    }
  end

  defp build_initial_state(fields) do
    calculated_widths = calculate_column_widths(fields.columns, fields.data)

    %__MODULE__{
      columns: fields.columns,
      data: fields.data,
      border: fields.border,
      striped: fields.striped,
      selectable: fields.selectable,
      selected: fields.selected,
      header_style: fields.header_style,
      row_style: fields.row_style,
      calculated_widths: calculated_widths,
      title: fields.title
    }
  end

  def init(props) do
    Logger.warning(
      "Table.init/1 called with non-map argument: #{inspect(props)}"
    )

    {:error, :invalid_props, props}
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
  def render(%__MODULE__{} = state) do
    content = build_table_content(state)
    wrap_table_content(content, state.border)
  end

  defp build_table_content(state) do
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

    [header | rows]
  end

  defp wrap_table_content(content, border) do
    if border != :none do
      View.border_wrap(border, do: content)
    else
      View.box(children: content)
    end
  end

  @doc """
  Handles updates to the component state.
  """
  @impl Raxol.UI.Components.Base.Component
  def update(%__MODULE__{} = state, message) do
    log_component(:update, message)
    default_update_response(state)
  end

  @doc """
  Handles dispatched events.
  """
  @impl Raxol.UI.Components.Base.Component
  def handle_event(%__MODULE__{} = state, event) do
    log_component(:event, event)
    default_update_response(state)
  end

  defp log_component(type, payload) do
    Logger.info(
      "Table component [#{inspect(self())}] received #{type}: #{inspect(payload)}"
    )
  end

  defp default_update_response(state), do: {:ok, state, []}

  @doc """
  Called when the component is about to be unmounted.
  """
  @impl Raxol.UI.Components.Base.Component
  def unmount(%__MODULE__{} = state) do
    # No specific cleanup for now
    {:ok, state}
  end

  # Private Helpers

  defp calculate_column_widths(columns, data) do
    Enum.map(columns, fn column ->
      calculate_single_column_width(column, data)
    end)
  end

  defp calculate_single_column_width(%{width: :auto} = column, data) do
    header_width = String.length(column.header)
    content_width = max_content_width(column, data)
    max(header_width, content_width)
  end

  defp calculate_single_column_width(%{width: width}, _data)
       when is_integer(width),
       do: width

  defp max_content_width(column, data) do
    data
    |> Enum.map(fn row ->
      value = get_column_value(row, column)
      String.length(to_string(value))
    end)
    |> Enum.max(fn -> 0 end)
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
    Enum.with_index(data)
    |> Enum.map(fn {row, index} ->
      context =
        build_row_context(
          index,
          row,
          columns,
          widths,
          striped,
          selectable,
          selected,
          row_style
        )

      create_data_row(context)
    end)
  end

  defp build_row_context(
         index,
         row,
         columns,
         widths,
         striped,
         selectable,
         selected,
         row_style
       ) do
    style =
      build_row_style(index, row, striped, selectable, selected, row_style)

    %RowContext{
      index: index,
      row: row,
      style: style,
      columns: columns,
      widths: widths
    }
  end

  defp build_row_style(index, row, striped, selectable, selected, row_style) do
    base = get_base_row_style(index, row, row_style)
    selection = get_selection_style(index, selectable, selected)
    stripe = get_stripe_style(index, striped)
    Enum.uniq(base ++ selection ++ stripe)
  end

  defp create_data_row(%RowContext{
         columns: columns,
         row: row,
         widths: widths,
         style: style
       }) do
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
      key when is_atom(key) ->
        Map.get(row, key)

      fun when is_function(fun, 1) ->
        fun.(row)

      other ->
        # Fallback for unsupported key types
        raise ArgumentError, "Unsupported column key: #{inspect(other)}"
    end
  end

  defp format_value(value, column) do
    case column.format do
      nil -> to_string(value)
      fun when is_function(fun, 1) -> fun.(value)
    end
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
    padding = max(width - String.length(text), 0)

    case align do
      :left -> pad_left(text, padding)
      :right -> pad_right(text, padding)
      :center -> pad_center(text, padding)
      _ -> text
    end
  end

  defp pad_left(text, padding) do
    # Pad spaces to the right
    text <> String.duplicate(" ", padding)
  end

  defp pad_right(text, padding) do
    # Pad spaces to the left
    String.duplicate(" ", padding) <> text
  end

  defp pad_center(text, padding) do
    # Split padding evenly left/right
    left_pad = div(padding, 2)
    right_pad = padding - left_pad
    String.duplicate(" ", left_pad) <> text <> String.duplicate(" ", right_pad)
  end

  def render_content(state), do: render(state)

  def new(props), do: init(props)

  def fetch(table, key) do
    Map.fetch(Map.from_struct(table), key)
  end

  def get_and_update(table, key, fun) do
    update_struct_map(table, fn map -> Map.get_and_update(map, key, fun) end)
  end

  def pop(table, key) do
    update_struct_map(table, fn map -> Map.pop(map, key) end)
  end

  defp update_struct_map(table, fun) do
    case fun.(Map.from_struct(table)) do
      {current, updated} -> {current, struct(table, updated)}
      :error -> :error
    end
  end
end
