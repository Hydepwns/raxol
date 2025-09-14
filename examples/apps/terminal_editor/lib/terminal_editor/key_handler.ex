defmodule TerminalEditor.KeyHandler do
  @moduledoc """
  Vi-style key handling for the terminal editor.

  Manages modal editing with different key bindings for each mode:
  - Normal mode: Navigation and commands
  - Insert mode: Text insertion
  - Visual mode: Text selection
  - Command mode: Ex commands
  - Search mode: Text search
  """

  alias TerminalEditor.{State, Cursor, Buffer, CommandProcessor}

  @doc """
  Handle key input based on current editor mode.
  """
  def handle_key(state, key_event) do
    case state.mode do
      :normal -> handle_normal_mode(state, key_event)
      :insert -> handle_insert_mode(state, key_event)
      :visual -> handle_visual_mode(state, key_event)
      :command -> handle_command_mode(state, key_event)
      :search -> handle_search_mode(state, key_event)
      _ -> {:ok, state}
    end
  end

  # Normal Mode Key Handling

  defp handle_normal_mode(state, %{key: "h", ctrl: false}) do
    move_cursor(state, :left)
  end

  defp handle_normal_mode(state, %{key: "j", ctrl: false}) do
    move_cursor(state, :down)
  end

  defp handle_normal_mode(state, %{key: "k", ctrl: false}) do
    move_cursor(state, :up)
  end

  defp handle_normal_mode(state, %{key: "l", ctrl: false}) do
    move_cursor(state, :right)
  end

  defp handle_normal_mode(state, %{key: "w", ctrl: false}) do
    move_cursor(state, :word_forward)
  end

  defp handle_normal_mode(state, %{key: "b", ctrl: false}) do
    move_cursor(state, :word_backward)
  end

  defp handle_normal_mode(state, %{key: "0", ctrl: false}) do
    move_cursor(state, :line_start)
  end

  defp handle_normal_mode(state, %{key: "$", ctrl: false}) do
    move_cursor(state, :line_end)
  end

  defp handle_normal_mode(state, %{key: "g", ctrl: false}) do
    # Handle 'gg' for go to top
    case state.last_key do
      "g" -> move_cursor(state, :file_start)
      _ -> {:ok, %{state | last_key: "g"}}
    end
  end

  defp handle_normal_mode(state, %{key: "G", ctrl: false}) do
    move_cursor(state, :file_end)
  end

  # Mode switching
  defp handle_normal_mode(state, %{key: "i", ctrl: false}) do
    {:ok, %{state | mode: :insert, status_message: "-- INSERT --"}}
  end

  defp handle_normal_mode(state, %{key: "a", ctrl: false}) do
    new_state =
      case move_cursor(state, :right) do
        {:ok, moved_state} -> moved_state
        _ -> state
      end

    {:ok, %{new_state | mode: :insert, status_message: "-- INSERT --"}}
  end

  defp handle_normal_mode(state, %{key: "I", ctrl: false}) do
    case move_cursor(state, :line_start) do
      {:ok, new_state} ->
        {:ok, %{new_state | mode: :insert, status_message: "-- INSERT --"}}

      error ->
        error
    end
  end

  defp handle_normal_mode(state, %{key: "A", ctrl: false}) do
    case move_cursor(state, :line_end) do
      {:ok, new_state} ->
        {:ok, %{new_state | mode: :insert, status_message: "-- INSERT --"}}

      error ->
        error
    end
  end

  defp handle_normal_mode(state, %{key: "o", ctrl: false}) do
    insert_new_line_below(state)
  end

  defp handle_normal_mode(state, %{key: "O", ctrl: false}) do
    insert_new_line_above(state)
  end

  defp handle_normal_mode(state, %{key: "v", ctrl: false}) do
    {:ok,
     %{
       state
       | mode: :visual,
         visual_start: {state.cursor.row, state.cursor.col},
         status_message: "-- VISUAL --"
     }}
  end

  defp handle_normal_mode(state, %{key: "V", ctrl: false}) do
    {:ok,
     %{
       state
       | mode: :visual_line,
         visual_start: {state.cursor.row, 0},
         status_message: "-- VISUAL LINE --"
     }}
  end

  # Editing commands
  defp handle_normal_mode(state, %{key: "d", ctrl: false}) do
    case state.last_key do
      "d" -> delete_current_line(state)
      _ -> {:ok, %{state | last_key: "d"}}
    end
  end

  defp handle_normal_mode(state, %{key: "x", ctrl: false}) do
    delete_char_under_cursor(state)
  end

  defp handle_normal_mode(state, %{key: "X", ctrl: false}) do
    delete_char_before_cursor(state)
  end

  defp handle_normal_mode(state, %{key: "y", ctrl: false}) do
    case state.last_key do
      "y" -> yank_current_line(state)
      _ -> {:ok, %{state | last_key: "y"}}
    end
  end

  defp handle_normal_mode(state, %{key: "p", ctrl: false}) do
    paste_after_cursor(state)
  end

  defp handle_normal_mode(state, %{key: "P", ctrl: false}) do
    paste_before_cursor(state)
  end

  # Undo/Redo
  defp handle_normal_mode(state, %{key: "u", ctrl: false}) do
    undo_last_change(state)
  end

  defp handle_normal_mode(state, %{key: "r", ctrl: true}) do
    redo_last_change(state)
  end

  # Search
  defp handle_normal_mode(state, %{key: "/", ctrl: false}) do
    {:ok,
     %{
       state
       | mode: :search,
         command_buffer: "",
         search_direction: :forward,
         status_message: ""
     }}
  end

  defp handle_normal_mode(state, %{key: "?", ctrl: false}) do
    {:ok,
     %{
       state
       | mode: :search,
         command_buffer: "",
         search_direction: :backward,
         status_message: ""
     }}
  end

  defp handle_normal_mode(state, %{key: "n", ctrl: false}) do
    search_next(state)
  end

  defp handle_normal_mode(state, %{key: "N", ctrl: false}) do
    search_previous(state)
  end

  # Command mode
  defp handle_normal_mode(state, %{key: ":", ctrl: false}) do
    {:ok,
     %{
       state
       | mode: :command,
         command_buffer: "",
         status_message: ""
     }}
  end

  # File operations
  defp handle_normal_mode(state, %{key: "s", ctrl: true}) do
    save_current_buffer(state)
  end

  # Default case - unknown key
  defp handle_normal_mode(state, _key_event) do
    {:ok, %{state | last_key: nil}}
  end

  # Insert Mode Key Handling

  defp handle_insert_mode(state, %{key: "Escape", ctrl: false}) do
    exit_insert_mode(state)
  end

  defp handle_insert_mode(state, %{key: key, ctrl: false})
       when byte_size(key) == 1 do
    insert_character(state, key)
  end

  defp handle_insert_mode(state, %{key: "Enter", ctrl: false}) do
    insert_newline(state)
  end

  defp handle_insert_mode(state, %{key: "Backspace", ctrl: false}) do
    delete_before_cursor(state)
  end

  defp handle_insert_mode(state, %{key: "Delete", ctrl: false}) do
    delete_char_under_cursor(state)
  end

  defp handle_insert_mode(state, %{key: "Tab", ctrl: false}) do
    insert_tab(state)
  end

  defp handle_insert_mode(state, %{key: "ArrowLeft", ctrl: false}) do
    move_cursor(state, :left)
  end

  defp handle_insert_mode(state, %{key: "ArrowRight", ctrl: false}) do
    move_cursor(state, :right)
  end

  defp handle_insert_mode(state, %{key: "ArrowUp", ctrl: false}) do
    move_cursor(state, :up)
  end

  defp handle_insert_mode(state, %{key: "ArrowDown", ctrl: false}) do
    move_cursor(state, :down)
  end

  # Save shortcut in insert mode
  defp handle_insert_mode(state, %{key: "s", ctrl: true}) do
    save_current_buffer(state)
  end

  defp handle_insert_mode(state, _key_event) do
    {:ok, state}
  end

  # Visual Mode Key Handling

  defp handle_visual_mode(state, %{key: "Escape", ctrl: false}) do
    {:ok,
     %{
       state
       | mode: :normal,
         visual_start: nil,
         status_message: ""
     }}
  end

  defp handle_visual_mode(state, %{key: key, ctrl: false})
       when key in ["h", "j", "k", "l", "w", "b", "0", "$"] do
    # Move cursor while maintaining selection
    case move_cursor(state, key_to_movement(key)) do
      {:ok, new_state} -> {:ok, new_state}
      error -> error
    end
  end

  defp handle_visual_mode(state, %{key: "d", ctrl: false}) do
    delete_visual_selection(state)
  end

  defp handle_visual_mode(state, %{key: "y", ctrl: false}) do
    yank_visual_selection(state)
  end

  defp handle_visual_mode(state, _key_event) do
    {:ok, state}
  end

  # Command and Search Mode Handling

  defp handle_command_mode(state, %{key: "Enter", ctrl: false}) do
    execute_command(state)
  end

  defp handle_command_mode(state, %{key: "Escape", ctrl: false}) do
    {:ok, %{state | mode: :normal, command_buffer: "", status_message: ""}}
  end

  defp handle_command_mode(state, %{key: key, ctrl: false})
       when byte_size(key) == 1 do
    {:ok, %{state | command_buffer: state.command_buffer <> key}}
  end

  defp handle_command_mode(state, %{key: "Backspace", ctrl: false}) do
    new_buffer = String.slice(state.command_buffer, 0..-2)
    {:ok, %{state | command_buffer: new_buffer}}
  end

  defp handle_command_mode(state, _key_event) do
    {:ok, state}
  end

  defp handle_search_mode(state, %{key: "Enter", ctrl: false}) do
    execute_search(state)
  end

  defp handle_search_mode(state, %{key: "Escape", ctrl: false}) do
    {:ok, %{state | mode: :normal, command_buffer: "", status_message: ""}}
  end

  defp handle_search_mode(state, %{key: key, ctrl: false})
       when byte_size(key) == 1 do
    {:ok, %{state | command_buffer: state.command_buffer <> key}}
  end

  defp handle_search_mode(state, %{key: "Backspace", ctrl: false}) do
    new_buffer = String.slice(state.command_buffer, 0..-2)
    {:ok, %{state | command_buffer: new_buffer}}
  end

  defp handle_search_mode(state, _key_event) do
    {:ok, state}
  end

  # Movement Implementation

  defp move_cursor(state, direction) do
    current_buffer = get_current_buffer(state)
    new_cursor = Cursor.move(state.cursor, direction, current_buffer)

    case new_cursor do
      {:ok, cursor} ->
        {:ok, %{state | cursor: cursor}}

      {:error, reason} ->
        {:ok, %{state | status_message: "Cannot move cursor: #{reason}"}}
    end
  end

  # Editing Operations

  defp insert_character(state, char) do
    current_buffer = get_current_buffer(state)

    case Buffer.insert_text(
           current_buffer,
           state.cursor.row,
           state.cursor.col,
           char
         ) do
      {:ok, new_buffer} ->
        new_buffers =
          List.replace_at(state.buffers, state.current_buffer, new_buffer)

        new_cursor = %{state.cursor | col: state.cursor.col + 1}

        {:ok,
         %{
           state
           | buffers: new_buffers,
             cursor: new_cursor,
             status_message: ""
         }}

      {:error, reason} ->
        {:ok, %{state | status_message: "Error: #{reason}"}}
    end
  end

  defp insert_newline(state) do
    current_buffer = get_current_buffer(state)

    # Split current line at cursor position
    current_line = Enum.at(current_buffer.lines, state.cursor.row)
    before_cursor = String.slice(current_line, 0, state.cursor.col)
    after_cursor = String.slice(current_line, state.cursor.col..-1)

    # Replace current line and insert new line
    new_lines =
      current_buffer.lines
      |> List.replace_at(state.cursor.row, before_cursor)
      |> List.insert_at(state.cursor.row + 1, after_cursor)

    new_buffer = %{current_buffer | lines: new_lines, modified: true}

    new_buffers =
      List.replace_at(state.buffers, state.current_buffer, new_buffer)

    new_cursor = %{state.cursor | row: state.cursor.row + 1, col: 0}

    {:ok,
     %{
       state
       | buffers: new_buffers,
         cursor: new_cursor,
         status_message: ""
     }}
  end

  defp insert_tab(state) do
    tab_string = String.duplicate(" ", state.config.tab_width)
    insert_character(state, tab_string)
  end

  defp delete_before_cursor(state) do
    if state.cursor.col > 0 do
      current_buffer = get_current_buffer(state)

      case Buffer.delete_range(
             current_buffer,
             state.cursor.row,
             state.cursor.col - 1,
             state.cursor.row,
             state.cursor.col
           ) do
        {:ok, new_buffer} ->
          new_buffers =
            List.replace_at(state.buffers, state.current_buffer, new_buffer)

          new_cursor = %{state.cursor | col: state.cursor.col - 1}

          {:ok,
           %{
             state
             | buffers: new_buffers,
               cursor: new_cursor
           }}

        {:error, reason} ->
          {:ok, %{state | status_message: "Error: #{reason}"}}
      end
    else
      # Handle joining with previous line
      if state.cursor.row > 0 do
        join_with_previous_line(state)
      else
        {:ok, state}
      end
    end
  end

  defp delete_char_under_cursor(state) do
    current_buffer = get_current_buffer(state)
    current_line = Enum.at(current_buffer.lines, state.cursor.row)

    if state.cursor.col < String.length(current_line) do
      case Buffer.delete_range(
             current_buffer,
             state.cursor.row,
             state.cursor.col,
             state.cursor.row,
             state.cursor.col + 1
           ) do
        {:ok, new_buffer} ->
          new_buffers =
            List.replace_at(state.buffers, state.current_buffer, new_buffer)

          {:ok, %{state | buffers: new_buffers}}

        {:error, reason} ->
          {:ok, %{state | status_message: "Error: #{reason}"}}
      end
    else
      {:ok, state}
    end
  end

  defp delete_current_line(state) do
    current_buffer = get_current_buffer(state)

    case Buffer.delete_line(current_buffer, state.cursor.row) do
      {:ok, new_buffer} ->
        new_buffers =
          List.replace_at(state.buffers, state.current_buffer, new_buffer)

        # Adjust cursor position
        new_row = min(state.cursor.row, length(new_buffer.lines) - 1)
        new_cursor = %{state.cursor | row: new_row, col: 0}

        {:ok,
         %{
           state
           | buffers: new_buffers,
             cursor: new_cursor,
             status_message: "Line deleted"
         }}

      {:error, reason} ->
        {:ok, %{state | status_message: "Error: #{reason}"}}
    end
  end

  defp insert_new_line_below(state) do
    current_buffer = get_current_buffer(state)
    new_lines = List.insert_at(current_buffer.lines, state.cursor.row + 1, "")

    new_buffer = %{current_buffer | lines: new_lines, modified: true}

    new_buffers =
      List.replace_at(state.buffers, state.current_buffer, new_buffer)

    new_cursor = %{state.cursor | row: state.cursor.row + 1, col: 0}

    {:ok,
     %{
       state
       | buffers: new_buffers,
         cursor: new_cursor,
         mode: :insert,
         status_message: "-- INSERT --"
     }}
  end

  defp insert_new_line_above(state) do
    current_buffer = get_current_buffer(state)
    new_lines = List.insert_at(current_buffer.lines, state.cursor.row, "")

    new_buffer = %{current_buffer | lines: new_lines, modified: true}

    new_buffers =
      List.replace_at(state.buffers, state.current_buffer, new_buffer)

    new_cursor = %{state.cursor | col: 0}

    {:ok,
     %{
       state
       | buffers: new_buffers,
         cursor: new_cursor,
         mode: :insert,
         status_message: "-- INSERT --"
     }}
  end

  defp exit_insert_mode(state) do
    # Move cursor back if not at beginning of line
    new_col = max(0, state.cursor.col - 1)
    new_cursor = %{state.cursor | col: new_col}

    {:ok,
     %{
       state
       | mode: :normal,
         cursor: new_cursor,
         status_message: ""
     }}
  end

  # Placeholder implementations for complex operations

  defp join_with_previous_line(state) do
    # Implementation for backspace at line start
    {:ok, state}
  end

  defp yank_current_line(state) do
    current_buffer = get_current_buffer(state)
    current_line = Enum.at(current_buffer.lines, state.cursor.row)

    {:ok,
     %{
       state
       | clipboard: [current_line],
         status_message: "Line yanked"
     }}
  end

  defp paste_after_cursor(state) do
    if state.clipboard != [] do
      # Simplified paste implementation
      {:ok, %{state | status_message: "Text pasted"}}
    else
      {:ok, %{state | status_message: "Nothing to paste"}}
    end
  end

  defp paste_before_cursor(state) do
    if state.clipboard != [] do
      {:ok, %{state | status_message: "Text pasted"}}
    else
      {:ok, %{state | status_message: "Nothing to paste"}}
    end
  end

  defp undo_last_change(state) do
    {:ok, %{state | status_message: "Undo not implemented yet"}}
  end

  defp redo_last_change(state) do
    {:ok, %{state | status_message: "Redo not implemented yet"}}
  end

  defp delete_visual_selection(state) do
    {:ok,
     %{
       state
       | mode: :normal,
         visual_start: nil,
         status_message: "Selection deleted"
     }}
  end

  defp yank_visual_selection(state) do
    {:ok,
     %{
       state
       | mode: :normal,
         visual_start: nil,
         status_message: "Selection yanked"
     }}
  end

  defp search_next(state) do
    {:ok, %{state | status_message: "Search next not implemented"}}
  end

  defp search_previous(state) do
    {:ok, %{state | status_message: "Search previous not implemented"}}
  end

  defp execute_command(state) do
    case CommandProcessor.execute(state.command_buffer, state) do
      {:ok, new_state} ->
        {:ok, %{new_state | mode: :normal, command_buffer: ""}}

      {:error, reason} ->
        {:ok,
         %{
           state
           | mode: :normal,
             command_buffer: "",
             status_message: "Error: #{reason}"
         }}
    end
  end

  defp execute_search(state) do
    # Simplified search execution
    {:ok,
     %{
       state
       | mode: :normal,
         command_buffer: "",
         search_query: state.command_buffer,
         status_message: "Search: #{state.command_buffer}"
     }}
  end

  defp save_current_buffer(state) do
    current_buffer = get_current_buffer(state)

    case Buffer.save(current_buffer) do
      {:ok, saved_buffer} ->
        new_buffers =
          List.replace_at(state.buffers, state.current_buffer, saved_buffer)

        {:ok,
         %{
           state
           | buffers: new_buffers,
             status_message: "File saved"
         }}

      {:error, reason} ->
        {:ok, %{state | status_message: "Save failed: #{reason}"}}
    end
  end

  # Helper functions

  defp get_current_buffer(state) do
    Enum.at(state.buffers, state.current_buffer)
  end

  defp key_to_movement(key) do
    case key do
      "h" -> :left
      "j" -> :down
      "k" -> :up
      "l" -> :right
      "w" -> :word_forward
      "b" -> :word_backward
      "0" -> :line_start
      "$" -> :line_end
    end
  end
end
