defmodule Raxol.Components.Input.TextInput.Manipulation do
  @moduledoc """
  Handles text manipulation operations for the TextInput component.
  This includes inserting, deleting, and pasting text.
  """

  alias Raxol.Components.Input.TextInput.Validation

  @doc """
  Inserts a character at the current cursor position.
  """
  def insert_char(state, char) do
    {before_cursor, after_cursor} = String.split_at(state.value, state.cursor)
    new_value = before_cursor <> <<char::utf8>> <> after_cursor
    %{state | value: new_value, cursor: state.cursor + 1}
  end

  @doc """
  Deletes the character before the cursor.
  """
  def delete_char_backward(%{cursor: 0} = state), do: state

  def delete_char_backward(state) do
    {before_cursor, after_cursor} =
      String.split_at(state.value, state.cursor - 1)

    # Delete character *before* cursor
    new_value = String.slice(before_cursor, 0, state.cursor - 1) <> after_cursor
    %{state | value: new_value, cursor: state.cursor - 1}
  end

  @doc """
  Deletes a character forward from the current cursor position.
  """
  def delete_char_forward(state) do
    if state.cursor_position < String.length(state.value) do
      new_value =
        state.value
        |> String.split_at(state.cursor_position)
        |> then(fn {before, rest} -> before <> String.slice(rest, 1..-1//1) end)

      %{state | value: new_value}
    else
      state
    end
  end

  @doc """
  Deletes the selected text and updates the cursor position.
  """
  def delete_selected_text(state, start, len) do
    {before, rest} = String.split_at(state.value, start)
    rest = String.slice(rest, len..-1)
    state = %{state | value: before <> rest, cursor: start, selection: nil}
    Validation.validate_input(state)
  end

  @doc """
  Pastes text at the specified position, optionally replacing selected text.
  """
  def paste_at_position(state, text, position, selection_len) do
    {before, rest} = String.split_at(state.value, position)
    rest = String.slice(rest, selection_len..-1)
    new_value = before <> text <> rest

    if Validation.would_exceed_max_length?(state, new_value) do
      state
    else
      state = %{
        state
        | value: new_value,
          cursor: position + String.length(text),
          selection: nil
      }

      Validation.validate_input(state)
    end
  end
end
