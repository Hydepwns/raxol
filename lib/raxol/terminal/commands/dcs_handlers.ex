defmodule Raxol.Terminal.Commands.DCSHandlers do
  @moduledoc false

  require Raxol.Core.Runtime.Log
  require Logger

  def handle_dcs(emulator, params, data_string) do
    case params do
      # DECRQSS - Request Status String
      [0] ->
        handle_decrqss(emulator, data_string)

      # DECDLD - Download Character Set
      [1] ->
        handle_decdld(emulator, data_string)

      _ ->
        {:error, :unknown_dcs, emulator}
    end
  end

  def handle_dcs(emulator, params, intermediates, final_byte, data_string) do
    case {intermediates, final_byte} do
      # Sixel Graphics - DCS q ... ST
      {"\"", ?q} ->
        handle_sixel(emulator, data_string)

      # DECRQSS - DCS ! | ... ST
      {"!", ?|} ->
        handle_decrqss(emulator, data_string)

      # DECDLD - DCS | p ... ST
      {"|", ?p} ->
        handle_decdld(emulator, data_string)

      _ ->
        {:error, :unknown_dcs, emulator}
    end
  end

  defp handle_decrqss(emulator, data_string) do
    case data_string do
      # SGR (Select Graphic Rendition)
      "m" ->
        response = "\eP1!|0m\e\\"
        {:ok, %{emulator | output_buffer: response}}

      # Cursor style queries
      " q" ->
        cursor_style = get_cursor_style(emulator)
        response = "\eP1!|#{cursor_style} q\e\\"
        {:ok, %{emulator | output_buffer: response}}

      # Scroll region query
      "r" ->
        scroll_region = get_scroll_region(emulator)
        response = "\eP1!|#{scroll_region}r\e\\"
        {:ok, %{emulator | output_buffer: response}}

      # Unknown request type
      unknown ->
        Logger.warning("Unhandled DECRQSS request type: #{inspect(unknown)}")
        {:ok, emulator}
    end
  end

  defp handle_decdld(emulator, _data_string) do
    Logger.warning("DECDLD (Downloadable Character Set) not yet implemented")
    {:error, :decdld_not_implemented, emulator}
  end

  defp get_cursor_style(emulator) do
    case emulator.cursor do
      %{style: :blinking_block} -> 1
      %{style: :steady_block} -> 2
      %{style: :blinking_underline} -> 3
      %{style: :steady_underline} -> 4
      %{style: :blinking_bar} -> 5
      %{style: :steady_bar} -> 6
      _ -> 1  # Default to blinking block
    end
  end

  defp get_scroll_region(emulator) do
    case emulator.scroll_region do
      {top, bottom} -> "#{top + 1};#{bottom + 1}"  # Convert to 1-indexed
      nil -> "1;#{emulator.height}"
      _ -> "1;#{emulator.height}"
    end
  end

  # Sixel Graphics support
  defp handle_sixel(emulator, data) do
    # Initialize sixel state if not present
    sixel_state = emulator.sixel_state || Raxol.Terminal.ANSI.SixelGraphics.new()

    # Process sixel data using the proper SixelGraphics module
    case Raxol.Terminal.ANSI.SixelGraphics.process_sequence(sixel_state, data) do
      {updated_sixel_state, :ok} ->
        # Successfully processed, update emulator with new sixel state
        # and blit the graphics to the screen buffer
        emulator_with_sixel = %{emulator | sixel_state: updated_sixel_state}
        emulator_with_blit = blit_sixel_to_buffer(emulator_with_sixel, updated_sixel_state)
        {:ok, emulator_with_blit}

      {_sixel_state, {:error, reason}} ->
        # Processing failed, log the error but still update the sixel_state
        Logger.warning("Sixel processing failed: #{inspect(reason)}")
        # Return the original sixel_state (or new one if it was nil)
        {:ok, %{emulator | sixel_state: sixel_state}}

      {updated_sixel_state, _} ->
        # Any other response, use the updated state
        emulator_with_sixel = %{emulator | sixel_state: updated_sixel_state}
        emulator_with_blit = blit_sixel_to_buffer(emulator_with_sixel, updated_sixel_state)
        {:ok, emulator_with_blit}
    end
  end

  # Blit Sixel graphics to the screen buffer
  defp blit_sixel_to_buffer(emulator, sixel_state) do
    %{pixel_buffer: pixel_buffer, palette: palette} = sixel_state

    # Get cursor position from the emulator's cursor field
    cursor_position = case emulator.cursor do
      cursor when is_pid(cursor) ->
        # If cursor is a PID, get position via GenServer call
        GenServer.call(cursor, :get_position)
      cursor when is_map(cursor) ->
        # If cursor is a struct, get position directly
        cursor.position
      _ ->
        {0, 0}  # Fallback
    end

    {cursor_x, cursor_y} = cursor_position

    log_sixel_debug_info(pixel_buffer, palette, cursor_x, cursor_y)

    buffer = Raxol.Terminal.Emulator.get_active_buffer(emulator)
    updated_buffer = blit_pixels_to_buffer(buffer, pixel_buffer, palette, cursor_x, cursor_y)
    update_emulator_buffer(emulator, updated_buffer)
  end

  defp log_sixel_debug_info(pixel_buffer, palette, cursor_x, cursor_y) do
    Logger.debug("Blitting Sixel graphics: pixel_buffer=#{inspect(pixel_buffer)}, palette=#{inspect(palette)}")
    Logger.debug("Cursor position: {#{cursor_x}, #{cursor_y}}")
  end

  defp blit_pixels_to_buffer(buffer, pixel_buffer, palette, cursor_x, cursor_y) do
    Enum.reduce(pixel_buffer, buffer, fn {{sixel_x, sixel_y}, color_index}, buffer ->
      blit_single_pixel(buffer, sixel_x, sixel_y, color_index, palette, cursor_x, cursor_y)
    end)
  end

  defp blit_single_pixel(buffer, sixel_x, sixel_y, color_index, palette, cursor_x, cursor_y) do
    screen_x = cursor_x + sixel_x
    screen_y = cursor_y + sixel_y

    Logger.debug("Blitting pixel at sixel {#{sixel_x}, #{sixel_y}} -> screen {#{screen_x}, #{screen_y}} with color_index #{color_index}")

    case Map.get(palette, color_index) do
      {r, g, b} ->
        Logger.debug("Found color {#{r}, #{g}, #{b}} for index #{color_index}")
        style = %{background: {:rgb, r, g, b}}
        Raxol.Terminal.ScreenBuffer.write_char(buffer, screen_x, screen_y, " ", style)

      nil ->
        Logger.debug("No color found for index #{color_index}")
        buffer
    end
  end

  defp update_emulator_buffer(emulator, updated_buffer) do
    case emulator.active_buffer_type do
      :main -> %{emulator | main_screen_buffer: updated_buffer}
      :alternate -> %{emulator | alternate_screen_buffer: updated_buffer}
    end
  end

  defp process_sixel_data(sixel_state, data) do
    # Basic sixel processing - this is a simplified implementation
    # In a full implementation, this would parse the sixel data and update the screen buffer
    %{sixel_state |
      data: sixel_state.data ++ [data],
      width: max(sixel_state.width, String.length(data)),
      height: sixel_state.height + 1
    }
  end
end
