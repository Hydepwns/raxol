defmodule Raxol.Terminal.Selection.Manager do
  @moduledoc """
  Manages text selection operations in the terminal.
  """

  defstruct start_pos: nil,
            end_pos: nil,
            active: false,
            # :normal, :word, :line
            mode: :normal,
            scrollback_included: false

  @type position :: {non_neg_integer(), non_neg_integer()}
  @type selection_mode :: :normal | :word | :line

  @type t :: %__MODULE__{
          start_pos: position() | nil,
          end_pos: position() | nil,
          active: boolean(),
          mode: selection_mode(),
          scrollback_included: boolean()
        }

  @doc """
  Creates a new selection manager instance.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Starts a new selection at the given position.
  """
  def start_selection(%__MODULE__{} = state, pos, mode \\ :normal)
      when is_tuple(pos) and tuple_size(pos) == 2 and
             mode in [:normal, :word, :line] do
    %{state | start_pos: pos, end_pos: pos, active: true, mode: mode}
  end

  @doc """
  Updates the selection end position.
  """
  def update_selection(%__MODULE__{} = state, pos)
      when is_tuple(pos) and tuple_size(pos) == 2 do
    update_selection_if_active(state.active, state, pos)
  end

  @doc """
  Ends the current selection.
  """
  def end_selection(%__MODULE__{} = state) do
    %{state | active: false, start_pos: nil, end_pos: nil}
  end

  @doc """
  Gets the current selection range.
  """
  def get_selection_range(%__MODULE__{} = state) do
    get_range_if_valid(
      state.active and state.start_pos and state.end_pos,
      state
    )
  end

  @doc """
  Checks if a position is within the current selection.
  """
  def position_in_selection?(%__MODULE__{} = state, pos)
      when is_tuple(pos) and tuple_size(pos) == 2 do
    check_position_in_selection(
      state.active and state.start_pos and state.end_pos,
      state,
      pos
    )
  end

  @doc """
  Gets the selected text from the terminal buffer.
  """
  def get_selected_text(%__MODULE__{} = state, buffer) do
    get_text_if_valid_selection(
      state.active and state.start_pos and state.end_pos,
      state,
      buffer
    )
  end

  @doc """
  Includes scrollback buffer in selection.
  """
  def include_scrollback(%__MODULE__{} = state, include \\ true) do
    %{state | scrollback_included: include}
  end

  @doc """
  Checks if scrollback is included in selection.
  """
  def scrollback_included?(%__MODULE__{} = state) do
    state.scrollback_included
  end

  # Private helper functions

  defp update_selection_if_active(false, state, _pos), do: state
  defp update_selection_if_active(true, state, pos), do: %{state | end_pos: pos}

  defp get_range_if_valid(false, _state), do: nil
  defp get_range_if_valid(true, state), do: {state.start_pos, state.end_pos}

  defp check_position_in_selection(false, _state, _pos), do: false

  defp check_position_in_selection(true, state, pos) do
    {start_x, start_y} = state.start_pos
    {end_x, end_y} = state.end_pos
    {x, y} = pos

    check_line_type_selection(
      start_y == end_y,
      y,
      x,
      start_y,
      end_y,
      start_x,
      end_x
    )
  end

  defp check_line_type_selection(true, y, x, start_y, _end_y, start_x, end_x) do
    # Single line selection
    y == start_y and x >= min(start_x, end_x) and x <= max(start_x, end_x)
  end

  defp check_line_type_selection(false, y, x, start_y, end_y, start_x, end_x) do
    # Multi-line selection
    check_multiline_position(y, x, start_y, end_y, start_x, end_x)
  end

  defp get_text_if_valid_selection(false, _state, _buffer), do: ""

  defp get_text_if_valid_selection(true, state, buffer) do
    {start_x, start_y} = state.start_pos
    {end_x, end_y} = state.end_pos

    get_text_by_line_type(
      start_y == end_y,
      buffer,
      start_y,
      end_y,
      start_x,
      end_x
    )
  end

  defp get_text_by_line_type(true, buffer, start_y, _end_y, start_x, end_x) do
    get_line_selection(buffer, start_y, start_x, end_x)
  end

  defp get_text_by_line_type(false, buffer, start_y, end_y, start_x, end_x) do
    get_multiline_selection(buffer, start_y, end_y, start_x, end_x)
  end

  defp get_line_selection(buffer, y, start_x, end_x) do
    case Enum.at(buffer, y) do
      nil ->
        ""

      line ->
        start_idx = min(start_x, end_x)
        end_idx = max(start_x, end_x)
        String.slice(line, start_idx, end_idx - start_idx + 1)
    end
  end

  defp get_multiline_selection(buffer, start_y, end_y, start_x, end_x) do
    buffer
    |> Enum.slice(start_y..end_y)
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {line, idx} ->
      slice_line_by_index(line, idx, end_y - start_y, start_x, end_x)
    end)
  end

  defp check_multiline_position(y, x, start_y, end_y, start_x, end_x)
       when y == start_y,
       do: x >= start_x

  defp check_multiline_position(y, x, start_y, end_y, start_x, end_x)
       when y == end_y,
       do: x <= end_x

  defp check_multiline_position(y, x, start_y, end_y, start_x, end_x)
       when y > start_y and y < end_y,
       do: true

  defp check_multiline_position(_y, _x, _start_y, _end_y, _start_x, _end_x),
    do: false

  defp slice_line_by_index(line, 0, _last_index, start_x, _end_x) do
    String.slice(line, start_x..-1)
  end

  defp slice_line_by_index(line, idx, last_index, _start_x, end_x)
       when idx == last_index do
    String.slice(line, 0..end_x)
  end

  defp slice_line_by_index(line, _idx, _last_index, _start_x, _end_x), do: line
end
