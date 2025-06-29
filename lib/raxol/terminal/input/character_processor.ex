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

  @doc """
  Processes a single printable character codepoint.
  Handles writing the character to the buffer, cursor advancement, and line wrapping.
  """
  @spec process_printable_character(Emulator.t(), integer()) :: Emulator.t()
  def process_printable_character(emulator, char_codepoint) do
    {_active_buffer, buffer_width, buffer_height} = get_buffer_info(emulator)

    {translated_char, new_charset_state} =
      translate_character(emulator, char_codepoint)

    {write_x, write_y, next_cursor_x, next_cursor_y, next_last_col_exceeded} =
      calculate_positions(emulator, buffer_width, char_codepoint)

    emulator_after_write =
      write_character(
        emulator,
        translated_char,
        write_x,
        write_y,
        buffer_height
      )

    update_emulator_state(
      emulator_after_write,
      next_cursor_x,
      next_cursor_y,
      next_last_col_exceeded,
      new_charset_state
    )
  end

  defp get_buffer_info(emulator) do
    active_buffer = Emulator.get_active_buffer(emulator)
    {active_buffer, ScreenBuffer.get_width(active_buffer),
     ScreenBuffer.get_height(active_buffer)}
  end

  defp translate_character(emulator, char_codepoint) do
    {translated_codepoint, new_charset_state} =
      CharacterSets.translate_char(char_codepoint, emulator.charset_state)

    # Convert codepoint to string
    translated_char = <<translated_codepoint::utf8>>

    if not is_binary(translated_char) do
      Raxol.Core.Runtime.Log.error(
        "Expected translated_char to be a string, got: #{inspect(translated_char)}"
      )
    end

    {translated_char, new_charset_state}
  end

  defp calculate_positions(emulator, buffer_width, char_codepoint) do
    char_width = CharacterHandling.get_char_width(char_codepoint)
    auto_wrap_mode = ModeManager.mode_enabled?(emulator.mode_manager, :decawm)

    {current_cursor_x, current_cursor_y} =
      Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    calculate_write_and_cursor_position(
      current_cursor_x,
      current_cursor_y,
      buffer_width,
      char_width,
      emulator.last_col_exceeded,
      auto_wrap_mode
    )
  end

  defp write_character(
         emulator,
         translated_char,
         write_x,
         write_y,
         buffer_height
       ) do
    if write_y < buffer_height do
      Raxol.Core.Runtime.Log.debug(
        # {translated_char}" with style: #{inspect(emulator.style)}"
        "[InputHandler] Writing char codepoint "
      )

      buffer_for_write = Emulator.get_active_buffer(emulator)

      buffer_after_write =
        Operations.write_char(
          buffer_for_write,
          write_x,
          write_y,
          translated_char,
          emulator.style
        )

      Emulator.update_active_buffer(emulator, buffer_after_write)
    else
      Raxol.Core.Runtime.Log.warning_with_context(
        "Attempted write out of bounds (y=#{write_y}, height=#{buffer_height}), skipping write.",
        %{}
      )

      emulator
    end
  end

  defp update_emulator_state(
         emulator,
         next_cursor_x,
         next_cursor_y,
         next_last_col_exceeded,
         new_charset_state
       ) do
    cursor_before_move = emulator.cursor
    new_position_tuple = {next_cursor_x, next_cursor_y}
    new_cursor = %{cursor_before_move | position: new_position_tuple}

    %{
      emulator
      | cursor: new_cursor,
        last_col_exceeded: next_last_col_exceeded,
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
