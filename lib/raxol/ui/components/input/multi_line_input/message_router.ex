defmodule Raxol.UI.Components.Input.MultiLineInput.MessageRouter do
  @moduledoc """
  Message routing for MultiLineInput component.
  Handles routing different message types to appropriate handler functions.
  """

  alias Raxol.UI.Components.Input.MultiLineInput

  @doc """
  Routes messages to appropriate handler functions.
  Returns {:ok, result} if message was handled, :error if not.
  """
  @spec route(any(), MultiLineInput.t()) :: {:ok, any()} | :error
  def route(msg, state), do: do_route(msg, state)

  # Focus and blur
  defp do_route(:focus, state),
    do: {:ok, MultiLineInput.handle_focus(state)}

  defp do_route(:blur, state),
    do: {:ok, MultiLineInput.handle_blur(state)}

  # Text input
  defp do_route({:input, char_codepoint}, state),
    do: {:ok, MultiLineInput.handle_input(char_codepoint, state)}

  # Text editing
  defp do_route({:backspace}, state),
    do: {:ok, MultiLineInput.handle_backspace(state)}

  defp do_route({:delete}, state),
    do: {:ok, MultiLineInput.handle_delete(state)}

  defp do_route({:enter}, state),
    do: {:ok, MultiLineInput.handle_enter(state)}

  # Cursor movement
  defp do_route({:move_cursor, direction}, state),
    do: {:ok, MultiLineInput.handle_move_cursor(direction, state)}

  defp do_route({:move_cursor_line_start}, state),
    do: {:ok, MultiLineInput.handle_move_cursor_line_start(state)}

  defp do_route({:move_cursor_line_end}, state),
    do: {:ok, MultiLineInput.handle_move_cursor_line_end(state)}

  defp do_route({:move_cursor_page, direction}, state),
    do: {:ok, MultiLineInput.handle_move_cursor_page(direction, state)}

  defp do_route({:move_cursor_doc_start}, state),
    do: {:ok, MultiLineInput.handle_move_cursor_doc_start(state)}

  defp do_route({:move_cursor_doc_end}, state),
    do: {:ok, MultiLineInput.handle_move_cursor_doc_end(state)}

  defp do_route({:move_cursor_to, position}, state),
    do: {:ok, MultiLineInput.handle_move_cursor_to(position, state)}

  defp do_route({:move_cursor_word_left}, state),
    do: {:ok, MultiLineInput.handle_move_cursor_word_left(state)}

  defp do_route({:move_cursor_word_right}, state),
    do: {:ok, MultiLineInput.handle_move_cursor_word_right(state)}

  # Selection
  defp do_route({:select_all}, state),
    do: {:ok, MultiLineInput.handle_select_all(state)}

  defp do_route({:select_to, position}, state),
    do: {:ok, MultiLineInput.handle_select_to(position, state)}

  defp do_route({:selection_move, direction}, state),
    do: {:ok, MultiLineInput.handle_selection_move(state, direction)}

  defp do_route({:copy_selection}, state),
    do: {:ok, MultiLineInput.handle_copy_selection(state)}

  defp do_route({:delete_selection, direction}, state),
    do: {:ok, MultiLineInput.handle_delete_selection(direction, state)}

  # Clipboard operations
  defp do_route({:copy}, state),
    do: {:ok, MultiLineInput.handle_copy(state)}

  defp do_route({:cut}, state),
    do: {:ok, MultiLineInput.handle_cut(state)}

  defp do_route({:paste}, state),
    do: {:ok, MultiLineInput.handle_paste(state)}

  defp do_route({:clipboard_content, content}, state),
    do: {:ok, MultiLineInput.handle_clipboard_content(content, state)}

  # Undo/redo
  defp do_route(:undo, state),
    do: {:ok, MultiLineInput.handle_undo(state)}

  defp do_route(:redo, state),
    do: {:ok, MultiLineInput.handle_redo(state)}

  # State changes
  defp do_route({:set_shift_held, held}, state),
    do: {:ok, MultiLineInput.handle_set_shift_held(held, state)}

  defp do_route({:update_props, new_props}, state),
    do: {:ok, MultiLineInput.handle_update_props(new_props, state)}

  # Properties update
  defp do_route({:set_value, new_value}, state) do
    new_state = %{state | value: new_value}

    new_lines =
      MultiLineInput.TextHelper.split_into_lines(
        new_value,
        state.width,
        state.wrap
      )

    final_state = %{new_state | lines: new_lines, cursor_pos: {0, 0}}
    {:ok, {:noreply, final_state, nil}}
  end

  # Unknown message
  defp do_route(_msg, _state), do: :error
end
