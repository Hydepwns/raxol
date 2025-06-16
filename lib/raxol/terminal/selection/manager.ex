defmodule Raxol.Terminal.Selection.Manager do
  @moduledoc """
  Manages text selection operations in the terminal.
  """

  defstruct [
    start_pos: nil,
    end_pos: nil,
    active: false,
    mode: :normal,  # :normal, :word, :line
    scrollback_included: false
  ]

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
      when is_tuple(pos) and tuple_size(pos) == 2
      and mode in [:normal, :word, :line] do
    %{state |
      start_pos: pos,
      end_pos: pos,
      active: true,
      mode: mode
    }
  end

  @doc """
  Updates the selection end position.
  """
  def update_selection(%__MODULE__{} = state, pos)
      when is_tuple(pos) and tuple_size(pos) == 2 do
    if state.active do
      %{state | end_pos: pos}
    else
      state
    end
  end

  @doc """
  Ends the current selection.
  """
  def end_selection(%__MODULE__{} = state) do
    %{state |
      active: false,
      start_pos: nil,
      end_pos: nil
    }
  end

  @doc """
  Gets the current selection range.
  """
  def get_selection_range(%__MODULE__{} = state) do
    if state.active and state.start_pos and state.end_pos do
      {state.start_pos, state.end_pos}
    else
      nil
    end
  end

  @doc """
  Checks if a position is within the current selection.
  """
  def position_in_selection?(%__MODULE__{} = state, pos)
      when is_tuple(pos) and tuple_size(pos) == 2 do
    if state.active and state.start_pos and state.end_pos do
      {start_x, start_y} = state.start_pos
      {end_x, end_y} = state.end_pos
      {x, y} = pos

      cond do
        # Single line selection
        start_y == end_y ->
          y == start_y and x >= min(start_x, end_x) and x <= max(start_x, end_x)

        # Multi-line selection
        true ->
          cond do
            # First line
            y == start_y ->
              x >= start_x

            # Last line
            y == end_y ->
              x <= end_x

            # Middle lines
            y > start_y and y < end_y ->
              true

            # Outside selection
            true ->
              false
          end
      end
    else
      false
    end
  end

  @doc """
  Gets the selected text from the terminal buffer.
  """
  def get_selected_text(%__MODULE__{} = state, buffer) do
    if state.active and state.start_pos and state.end_pos do
      {start_x, start_y} = state.start_pos
      {end_x, end_y} = state.end_pos

      cond do
        # Single line selection
        start_y == end_y ->
          get_line_selection(buffer, start_y, start_x, end_x)

        # Multi-line selection
        true ->
          get_multiline_selection(buffer, start_y, end_y, start_x, end_x)
      end
    else
      ""
    end
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

  defp get_line_selection(buffer, y, start_x, end_x) do
    case Enum.at(buffer, y) do
      nil -> ""
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
    |> Enum.map(fn {line, idx} ->
      cond do
        # First line
        idx == 0 ->
          String.slice(line, start_x..-1)

        # Last line
        idx == end_y - start_y ->
          String.slice(line, 0..end_x)

        # Middle lines
        true ->
          line
      end
    end)
    |> Enum.join("\n")
  end
end
