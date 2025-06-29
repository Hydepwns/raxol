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
        {:ok, %{emulator | sixel_state: updated_sixel_state}}

      {_sixel_state, {:error, reason}} ->
        # Processing failed, log the error but still update the sixel_state
        Logger.warning("Sixel processing failed: #{inspect(reason)}")
        # Return the original sixel_state (or new one if it was nil)
        {:ok, %{emulator | sixel_state: sixel_state}}

      {updated_sixel_state, _} ->
        # Any other response, use the updated state
        {:ok, %{emulator | sixel_state: updated_sixel_state}}
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
