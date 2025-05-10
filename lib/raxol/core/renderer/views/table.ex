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

  # Assuming a Base.Component behaviour might exist or these are the expected functions
  # If Raxol.UI.Components.Base.Component is a defined behaviour, uncommenting the next line would be good.
  # @behaviour Raxol.UI.Components.Base.Component

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
            calculated_widths: []

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
  # @impl Raxol.UI.Components.Base.Component
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
      calculated_widths: calculated_widths
    }
    # Return state directly, not {:ok, state}
    initial_state
  end

  @doc """
  Called when the component is mounted.
  """
  # @impl Raxol.UI.Components.Base.Component
  def mount(state) do
    # No commands on mount for now
    # Return {state, commands} tuple
    {state, []}
  end

  @doc """
  Renders the Table component based on its current state.
  """
  # @impl Raxol.UI.Components.Base.Component
  def render(state = %__MODULE__{}) do
    # Logic from the old new/1 function, adapted to use component state
    header = create_header_row(state.columns, state.calculated_widths, state.header_style)

    rows = create_data_rows(
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
      View.border(state.border, do: content)
    else
      View.box(children: content)
    end
  end

  @doc """
  Handles updates to the component state.
  """
  # @impl Raxol.UI.Components.Base.Component
  def update(message, state = %__MODULE__{}) do
    Logger.info("Table component [#{inspect(self())}] received update: #{inspect(message)}")
    # TODO: Implement actual update logic based on message
    # For now, just return current state and no commands
    {:ok, state, []}
  end

  @doc """
  Handles dispatched events.
  """
  # @impl Raxol.UI.Components.Base.Component
  def handle_event(event, state = %__MODULE__{}) do
    Logger.info("Table component [#{inspect(self())}] received event: #{inspect(event)}")
    # TODO: Implement event handling logic
    {:ok, state, []}
  end

  @doc """
  Called when the component is about to be unmounted.
  """
  # @impl Raxol.UI.Components.Base.Component
  def unmount(state = %__MODULE__{}) do
    # No specific cleanup for now
    {:ok, state}
  end


  @doc """
  Creates a new table view. (DEPRECATED - Use ComponentManager.mount/2 instead)
  """
  def new(opts) do
    Logger.warn("#{__MODULE__}.new/1 is deprecated. Use ComponentManager.mount(#{__MODULE__}, props) instead.")
    # For temporary backward compatibility or direct view generation, map opts to props
    # and call the new rendering path via a temporary state.
    props = Enum.into(opts, %{})
    {:ok, initial_comp_state} = init(props)
    render(initial_comp_state)
  end

  # Private Helpers (remain largely the same, ensure they use arguments not module state)

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
    View.flex direction: :row, style: style do
      Enum.zip(columns, widths)
      |> Enum.map(fn {column, width} ->
        View.text(pad_text(column.header, width, column.align))
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
         style # This is state.row_style
       ) do
    data
    |> Enum.with_index()
    |> Enum.map(fn {row, index} ->
      base_style =
        if is_function(style, 2) do
          style.(index, row)
        else
          style
        end || []

      row_style_combined =
        base_style ++
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

      cells =
        Enum.zip(columns, widths)
        |> Enum.map(fn {column, width} ->
          formatted_value =
            get_column_value(row, column)
            |> format_value(column.format)
          cell_content =
            case formatted_value do
              text when is_binary(text) ->
                View.text(pad_text(text, width, column.align))
              view when is_map(view) ->
                view
              other ->
                View.text(pad_text(to_string(other), width, column.align))
            end
          cell_content
        end)
      View.flex direction: :row, style: row_style_combined do
        cells
      end
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
