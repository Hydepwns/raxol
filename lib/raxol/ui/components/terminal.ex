defmodule Raxol.UI.Components.Terminal do
  @moduledoc """
  A terminal emulator component that wraps EmulatorLite to display
  a fully functional terminal within the UI.

  Renders the emulator's screen buffer as styled text elements,
  converting cell-level character/style data to the standard
  `%{type: :text, content: ..., style: ...}` render format.
  """

  use Raxol.UI.Components.Base.Component

  alias Raxol.Terminal.EmulatorLite
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.View.Components

  @type t :: %__MODULE__{
          id: any(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          emulator: EmulatorLite.t() | nil,
          style: map(),
          scroll_offset: integer()
        }

  defstruct id: nil,
            width: 80,
            height: 24,
            emulator: nil,
            style: %{},
            scroll_offset: 0

  @impl true
  @spec init(keyword() | map()) :: {:ok, t()}
  def init(props) do
    props_map = if Keyword.keyword?(props), do: Map.new(props), else: props

    width = Map.get(props_map, :width, 80)
    height = Map.get(props_map, :height, 24)

    emulator = EmulatorLite.new(width, height)

    {:ok,
     %__MODULE__{
       id: Map.get(props_map, :id, nil),
       width: width,
       height: height,
       emulator: emulator,
       style: Map.get(props_map, :style, %{}),
       scroll_offset: 0
     }}
  end

  @impl true
  def mount(state), do: {state, []}

  @impl true
  def unmount(state), do: state

  @impl true
  def update({:write, text}, state) do
    buffer = EmulatorLite.get_active_buffer(state.emulator)
    updated_buffer = write_text_to_buffer(buffer, text)
    emulator = EmulatorLite.update_active_buffer(state.emulator, fn _buf -> updated_buffer end)
    {%{state | emulator: emulator}, []}
  end

  def update({:resize, width, height}, state) do
    emulator = EmulatorLite.resize(state.emulator, width, height)
    {%{state | emulator: emulator, width: width, height: height}, []}
  end

  def update({:clear}, state) do
    emulator = EmulatorLite.reset(state.emulator)
    {%{state | emulator: emulator}, []}
  end

  def update(_msg, state), do: {state, []}

  @impl true
  def handle_event(%{type: :key, data: %{key: key}}, state, _context) do
    buffer = EmulatorLite.get_active_buffer(state.emulator)
    char = key_to_char(key)
    updated_buffer = write_text_to_buffer(buffer, char)
    emulator = EmulatorLite.update_active_buffer(state.emulator, fn _buf -> updated_buffer end)
    {%{state | emulator: emulator}, []}
  end

  def handle_event(%{type: :resize, data: %{width: w, height: h}}, state, _context) do
    emulator = EmulatorLite.resize(state.emulator, w, h)
    {%{state | emulator: emulator, width: w, height: h}, []}
  end

  def handle_event(_event, state, _context), do: {state, []}

  @impl true
  @spec render(t(), map()) :: map()
  def render(state, _context) do
    buffer = EmulatorLite.get_active_buffer(state.emulator)
    rows = buffer_to_rows(buffer)

    %{
      type: :box,
      id: state.id,
      width: state.width,
      height: state.height,
      style: state.style,
      children: %{
        type: :column,
        children: rows
      }
    }
  end

  # Convert the screen buffer's cell grid into a list of styled text elements,
  # one per row. Adjacent cells with the same style are merged into runs.
  defp buffer_to_rows(%ScreenBuffer{} = buffer) do
    Enum.map(0..(buffer.height - 1), fn y ->
      row_cells = ScreenBuffer.get_line(buffer, y)
      spans = cells_to_spans(row_cells)

      case spans do
        [single] ->
          Components.text(content: single.text, style: single.style)

        multiple ->
          %{
            type: :row,
            children:
              Enum.map(multiple, fn span ->
                Components.text(content: span.text, style: span.style)
              end)
          }
      end
    end)
  end

  # Group adjacent cells with matching styles into text spans
  defp cells_to_spans([]), do: [%{text: "", style: %{}}]

  defp cells_to_spans(cells) do
    cells
    |> Enum.reduce([], fn cell, acc ->
      char = cell_char(cell)
      style = cell_to_style(cell)

      case acc do
        [%{style: ^style} = current | rest] ->
          [%{current | text: current.text <> char} | rest]

        _ ->
          [%{text: char, style: style} | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp cell_char(%Cell{char: nil}), do: " "
  defp cell_char(%Cell{char: ""}), do: " "
  defp cell_char(%Cell{char: char}), do: char
  # Handle map-style cells (from some buffer implementations)
  defp cell_char(%{char: char}) when is_integer(char), do: <<char::utf8>>
  defp cell_char(%{char: char}) when is_binary(char), do: char
  defp cell_char(_), do: " "

  defp cell_to_style(%Cell{style: nil}), do: %{}

  defp cell_to_style(%Cell{style: style}) when is_struct(style) do
    style
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> v == false or v == nil or v == :none end)
    |> Map.new()
  end

  defp cell_to_style(%{style: style}) when is_map(style) do
    style
    |> Enum.reject(fn {_k, v} -> v == false or v == nil or v == :none end)
    |> Map.new()
  end

  defp cell_to_style(_), do: %{}

  # Write a string into the buffer starting at the cursor position
  defp write_text_to_buffer(buffer, text) do
    {cursor_x, cursor_y} = buffer.cursor_position

    text
    |> String.graphemes()
    |> Enum.reduce({buffer, cursor_x, cursor_y}, fn char, {buf, x, y} ->
      case char do
        "\n" ->
          new_y = min(y + 1, buf.height - 1)
          buf = %{buf | cursor_position: {0, new_y}}
          {buf, 0, new_y}

        "\r" ->
          buf = %{buf | cursor_position: {0, y}}
          {buf, 0, y}

        _ ->
          if x < buf.width do
            buf = ScreenBuffer.write_char(buf, x, y, char)
            new_x = x + 1
            buf = %{buf | cursor_position: {new_x, y}}
            {buf, new_x, y}
          else
            # Wrap to next line
            new_y = min(y + 1, buf.height - 1)
            buf = ScreenBuffer.write_char(buf, 0, new_y, char)
            buf = %{buf | cursor_position: {1, new_y}}
            {buf, 1, new_y}
          end
      end
    end)
    |> elem(0)
  end

  defp key_to_char(key) when is_binary(key), do: key
  defp key_to_char(:enter), do: "\n"
  defp key_to_char(:space), do: " "
  defp key_to_char(:tab), do: "\t"
  defp key_to_char(key), do: inspect(key)
end
