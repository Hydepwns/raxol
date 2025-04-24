defmodule Raxol.Terminal.Commands.Modes do
  @moduledoc """
  Handles terminal mode setting and resetting operations.

  This module manages DEC private mode and ANSI mode setting/resetting in the terminal,
  which control various aspects of terminal behavior like cursor visibility, line wrapping,
  alternate screen buffer, and more.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenModes
  alias Raxol.Terminal.Commands.Parser

  require Logger
  require Raxol.Terminal.ScreenModes

  @doc """
  Handles DEC private mode setting or resetting.

  These are the modes that are prefixed with '?' in the terminal sequences.

  ## Parameters

  * `emulator` - The current emulator state
  * `params` - List of mode numbers to set or reset
  * `action` - Either `:set` to enable or `:reset` to disable

  ## Returns

  * Updated emulator state
  """
  @spec handle_dec_private_mode(Emulator.t(), list(integer()), :set | :reset) :: Emulator.t()
  def handle_dec_private_mode(emulator, params, action) do
    params
    |> Enum.reduce(emulator, fn param, acc ->
      # Safely handle nil params
      if is_nil(param) do
        Logger.warn("Ignoring nil mode parameter in DEC private mode set/reset")
        acc
      else
        handle_single_dec_mode(acc, param, action)
      end
    end)
  end

  @doc """
  Handles ANSI mode setting or resetting.

  These are the standard mode control sequences without the '?' prefix.

  ## Parameters

  * `emulator` - The current emulator state
  * `params` - List of mode numbers to set or reset
  * `action` - Either `:set` to enable or `:reset` to disable

  ## Returns

  * Updated emulator state
  """
  @spec handle_ansi_mode(Emulator.t(), list(integer()), :set | :reset) :: Emulator.t()
  def handle_ansi_mode(emulator, params, action) do
    params
    |> Enum.reduce(emulator, fn param, acc ->
      # Safely handle nil params
      if is_nil(param) do
        Logger.warn("Ignoring nil mode parameter in ANSI mode set/reset")
        acc
      else
        handle_single_ansi_mode(acc, param, action)
      end
    end)
  end

  # Private handlers for specific DEC modes
  defp handle_single_dec_mode(emulator, mode, action) do
    enabled = action == :set
    Logger.debug("#{if enabled, do: "Setting", else: "Resetting"} DEC private mode #{mode}")

    case mode do
      # DECCKM - Cursor Keys Mode
      1 ->
        ScreenModes.set_mode(emulator, ScreenModes.cursor_keys_application(), enabled)

      # DECANM - ANSI/VT52 Mode
      2 ->
        ScreenModes.set_mode(emulator, ScreenModes.ansi_mode(), enabled)

      # DECCOLM - 80/132 Column Mode
      3 ->
        ScreenModes.set_mode(emulator, ScreenModes.column_mode(), enabled)

      # DECSCLM - Smooth Scroll Mode
      4 ->
        ScreenModes.set_mode(emulator, ScreenModes.smooth_scroll(), enabled)

      # DECSCNM - Screen Mode (reverse video)
      5 ->
        ScreenModes.set_mode(emulator, ScreenModes.reverse_screen(), enabled)

      # DECOM - Origin Mode
      6 ->
        ScreenModes.set_mode(emulator, ScreenModes.origin_mode(), enabled)

      # DECAWM - Auto Wrap Mode
      7 ->
        ScreenModes.set_mode(emulator, ScreenModes.auto_wrap(), enabled)

      # DECARM - Auto Repeat Mode
      8 ->
        ScreenModes.set_mode(emulator, ScreenModes.auto_repeat(), enabled)

      # X10 Mouse Tracking Mode
      9 ->
        ScreenModes.set_mode(emulator, ScreenModes.mouse_x10(), enabled)

      # DECBKM - Backarrow Key Mode
      12 ->
        ScreenModes.set_mode(emulator, ScreenModes.backarrow_mode(), enabled)

      # DECTCEM - Text Cursor Enable Mode
      25 ->
        ScreenModes.set_mode(emulator, ScreenModes.show_cursor(), enabled)

      # DECNRCM - National Replacement Character Set Mode
      42 ->
        ScreenModes.set_mode(emulator, ScreenModes.nrc_mode(), enabled)

      # Use Alternate Screen Buffer
      47 ->
        if enabled do
          Emulator.use_alternate_buffer(emulator)
        else
          Emulator.use_main_buffer(emulator)
        end

      # DECCM - Cursor Position Visible
      1048 ->
        if enabled do
          cursor_pos = emulator.cursor.position
          %{emulator | saved_cursor_position: cursor_pos}
        else
          # Restore cursor position if saved
          case emulator.saved_cursor_position do
            nil -> emulator
            pos -> %{emulator | cursor: %{emulator.cursor | position: pos}}
          end
        end

      # DECCM + Use Alternative Screen Buffer
      1049 ->
        # Equivalent to 1048 + 47
        # First, save/restore cursor position
        em_with_cursor =
          if enabled do
            cursor_pos = emulator.cursor.position
            %{emulator | saved_cursor_position: cursor_pos}
          else
            # Restore cursor position if saved
            case emulator.saved_cursor_position do
              nil -> emulator
              pos -> %{emulator | cursor: %{emulator.cursor | position: pos}}
            end
          end

        # Then, switch screen buffer
        if enabled do
          Emulator.use_alternate_buffer(em_with_cursor)
        else
          Emulator.use_main_buffer(em_with_cursor)
        end

      # Bracketed Paste Mode
      2004 ->
        ScreenModes.set_mode(emulator, ScreenModes.bracketed_paste(), enabled)

      # Unknown mode - log and return unmodified emulator
      _ ->
        Logger.debug("Ignoring unknown DEC private mode: #{mode}")
        emulator
    end
  end

  # Private handlers for specific ANSI modes
  defp handle_single_ansi_mode(emulator, mode, action) do
    enabled = action == :set
    Logger.debug("#{if enabled, do: "Setting", else: "Resetting"} ANSI mode #{mode}")

    case mode do
      # Insert/Replace Mode (IRM)
      4 ->
        ScreenModes.set_mode(emulator, ScreenModes.insert_mode(), enabled)

      # Line Feed/New Line Mode (LNM)
      20 ->
        ScreenModes.set_mode(emulator, ScreenModes.new_line_mode(), enabled)

      # Unknown mode - log and return unmodified emulator
      _ ->
        Logger.debug("Ignoring unknown ANSI mode: #{mode}")
        emulator
    end
  end
end
