defmodule Raxol.Core.Renderer.Views.Table do
  @moduledoc '''
  Table view component for displaying tabular data.

  Features:
  * Column headers
  * Row striping
  * Column alignment
  * Border styles
  * Column resizing
  * Row selection
  '''

  @behaviour Raxol.UI.Components.Base.Component

  alias Raxol.Core.Renderer.View
  require Raxol.Core.Runtime.Log
  require Raxol.Core.Renderer.View

  defstruct type: :table,
            columns: [],
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

  @doc '''
  Initializes the Table component with props.
  Props are expected to be a map.
  '''
  @impl Raxol.UI.Components.Base.Component
  def init(props) when is_map(props) do
    fields = extract_table_fields(props)
    build_initial_state(fields)
  end

  def init(props) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Table.init/1 called with non-map argument: #{inspect(props)}",
      %{}
    )

    {:error, :invalid_props, props}
  end

  @doc '''
  Called when the component is mounted.
  '''
  @impl Raxol.UI.Components.Base.Component
  def mount(state) do
    # No commands on mount for now
    {:ok, state, []}
  end

  @doc '''
  Renders the Table component based on its current state.
  '''
  @impl Raxol.UI.Components.Base.Component
  def render(%__MODULE__{} = state, _props_or_context) do
    content = build_table_content(state)
    wrap_table_content(content, state.border)
  end

  @doc '''
  Renders the table content, potentially with a border.
  '''
  def render_content(state), do: render(state, %{})

  defp build_table_content(state) do
    header =
      create_header_row(%RowContext{
        columns: state.columns,
        widths: state.calculated_widths,
        style: state.header_style
      })

    rows =
      Enum.with_index(state.data)
      |> Enum.map(fn {row, index} ->
        style =
          build_row_style(
            index,
            row,
            state.striped,
            state.selectable,
            state.selected,
            state.row_style
          )

        create_data_row(%RowContext{
          columns: state.columns,
          row: row,
          widths: state.calculated_widths,
          style: style
        })
      end)

    [header | rows]
  end

  defp wrap_table_content(content, border) do
    if border != :none do
      View.border_wrap(border, do: content)
    else
      View.box(children: content)
    end
  end

  @doc '''
  Handles updates to the component state.
  '''
  @impl Raxol.UI.Components.Base.Component
  def update(%__MODULE__{} = state, message) do
    log_component(:update, message)
    default_update_response(state)
  end

  @doc '''
  Handles dispatched events.
  '''
  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, _props_or_context, %__MODULE__{} = state) do
    log_component(:event, event)
    default_update_response(state)
  end

  defp log_component(type, payload) do
    Raxol.Core.Runtime.Log.info(
      "Table component [#{inspect(self())}] received #{type}: #{inspect(payload)}"
    )
  end

  defp default_update_response(state), do: {:ok, state, []}

  @doc '''
  Called when the component is about to be unmounted.
  '''
  @impl Raxol.UI.Components.Base.Component
  def unmount(%__MODULE__{} = state) do
    # No specific cleanup for now
    {:ok, state}
  end

  # Private Helpers

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

  defp create_header_row(%RowContext{
         columns: columns,
         widths: widths,
         style: style
       }) do
    header_cells =
      Enum.zip(columns, widths)
      |> Enum.map(fn {%{header: header}, width} ->
        View.text(String.pad_trailing(header, width), style: style)
      end)

    View.flex direction: :row do
      header_cells
    end
  end

  defp create_data_row(%RowContext{
         columns: columns,
         row: row,
         widths: widths,
         style: style
       }) do
    cells =
      Enum.zip(columns, widths)
      |> Enum.map(fn {column, width} ->
        value = get_column_value(row, column)
        formatted = format_cell_value(value, column)
        View.text(String.pad_trailing(formatted, width), style: style)
      end)

    View.flex direction: :row do
      cells
    end
  end

  defp get_column_value(row, %{key: key}) when is_function(key, 1),
    do: key.(row)

  defp get_column_value(row, %{key: key}) when is_atom(key),
    do: Map.get(row, key)

  defp format_cell_value(value, %{format: format}) when is_function(format, 1),
    do: format.(value)

  defp format_cell_value(value, _), do: to_string(value)

  @doc '''
  Constructs a Table struct for view usage (not stateful component usage).
  Accepts a map of props and returns the struct directly (not a tuple).
  '''
  def new(props) when is_map(props) do
    fields = extract_table_fields(props)
    build_initial_state(fields)
  end

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
    struct_keys = Map.keys(table.__struct__)

    case fun.(Map.from_struct(table)) do
      {current, updated} ->
        filtered = Map.take(updated, struct_keys)
        {current, struct(table, filtered)}

      :error ->
        :error
    end
  end

  defp build_row_style(index, _row, striped, selectable, selected, row_style) do
    style = row_style

    style =
      if striped and rem(index, 2) == 1 do
        [:inverse | style]
      else
        style
      end

    style =
      if selectable and selected == index do
        [:bold, :inverse | style]
      else
        style
      end

    style
  end

  # Group handle_call clauses together
  def handle_call({:update_props, _new_props}, _from, _state) do
    # TODO: Implement this
  end

  def handle_call({:get_state}, _from, _state) do
    # TODO: Implement this
  end
end
