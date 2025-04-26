defmodule Raxol.Terminal.Commands.Modes do
  @moduledoc """
  Handles terminal mode setting and resetting operations.

  This module manages DEC private mode and ANSI mode setting/resetting in the terminal,
  which control various aspects of terminal behavior like cursor visibility, line wrapping,
  alternate screen buffer, and more.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenModes
  alias Raxol.Terminal.ANSI.Sequences.Modes, as: ANSIModeSequences

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
  @spec handle_dec_private_mode(Emulator.t(), list(integer()), :set | :reset) ::
          Emulator.t()
  def handle_dec_private_mode(emulator, params, action) do
    enabled = action == :set

    params
    |> Enum.reduce(emulator, fn param, acc ->
      if is_nil(param) do
        Logger.warning("Ignoring nil mode parameter in DEC private mode set/reset")
        acc
      else
        # Lookup the mode atom
        case ScreenModes.lookup_private(param) do
          nil ->
            Logger.debug("Ignoring unknown DEC private mode code: #{param}")
            # Handle special cases not directly mapped by lookup
            handle_special_dec_mode(acc, param, enabled)

          mode_atom ->
            Logger.debug(
              "#{if enabled, do: "Setting", else: "Resetting"} DEC private mode #{param} (#{inspect(mode_atom)})"
            )

            # Use switch_mode/3 with the looked-up atom
            ScreenModes.switch_mode(acc, mode_atom, enabled)
        end
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
  @spec handle_ansi_mode(Emulator.t(), list(integer()), :set | :reset) ::
          Emulator.t()
  def handle_ansi_mode(emulator, params, action) do
    enabled = action == :set

    params
    |> Enum.reduce(emulator, fn param, acc ->
      if is_nil(param) do
        Logger.warning("Ignoring nil mode parameter in ANSI mode set/reset")
        acc
      else
        # Lookup the mode atom
        case ScreenModes.lookup_standard(param) do
          nil ->
            Logger.debug("Ignoring unknown ANSI mode code: #{param}")
            # Return unmodified accumulator for unknown standard modes
            acc

          mode_atom ->
            Logger.debug(
              "#{if enabled, do: "Setting", else: "Resetting"} ANSI mode #{param} (#{inspect(mode_atom)})"
            )

            # Use switch_mode/3 with the looked-up atom
            ScreenModes.switch_mode(acc, mode_atom, enabled)
        end
      end
    end)
  end

  # Private handler for special DEC cases not directly mapped by lookup_private
  # These often involve multiple actions (like saving cursor + switching buffer)
  defp handle_special_dec_mode(emulator, mode, enabled) do
    case mode do
      # Use Alternate Screen Buffer (DECALTBUF)
      # Note: 47 is not in lookup_private; handled here.
      47 ->
        Logger.debug(
          "Switching screen buffer (Mode 47) -> #{if enabled, do: "alternate", else: "main"}"
        )

        # Use the function from ANSI.Sequences.Modes
        ANSIModeSequences.set_alternate_buffer(emulator, enabled)

      # DECSCUR - Save Cursor position (not a mode switch)
      # Often used with 1049
      1048 ->
        Logger.debug("Saving/Restoring cursor position (Mode 1048)")

        if enabled do
          cursor_pos = emulator.cursor.position
          %{emulator | saved_cursor_position: cursor_pos}
        else
          # Restore cursor position if saved
          case emulator.saved_cursor_position do
            nil ->
              emulator

            pos ->
              %{
                emulator
                | cursor: %{emulator.cursor | position: pos},
                  saved_cursor_position: nil
              }
          end
        end

      # xterm Alternate Screen Buffer with cursor save/restore
      # Equivalent to 1048 + 47
      1049 ->
        Logger.debug(
          "Switching alt screen buffer + save/restore cursor (Mode 1049)"
        )

        # First, save/restore cursor position (like 1048)
        em_with_cursor =
          if enabled do
            cursor_pos = emulator.cursor.position
            %{emulator | saved_cursor_position: cursor_pos}
          else
            # Restore cursor position if saved
            case emulator.saved_cursor_position do
              nil ->
                emulator

              pos ->
                %{
                  emulator
                  | cursor: %{emulator.cursor | position: pos},
                    saved_cursor_position: nil
                }
            end
          end

        # Then, switch screen buffer (like 47)
        # Use the function from ANSI.Sequences.Modes
        ANSIModeSequences.set_alternate_buffer(em_with_cursor, enabled)

      # Bracketed Paste Mode (Not in lookup map? Add or handle here)
      # Should be mapped to :bracketed_paste atom if possible
      2004 ->
        Logger.debug("Setting bracketed paste mode (Mode 2004) -> #{enabled}")
        # Assuming :bracketed_paste is the correct atom, delegate
        # If :bracketed_paste is not defined in ANSI.ScreenModes, this will need adjustment
        ScreenModes.switch_mode(emulator, :bracketed_paste, enabled)

      # Unknown mode code
      _ ->
        # Already logged in handle_dec_private_mode
        emulator
    end
  end

  # Note: handle_single_dec_mode and handle_single_ansi_mode are removed
  # as their logic is incorporated into the main handle functions.
end
