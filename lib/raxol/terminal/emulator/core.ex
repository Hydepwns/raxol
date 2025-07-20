defmodule Raxol.Terminal.Emulator.Core do
  @moduledoc """
  Handles core emulator functionality including input processing and scrolling.

  This module provides core emulator operations including:
  - Input processing
  - Scrolling logic
  - Cursor position management
  - Buffer management
  """

  import Raxol.Guards

  alias Raxol.Terminal.{
    ScreenBuffer,
    Buffer.Scrollback,
    Cursor.Manager,
    Input.CoreHandler
  }

  @doc """
  Processes input for the emulator.

  ## Parameters

  * `emulator` - The emulator state
  * `input` - Input to process

  ## Returns

  A tuple {updated_emulator, output}.
  """
  @spec process_input(Raxol.Terminal.Emulator.t(), binary()) :: {Raxol.Terminal.Emulator.t(), binary()}
  def process_input(emulator, input) do
    IO.puts("DEBUG: process_input called with input: #{inspect(input)}")

    # Handle character set commands first
    case get_charset_command(input) do
      {field, value} ->
        IO.puts(
          "DEBUG: process_input matched charset command: #{field} = #{value}"
        )

        # If it's a charset command, handle it completely and return
        updated_emulator = %{
          emulator
          | charset_state: %{emulator.charset_state | field => value}
        }

        {updated_emulator, ""}

      :no_match ->
        IO.puts(
          "DEBUG: process_input no charset match, using parser-based processing"
        )

        # Use parser-based input processing for all other input
        {updated_emulator, output} =
          CoreHandler.process_terminal_input(
            emulator,
            input
          )

        # After all input, if the cursor is past the last row, scroll until it's visible
        final_emulator =
          ensure_cursor_in_visible_region(updated_emulator)

        {final_emulator, output}
    end
  end

  @doc """
  Ensures the cursor is in the visible region by scrolling if necessary.

  ## Parameters

  * `emulator` - The emulator state

  ## Returns

  Updated emulator with cursor in visible region.
  """
  def ensure_cursor_in_visible_region(emulator) do
    # If cursor position was handled by autowrap, don't override it
    if Map.get(emulator, :cursor_handled_by_autowrap, false) do
      IO.puts(
        "DEBUG: ensure_cursor_in_visible_region - cursor_handled_by_autowrap is true, skipping cursor adjustment"
      )

      # Remove the flag and return the emulator without further cursor adjustment
      %{emulator | cursor_handled_by_autowrap: false}
    else
      IO.puts(
        "DEBUG: ensure_cursor_in_visible_region - cursor_handled_by_autowrap is false, checking cursor position"
      )

      active_buffer = get_active_buffer(emulator)
      buffer_height = ScreenBuffer.get_height(active_buffer)

      {_, cursor_y} =
        case emulator.cursor do
          cursor when is_pid(cursor) ->
            Manager.get_position(cursor)

          cursor when is_map(cursor) ->
            Manager.get_position(cursor)

          _ ->
            {0, 0}
        end

      IO.puts(
        "DEBUG: ensure_cursor_in_visible_region - cursor_y: #{cursor_y}, buffer_height: #{buffer_height}"
      )

      if cursor_y >= buffer_height do
        # Scroll until the cursor is in the visible region
        ensure_cursor_in_visible_region(
          Raxol.Terminal.Emulator.maybe_scroll(emulator)
        )
      else
        emulator
      end
    end
  end

  @doc """
  Checks if scrolling is needed and performs it if necessary.

  ## Parameters

  * `emulator` - The emulator state

  ## Returns

  Updated emulator after scrolling.
  """
  @spec maybe_scroll(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def maybe_scroll(%Raxol.Terminal.Emulator{} = emulator) do
    {_x, y} = Manager.get_position(emulator.cursor)

    log_scroll_debug(_x, y, emulator.height)

    if y >= emulator.height do
      perform_scroll(emulator)
    else
      log_no_scroll_needed()
      emulator
    end
  end

  @doc """
  Gets the active buffer from the emulator.

  ## Parameters

  * `emulator` - The emulator state

  ## Returns

  The active screen buffer.
  """
  @spec get_active_buffer(Raxol.Terminal.Emulator.t()) :: ScreenBuffer.t()
  def get_active_buffer(%Raxol.Terminal.Emulator{} = emulator) do
    case emulator.active_buffer_type do
      :main -> emulator.main_screen_buffer
      :alternate -> emulator.alternate_screen_buffer
    end
  end

  @doc """
  Updates the active buffer in the emulator.

  ## Parameters

  * `emulator` - The emulator state
  * `new_buffer` - The new buffer to set

  ## Returns

  Updated emulator with new buffer.
  """
  def update_active_buffer(emulator, new_buffer) do
    case emulator.active_buffer_type do
      :main ->
        %{emulator | main_screen_buffer: new_buffer}

      :alternate ->
        %{emulator | alternate_screen_buffer: new_buffer}

      _ ->
        %{emulator | main_screen_buffer: new_buffer}
    end
  end

  @doc """
  Resizes the terminal emulator to new dimensions.

  ## Parameters

  * `emulator` - The emulator state
  * `width` - New width
  * `height` - New height

  ## Returns

  Updated emulator with new dimensions.
  """
  @spec resize(Raxol.Terminal.Emulator.t(), non_neg_integer(), non_neg_integer()) :: Raxol.Terminal.Emulator.t()
  def resize(%Raxol.Terminal.Emulator{} = emulator, width, height)
      when width > 0 and height > 0 do
    # Resize main screen buffer
    main_buffer =
      if emulator.main_screen_buffer do
        ScreenBuffer.resize(emulator.main_screen_buffer, width, height)
      else
        ScreenBuffer.new(width, height)
      end

    # Resize alternate screen buffer
    alternate_buffer =
      if emulator.alternate_screen_buffer do
        ScreenBuffer.resize(emulator.alternate_screen_buffer, width, height)
      else
        ScreenBuffer.new(width, height)
      end

    # Update emulator with new dimensions and buffers
    %{
      emulator
      | width: width,
        height: height,
        main_screen_buffer: main_buffer,
        alternate_screen_buffer: alternate_buffer
    }
  end

  @doc """
  Writes a string to the emulator with charset translation.

  ## Parameters

  * `emulator` - The emulator state
  * `x` - X coordinate
  * `y` - Y coordinate
  * `string` - String to write
  * `style` - Style to apply

  ## Returns

  Updated emulator.
  """
  def write_string(%Raxol.Terminal.Emulator{} = emulator, x, y, string, style \\ %{}) do
    translated =
      Raxol.Terminal.ANSI.CharacterSets.translate_string(
        string,
        emulator.charset_state
      )

    # Get the active buffer
    buffer = get_active_buffer(emulator)

    # Write the string to the buffer
    updated_buffer =
      ScreenBuffer.write_string(buffer, x, y, translated, style)

    # Update cursor position after writing
    cursor = get_cursor_struct(emulator)
    new_x = x + String.length(translated)
    new_cursor = %{cursor | x: new_x, position: {new_x, y}}

    # Update the appropriate buffer
    emulator =
      case emulator.active_buffer_type do
        :main ->
          %{emulator | main_screen_buffer: updated_buffer, cursor: new_cursor}

        :alternate ->
          %{
            emulator
            | alternate_screen_buffer: updated_buffer,
              cursor: new_cursor
          }
      end

    emulator
  end

  # Private helper functions

  defp get_charset_command(input) do
    charset_commands = %{
      "\e)0" => {:g1, :dec_special_graphics},
      "\e(B" => {:g0, :us_ascii},
      "\e*0" => {:g2, :dec_special_graphics},
      "\x0E" => {:gl, :g1},
      "\x0F" => {:gl, :g0},
      "\en" => {:gl, :g2},
      "\eo" => {:gl, :g3},
      "\e~" => {:gr, :g2},
      "\e}" => {:gr, :g1},
      "\e|" => {:gr, :g3}
    }

    Map.get(charset_commands, input, :no_match)
  end

  defp perform_scroll(emulator) do
    Raxol.Core.Runtime.Log.debug("[maybe_scroll] Scrolling needed!")

    active_buffer = get_active_buffer(emulator)

    {scrolled_buffer, scrolled_lines} =
      ScreenBuffer.scroll_up(active_buffer, 1)

    log_scroll_result(scrolled_lines)
    updated_buffer = update_scrollback_buffer(scrolled_buffer, scrolled_lines)
    log_buffer_update(updated_buffer)

    # Update the buffer
    emulator_with_updated_buffer =
      update_active_buffer(emulator, updated_buffer)

    # If cursor position was handled by autowrap, don't override it
    if Map.get(emulator, :cursor_handled_by_autowrap, false) do
      IO.puts(
        "DEBUG: perform_scroll - cursor_handled_by_autowrap is true, skipping cursor adjustment"
      )

      emulator_with_updated_buffer
    else
      # Update the cursor position to stay within the visible region
      {cursor_x, cursor_y} =
        Manager.get_position(emulator.cursor)

      # Move cursor up by 1 line, but not below 0
      new_cursor_y = max(0, cursor_y - 1)

      # Update the cursor position
      updated_cursor =
        Manager.set_position(
          emulator.cursor,
          {cursor_x, new_cursor_y}
        )

      %{emulator_with_updated_buffer | cursor: updated_cursor}
    end
  end

  defp update_scrollback_buffer(scrolled_buffer, scrolled_lines) do
    if scrolled_lines && length(scrolled_lines) > 0 do
      # Filter out lines that don't contain meaningful content
      meaningful_lines = Enum.filter(scrolled_lines, &has_meaningful_content?/1)

      if length(meaningful_lines) > 0 do
        Raxol.Core.Runtime.Log.debug(
          "[maybe_scroll] Adding #{length(meaningful_lines)} meaningful lines to scrollback"
        )

        Scrollback.add_lines(
          scrolled_buffer,
          meaningful_lines
        )
      else
        Raxol.Core.Runtime.Log.debug(
          "[maybe_scroll] No meaningful lines to add to scrollback"
        )

        scrolled_buffer
      end
    else
      Raxol.Core.Runtime.Log.debug("[maybe_scroll] No scrolled_lines to add")
      scrolled_buffer
    end
  end

  defp has_meaningful_content?(line) do
    # Check if the line contains at least 3 non-whitespace characters
    case line do
      [] -> false
      cells when is_list(cells) ->
        non_ws_count = Enum.count(cells, fn cell ->
          case cell do
            %{char: char} when is_binary(char) ->
              char != " " and char != "\t" and char != "\n" and char != "\r"
            %{char: char} when is_integer(char) ->
              char > 32  # ASCII space is 32, so anything above that is meaningful
            _ -> false
          end
        end)
        non_ws_count >= 3
      _ -> false
    end
  end

  defp get_cursor_struct(%Raxol.Terminal.Emulator{cursor: cursor}) do
    if is_pid(cursor) do
      GenServer.call(cursor, :get_state)
    else
      cursor
    end
  end

  defp log_scroll_debug(x, y, height) do
    Raxol.Core.Runtime.Log.debug(
      "[maybe_scroll] Cursor position: {#{x}, #{y}}, emulator height: #{height}"
    )
  end

  defp log_no_scroll_needed do
    Raxol.Core.Runtime.Log.debug("[maybe_scroll] No scrolling needed")
  end

  defp log_scroll_result(scrolled_lines) do
    Raxol.Core.Runtime.Log.debug(
      "[maybe_scroll] scroll_up returned scrolled_lines: #{inspect(scrolled_lines)}"
    )
  end

  defp log_buffer_update(updated_buffer) do
    Raxol.Core.Runtime.Log.debug(
      "[maybe_scroll] Updated buffer scrollback length: #{length(updated_buffer.scrollback)}"
    )
  end
end
