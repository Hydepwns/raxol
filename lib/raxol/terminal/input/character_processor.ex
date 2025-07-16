defmodule Raxol.Terminal.Input.CharacterProcessor do
  @moduledoc """
  Handles character processing, translation, and writing to the terminal buffer.
  """

  alias Raxol.Terminal.{Emulator, ScreenBuffer, CharacterHandling}
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.Buffer.Operations
  alias Raxol.Terminal.ModeManager

  require Raxol.Core.Runtime.Log

  @doc """
  Processes a single character codepoint.
  Delegates to C0 handlers or printable character handlers.
  """
  @spec process_character(Emulator.t(), integer()) :: Emulator.t()
  def process_character(emulator, char_codepoint)
      when (char_codepoint >= 0 and char_codepoint <= 31) or
             char_codepoint == 127 do
    Raxol.Terminal.ControlCodes.handle_c0(emulator, char_codepoint)
  end

  def process_character(emulator, char_codepoint) do
    process_printable_character(emulator, char_codepoint)
  end

  def process_printable_character(emulator, char_codepoint) do
    buffer_width = get_buffer_width(emulator)
    buffer_height = get_buffer_height(emulator)

    {translated_char, new_charset_state} =
      CharacterSets.translate_char(char_codepoint, emulator.charset_state)

    {write_x, write_y, next_cursor_x, next_cursor_y, next_last_col_exceeded} =
      calculate_positions(emulator, buffer_width, char_codepoint)

    # Check if autowrap would cause an out-of-bounds write
    auto_wrap_mode = ModeManager.mode_enabled?(emulator.mode_manager, :decawm)

    # Get the original write_y before adjustment to detect autowrap
    {original_write_x, original_write_y, _, _, _} =
      calculate_write_and_cursor_position(
        get_cursor_position_safe(emulator.cursor) |> elem(0),
        get_cursor_position_safe(emulator.cursor) |> elem(1),
        buffer_width,
        CharacterHandling.get_char_width(char_codepoint),
        emulator.last_col_exceeded,
        auto_wrap_mode
      )

    autowrap_out_of_bounds = original_write_y >= buffer_height and auto_wrap_mode and emulator.last_col_exceeded

    # Write the character to the buffer
    emulator_after_write =
      write_character(
        emulator,
        char_codepoint,
        emulator.style
      )

    updated_emulator =
      update_emulator_state(
        emulator_after_write,
        next_cursor_x,
        next_cursor_y,
        next_last_col_exceeded,
        new_charset_state
      )

    # Handle scrolling and autowrap
    if original_write_y >= buffer_height do
      # Check if this was an autowrap that went out of bounds
      if autowrap_out_of_bounds do
        # Set the flag BEFORE scrolling to prevent scroll from overriding cursor position
        updated_emulator_with_flag = %{updated_emulator | cursor_handled_by_autowrap: true}

        # Scroll the emulator (the flag will prevent scroll from overriding cursor position)
        scrolled_emulator = Emulator.maybe_scroll(updated_emulator_with_flag)
        # Write character after scroll
        {translated_char, _} = CharacterSets.translate_char(char_codepoint, scrolled_emulator.charset_state)
        translated_char_str = <<translated_char::utf8>>

        buffer_for_write = Emulator.get_active_buffer(scrolled_emulator)
        buffer_after_write =
          Operations.write_char(
            buffer_for_write,
            0,  # Write at column 0 of the new line
            0,  # Write at row 0 (the new line after scroll)
            translated_char_str,
            scrolled_emulator.style
          )

        final_emulator = Emulator.update_active_buffer(scrolled_emulator, buffer_after_write)

        # Always set cursor to {char_width, 0} after autowrap and scroll, overriding scroll logic
        char_width = CharacterHandling.get_char_width(char_codepoint)
        final_emulator = case final_emulator.cursor do
          cursor when is_pid(cursor) ->
            Raxol.Terminal.Cursor.Manager.set_position(cursor, {char_width, 0})
            final_emulator
          cursor when is_map(cursor) ->
            updated_cursor = Raxol.Terminal.Cursor.Manager.set_position(cursor, {char_width, 0})
            %{final_emulator | cursor: updated_cursor}
          _ ->
            final_emulator
        end

        # Return early
        final_emulator
      else
        # Scroll as usual if not autowrap out of bounds
        Emulator.maybe_scroll(updated_emulator)
      end
    else
      updated_emulator
    end
  end

  defp maybe_advance_cursor_at_last_position(
         emulator,
         buffer_width,
         buffer_height
       ) do
    {cursor_x, cursor_y} = get_cursor_position_safe(emulator.cursor)

    # Trigger scroll if cursor is at the last row (not just the last column)
    if cursor_y == buffer_height - 1 do
      updated_emulator =
        case emulator.cursor do
          cursor when is_pid(cursor) ->
            GenServer.call(cursor, {:move_to, 0, buffer_height - 1})
            emulator

          cursor when is_map(cursor) ->
            updated_cursor =
              Raxol.Terminal.Cursor.Manager.move_to(
                cursor,
                0,
                buffer_height - 1
              )

            %{emulator | cursor: updated_cursor}

          _ ->
            emulator
        end

      Emulator.maybe_scroll(updated_emulator)
    else
      emulator
    end
  end

  defp get_buffer_width(emulator) do
    active_buffer = Emulator.get_active_buffer(emulator)
    ScreenBuffer.get_width(active_buffer)
  end

  defp get_buffer_height(emulator) do
    active_buffer = Emulator.get_active_buffer(emulator)
    ScreenBuffer.get_height(active_buffer)
  end

  defp update_charset_state(emulator, char_codepoint) do
    {_, new_charset_state} =
      CharacterSets.translate_char(char_codepoint, emulator.charset_state)

    new_charset_state
  end

  defp calculate_positions(emulator, buffer_width, char_codepoint) do
    char_width = CharacterHandling.get_char_width(char_codepoint)
    auto_wrap_mode = ModeManager.mode_enabled?(emulator.mode_manager, :decawm)
    buffer_height = get_buffer_height(emulator)

    {current_cursor_x, current_cursor_y} =
      get_cursor_position_safe(emulator.cursor)

    {write_x, write_y, next_cursor_x, next_cursor_y, next_last_col_exceeded} =
      calculate_write_and_cursor_position(
        current_cursor_x,
        current_cursor_y,
        buffer_width,
        char_width,
        emulator.last_col_exceeded,
        auto_wrap_mode
      )

    # Check if autowrap would cause an out-of-bounds write
    # If so, adjust the positions to stay within bounds
    {adjusted_write_x, adjusted_write_y, adjusted_next_cursor_x, adjusted_next_cursor_y, adjusted_next_last_col_exceeded} =
      if write_y >= buffer_height and auto_wrap_mode and emulator.last_col_exceeded do
        # Autowrap would go out of bounds, so we need to handle this specially
        # Write at the current position but move cursor to next line
        # The emulator will handle scrolling when the cursor moves out of bounds
        {write_x, current_cursor_y, next_cursor_x, next_cursor_y, next_last_col_exceeded}
      else
        {write_x, write_y, next_cursor_x, next_cursor_y, next_last_col_exceeded}
      end

    log_cursor_positions(
      current_cursor_x,
      current_cursor_y,
      adjusted_write_x,
      adjusted_write_y,
      adjusted_next_cursor_x,
      adjusted_next_cursor_y
    )

    {adjusted_write_x, adjusted_write_y, adjusted_next_cursor_x, adjusted_next_cursor_y, adjusted_next_last_col_exceeded}
  end

  defp get_cursor_position_safe(cursor) do
    try do
      case cursor do
        cursor when is_pid(cursor) ->
          position = Raxol.Terminal.Cursor.Manager.get_position(cursor)
          position

        cursor when is_map(cursor) ->
          Raxol.Terminal.Cursor.Manager.get_position(cursor)

        _ ->
          log_cursor_debug("unknown cursor type", cursor)
          {0, 0}
      end
    rescue
      e ->
        IO.puts("ERROR: Failed to get cursor position: #{inspect(e)}")
        {0, 0}
    end
  end

  defp log_cursor_debug(cursor_type, cursor) do
    Raxol.Core.Runtime.Log.debug(
      "[calculate_positions] Getting position from #{cursor_type}: #{inspect(cursor)}"
    )
  end

  defp log_position_debug(cursor_type, position) do
    Raxol.Core.Runtime.Log.debug(
      "[calculate_positions] #{cursor_type}: #{inspect(position)}"
    )
  end

  defp log_cursor_positions(
         current_x,
         current_y,
         write_x,
         write_y,
         next_x,
         next_y
       ) do
    Raxol.Core.Runtime.Log.debug(
      "Cursor positions - Current: {#{current_x}, #{current_y}}, Write: {#{write_x}, #{write_y}}, Next: {#{next_x}, #{next_y}}"
    )
  end

  defp write_character(emulator, char_codepoint, opts \\ []) do
    try do
      {translated_char, new_charset_state} =
        CharacterSets.translate_char(char_codepoint, emulator.charset_state)

      active_charset_module =
        CharacterSets.get_active_charset(emulator.charset_state)

      translated_char_str = <<translated_char::utf8>>

      if not is_binary(translated_char_str) do
        Raxol.Core.Runtime.Log.error(
          "Expected translated_char to be a string, got: #{inspect(translated_char_str)}"
        )
      end

      buffer_height = get_buffer_height(emulator)

      {write_x, write_y, next_cursor_x, next_cursor_y, next_last_col_exceeded} =
        calculate_positions(
          emulator,
          get_buffer_width(emulator),
          char_codepoint
        )

      # Check if autowrap would cause an out-of-bounds write
      auto_wrap_mode = ModeManager.mode_enabled?(emulator.mode_manager, :decawm)

      if write_y < buffer_height do
        buffer_for_write = Emulator.get_active_buffer(emulator)
        # When writing the cell, use opts directly as the style argument
        # For example, if the function is write_char(buffer, x, y, char, style), pass opts as style
        buffer_after_write =
          Operations.write_char(
            buffer_for_write,
            write_x,
            write_y,
            translated_char_str,
            opts
          )

        emulator = Emulator.update_active_buffer(emulator, buffer_after_write)

        emulator
      else
        Raxol.Core.Runtime.Log.warning_with_context(
          "Attempted write out of bounds (y=#{write_y}, height=#{buffer_height}), handling autowrap after scroll.",
          %{}
        )

        # For autowrap that would go out of bounds, we need to write the character after scrolling
        # First, let the emulator scroll, then write the character to the new line
        emulator
      end
    rescue
      exception ->
        IO.puts(
          "ERROR in write_character/3: #{inspect(exception)}\n#{Exception.format(:error, exception, __STACKTRACE__)}"
        )

        reraise(exception, __STACKTRACE__)
    end
  end

  defp update_emulator_state(
         emulator,
         next_cursor_x,
         next_cursor_y,
         next_last_col_exceeded,
         new_charset_state
       ) do
    # Update cursor position by calling the cursor manager
    updated_emulator =
      case emulator.cursor do
        cursor when is_pid(cursor) ->
          # For PID cursors, just call set_position - the PID manages its own state
          Raxol.Terminal.Cursor.Manager.set_position(
            cursor,
            {next_cursor_x, next_cursor_y}
          )

          # Don't update the emulator's cursor field - the PID is the cursor
          emulator

        cursor when is_map(cursor) ->
          updated_cursor =
            Raxol.Terminal.Cursor.Manager.set_position(
              cursor,
              {next_cursor_x, next_cursor_y}
            )

          %{emulator | cursor: updated_cursor}

        _ ->
          emulator
      end

    %{
      updated_emulator
      | last_col_exceeded: next_last_col_exceeded,
        charset_state: new_charset_state
    }
  end

  @doc false
  def calculate_write_and_cursor_position(
        current_x,
        current_y,
        buffer_width,
        char_width,
        last_col_exceeded,
        auto_wrap_mode
      ) do
    cond do
      last_col_exceeded and auto_wrap_mode ->
        # For autowrap, we need to check if the next line is within bounds
        # If not, we should stay on the current line and let scrolling handle it
        write_y = current_y + 1

        {0, write_y, char_width, write_y,
         auto_wrap_mode and char_width >= buffer_width}

      last_col_exceeded and not auto_wrap_mode ->
        write_x = buffer_width - 1
        write_y = current_y
        next_cursor_x = buffer_width - 1
        next_cursor_y = current_y
        next_flag = true
        {write_x, write_y, next_cursor_x, next_cursor_y, next_flag}

      current_x + char_width < buffer_width ->
        {current_x, current_y, current_x + char_width, current_y, false}

      true ->
        if auto_wrap_mode do
          {current_x, current_y, buffer_width - 1, current_y, true}
        else
          {current_x, current_y, buffer_width - 1, current_y, true}
        end
    end
  end
end
