defmodule Raxol.Terminal.Emulator.ANSIHandler do
  @moduledoc """
  Handles ANSI sequence processing for the terminal emulator.

  This module provides ANSI sequence handling including:
  - Sequence parsing
  - Command handling
  - SGR processing
  - Mode management
  """

  import Raxol.Guards

  alias Raxol.Terminal.{
    ANSI.SequenceHandlers,
    ANSI.SGRProcessor,
    Commands.CursorHandlers,
    Operations.ScreenOperations,
    ModeManager
  }

  @doc """
  Handles ANSI sequences for the emulator.

  ## Parameters

  * `rest` - Remaining input to process
  * `emulator` - The emulator state

  ## Returns

  A tuple {updated_emulator, remaining_input}.
  """
  def handle_ansi_sequences(<<>>, emulator), do: {emulator, <<>>}

  def handle_ansi_sequences(rest, emulator) do
    case SequenceHandlers.parse_ansi_sequence(rest) do
      {:osc, remaining, _} ->
        handle_ansi_sequences(remaining, emulator)

      {:dcs, remaining, _} ->
        handle_ansi_sequences(remaining, emulator)

      {:incomplete, _} ->
        {emulator, rest}

      parsed_sequence ->
        {new_emulator, remaining} =
          handle_parsed_sequence(parsed_sequence, rest, emulator)

        handle_ansi_sequences(remaining, new_emulator)
    end
  end

  @doc """
  Handles a parsed ANSI sequence.

  ## Parameters

  * `parsed_sequence` - The parsed sequence
  * `rest` - Remaining input
  * `emulator` - The emulator state

  ## Returns

  A tuple {updated_emulator, remaining_input}.
  """
  def handle_parsed_sequence(parsed_sequence, rest, emulator) do
    IO.puts("DEBUG: handle_parsed_sequence called with: #{inspect(parsed_sequence)}")
    case parsed_sequence do
      {:osc, remaining, _} ->
        handle_ansi_sequences(remaining, emulator)

      {:dcs, remaining, _} ->
        handle_ansi_sequences(remaining, emulator)

      {:incomplete, _} ->
        {emulator, <<>>}

      {:csi_cursor_pos, params, remaining, _} ->
        {CursorHandlers.handle_cup(params, emulator), remaining}

      {:csi_cursor_up, params, remaining, _} ->
        {CursorHandlers.handle_cursor_up(params, emulator), remaining}

      {:csi_cursor_down, params, remaining, _} ->
        {CursorHandlers.handle_cursor_down(params, emulator), remaining}

      {:csi_cursor_forward, params, remaining, _} ->
        {CursorHandlers.handle_cursor_forward(params, emulator), remaining}

      {:csi_cursor_back, params, remaining, _} ->
        {CursorHandlers.handle_cursor_back(params, emulator), remaining}

      {:csi_cursor_show, remaining, _} ->
        {set_cursor_visible(true, emulator), remaining}

      {:csi_cursor_hide, remaining, _} ->
        {set_cursor_visible(false, emulator), remaining}

      {:csi_clear_screen, remaining, _} ->
        {ScreenOperations.clear_screen(emulator), remaining}

      {:csi_clear_line, remaining, _} ->
        {ScreenOperations.clear_line(emulator), remaining}

      {:csi_set_mode, params, remaining, _} ->
        {handle_set_mode(params, emulator), remaining}

      {:csi_reset_mode, params, remaining, _} ->
        {handle_reset_mode(params, emulator), remaining}

      {:csi_set_standard_mode, params, remaining, _} ->
        {handle_set_standard_mode(params, emulator), remaining}

      {:csi_reset_standard_mode, params, remaining, _} ->
        {handle_reset_standard_mode(params, emulator), remaining}

      {:esc_equals, remaining, _} ->
        {handle_esc_equals(emulator), remaining}

      {:esc_greater, remaining, _} ->
        {handle_esc_greater(emulator), remaining}

      {:sgr, params, remaining, _} ->
        IO.puts(
          "DEBUG: SGR handler called with params=#{inspect(params)}, remaining=#{inspect(remaining)}"
        )

        IO.puts(
          "DEBUG: SGR handler emulator.style before=#{inspect(emulator.style)}"
        )

        result = {handle_sgr(params, emulator), remaining}

        IO.puts(
          "DEBUG: SGR handler result emulator.style after=#{inspect(elem(result, 0).style)}"
        )

        result

      {:unknown, remaining, _} ->
        handle_ansi_sequences(remaining, emulator)

      {:csi_set_scroll_region, params, remaining, _} ->
        {handle_set_scroll_region(params, emulator), remaining}

      {:csi_general, params, intermediates, final_byte, remaining} ->
        {handle_csi_general(params, final_byte, emulator, intermediates), remaining}

      {:cursor_horizontal_absolute, col, remaining} ->
        IO.puts("DEBUG: handle_parsed_sequence cursor_horizontal_absolute col=#{inspect(col)}")
        result = CursorHandlers.handle_G(emulator, [col + 1])
        IO.puts("DEBUG: handle_G result cursor=#{inspect(result)}")
        {result, remaining}
    end
  end

  # Mode handling functions
  def handle_set_mode(params, emulator) do
    parsed_params = parse_mode_params(params)

    Enum.reduce(parsed_params, emulator, fn param, acc ->
      case lookup_mode(param) do
        {:ok, mode_name} ->
          ModeManager.set_mode(acc, [mode_name])
          acc
        :error ->
          acc
      end
    end)
  end

  def handle_reset_mode(params, emulator) do
    parsed_params = parse_mode_params(params)

    Enum.reduce(parsed_params, emulator, fn param, acc ->
      case lookup_mode(param) do
        {:ok, mode_name} ->
          ModeManager.reset_mode(acc, [mode_name])
          acc
        :error ->
          acc
      end
    end)
  end

  def handle_set_standard_mode(params, emulator) do
    parsed_params = parse_mode_params(params)

    Enum.reduce(parsed_params, emulator, fn param, acc ->
      case lookup_standard_mode(param) do
        {:ok, mode_name} ->
          ModeManager.set_standard_mode(acc, [mode_name])
          acc
        :error ->
          acc
      end
    end)
  end

  def handle_reset_standard_mode(params, emulator) do
    parsed_params = parse_mode_params(params)

    Enum.reduce(parsed_params, emulator, fn param, acc ->
      case lookup_standard_mode(param) do
        {:ok, mode_name} ->
          ModeManager.reset_standard_mode(acc, [mode_name])
          acc
        :error ->
          acc
      end
    end)
  end

  def handle_esc_equals(emulator) do
    # Application Keypad mode
    ModeManager.set_mode(emulator, [:application_keypad])
  end

  def handle_esc_greater(emulator) do
    # Normal Keypad mode
    ModeManager.reset_mode(emulator, [:application_keypad])
  end

  def handle_sgr(params, emulator) do
    parsed_params = parse_sgr_params(params)
    updated_style = SGRProcessor.process_sgr_codes(parsed_params, emulator.style)
    %{emulator | style: updated_style}
  end

  def handle_set_scroll_region(params, emulator) do
    # Implementation for setting scroll region
    emulator
  end

  def handle_csi_general(params, final_byte, emulator, intermediates) do
    # Implementation for general CSI commands
    emulator
  end

  # Private helper functions

  defp set_cursor_visible(visible, emulator) do
    mode_manager = emulator.mode_manager

    # Update the mode manager struct directly
    new_mode_manager = %{mode_manager | cursor_visible: visible}
    emulator = %{emulator | mode_manager: new_mode_manager}

    # Also update the cursor manager - use non-blocking cast for better performance
    cursor = emulator.cursor

    if pid?(cursor) do
      GenServer.cast(cursor, {:set_visibility, visible})
    end

    emulator
  end

  defp parse_mode_params(params) do
    params
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&String.to_integer/1)
  end

  defp parse_sgr_params(params) do
    params
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&String.to_integer/1)
  end

  defp lookup_mode(mode_code) do
    case ModeManager.lookup_private(mode_code) do
      nil -> :error
      mode_name -> {:ok, mode_name}
    end
  end

  defp lookup_standard_mode(mode_code) do
    case ModeManager.lookup_standard(mode_code) do
      nil -> :error
      mode_name -> {:ok, mode_name}
    end
  end
end
