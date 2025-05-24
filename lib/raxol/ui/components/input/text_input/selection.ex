defmodule Raxol.UI.Components.Input.TextInput.Selection do
  @moduledoc """
  Handles cursor and text selection operations for the TextInput component.
  This includes cursor movement, text selection, and selection clearing.
  """

  @doc """
  Moves the cursor by the specified offset, ensuring it stays within bounds.
  """
  def move_cursor(state, offset) do
    new_cursor = max(0, min(String.length(state.value), state.cursor + offset))
    %{state | cursor: new_cursor}
  end

  @doc """
  Moves the cursor to the start of the text.
  """
  def move_to_home(state) do
    %{state | cursor: 0}
  end

  @doc """
  Moves the cursor to the end of the text.
  """
  def move_to_end(state) do
    %{state | cursor: String.length(state.value)}
  end

  @doc """
  Extends or creates a text selection by moving the cursor.
  """
  def select_text(state, offset) do
    new_cursor = max(0, min(String.length(state.value), state.cursor + offset))

    case state.selection do
      {start, _len} ->
        # Extend existing selection
        if new_cursor < start do
          %{
            state
            | cursor: new_cursor,
              selection: {new_cursor, start - new_cursor}
          }
        else
          %{state | cursor: new_cursor, selection: {start, new_cursor - start}}
        end

      nil ->
        # Start new selection
        if new_cursor < state.cursor do
          %{
            state
            | cursor: new_cursor,
              selection: {new_cursor, state.cursor - new_cursor}
          }
        else
          %{
            state
            | cursor: new_cursor,
              selection: {state.cursor, new_cursor - state.cursor}
          }
        end
    end
  end

  @doc """
  Selects text from the current cursor position to the start of the text.
  """
  def select_to_home(state) do
    case state.selection do
      {start, _len} ->
        %{state | cursor: 0, selection: {0, start}}

      nil ->
        %{state | cursor: 0, selection: {0, state.cursor}}
    end
  end

  @doc """
  Selects text from the current cursor position to the end of the text.
  """
  def select_to_end(state) do
    len = String.length(state.value)

    case state.selection do
      {start, _len} ->
        %{state | cursor: len, selection: {start, len - start}}

      nil ->
        %{state | cursor: len, selection: {state.cursor, len - state.cursor}}
    end
  end

  @doc """
  Clears any existing text selection.
  """
  def clear_selection(state) do
    %{state | selection: nil}
  end

  @doc """
  Gets the currently selected text, if any.
  """
  def get_selected_text(state) do
    case state.selection do
      {start, len} -> String.slice(state.value, start, len)
      nil -> nil
    end
  end
end
