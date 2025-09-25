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
  def route(msg, state) do
    case msg do
      # Focus and blur
      :focus ->
        {:ok, MultiLineInput.handle_focus(state)}

      :blur ->
        {:ok, MultiLineInput.handle_blur(state)}

      # Text input
      {:input, char_codepoint} ->
        {:ok, MultiLineInput.handle_input(char_codepoint, state)}

      # Text editing
      {:backspace} ->
        {:ok, MultiLineInput.handle_backspace(state)}

      {:delete} ->
        {:ok, MultiLineInput.handle_delete(state)}

      {:enter} ->
        {:ok, MultiLineInput.handle_enter(state)}

      # Cursor movement
      {:move_cursor, direction} ->
        {:ok, MultiLineInput.handle_move_cursor(direction, state)}

      {:move_cursor_line_start} ->
        {:ok, MultiLineInput.handle_move_cursor_line_start(state)}

      {:move_cursor_line_end} ->
        {:ok, MultiLineInput.handle_move_cursor_line_end(state)}

      {:move_cursor_page, direction} ->
        {:ok, MultiLineInput.handle_move_cursor_page(direction, state)}

      {:move_cursor_doc_start} ->
        {:ok, MultiLineInput.handle_move_cursor_doc_start(state)}

      {:move_cursor_doc_end} ->
        {:ok, MultiLineInput.handle_move_cursor_doc_end(state)}

      {:move_cursor_to, position} ->
        {:ok, MultiLineInput.handle_move_cursor_to(position, state)}

      {:move_cursor_word_left} ->
        {:ok, MultiLineInput.handle_move_cursor_word_left(state)}

      {:move_cursor_word_right} ->
        {:ok, MultiLineInput.handle_move_cursor_word_right(state)}

      # Selection
      {:select_all} ->
        {:ok, MultiLineInput.handle_select_all(state)}

      {:select_to, position} ->
        {:ok, MultiLineInput.handle_select_to(position, state)}

      {:selection_move, direction} ->
        {:ok, MultiLineInput.handle_selection_move(state, direction)}

      {:copy_selection} ->
        {:ok, MultiLineInput.handle_copy_selection(state)}

      {:delete_selection, direction} ->
        {:ok, MultiLineInput.handle_delete_selection(direction, state)}

      # Clipboard operations
      {:copy} ->
        {:ok, MultiLineInput.handle_copy(state)}

      {:cut} ->
        {:ok, MultiLineInput.handle_cut(state)}

      {:paste} ->
        {:ok, MultiLineInput.handle_paste(state)}

      {:clipboard_content, content} ->
        {:ok, MultiLineInput.handle_clipboard_content(content, state)}

      # State changes
      {:set_shift_held, held} ->
        {:ok, MultiLineInput.handle_set_shift_held(held, state)}

      {:update_props, new_props} ->
        {:ok, MultiLineInput.handle_update_props(new_props, state)}

      # Properties update
      {:set_value, new_value} ->
        new_state = %{state | value: new_value}

        new_lines =
          MultiLineInput.TextHelper.split_into_lines(
            new_value,
            state.width,
            state.wrap
          )

        final_state = %{new_state | lines: new_lines, cursor_pos: {0, 0}}
        {:ok, {:noreply, final_state, nil}}

      # Unknown message
      _ ->
        :error
    end
  end
end
