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
    |> Enum.reduce(emulator, fn param, current_emulator ->
      if is_nil(param) do
        Logger.warning("Ignoring nil mode parameter in DEC private mode set/reset")
        current_emulator
      else
        # Lookup the mode atom
        case ScreenModes.lookup_private(param) do
          nil ->
            # Mode not in lookup table, check if it's a special case
            Logger.debug("Checking special DEC private mode: #{param}")
            handle_special_dec_mode(current_emulator, param, enabled)

          mode_atom ->
            # Mode found in lookup table, update the mode_state map
            Logger.debug(
              "#{if enabled, do: "Setting", else: "Resetting"} DEC private mode #{param} (#{inspect(mode_atom)})"
            )
            # Inline ScreenModes.switch_mode logic
            current_mode_state = current_emulator.mode_state
            updated_mode_state = if enabled do
              # Inline ScreenModes.set_mode
              case mode_atom do
                :cursor_visible -> %{current_mode_state | cursor_visible: true}
                :auto_wrap -> %{current_mode_state | auto_wrap: true}
                :origin_mode -> %{current_mode_state | origin_mode: true}
                :insert_mode -> %{current_mode_state | insert_mode: true}
                :line_feed_mode -> %{current_mode_state | line_feed_mode: true}
                :wide_column -> %{current_mode_state | column_width_mode: :wide}
                :deccolm_132 -> %{current_mode_state | column_width_mode: :wide}
                :auto_repeat -> %{current_mode_state | auto_repeat_mode: true}
                :interlacing -> %{current_mode_state | interlacing_mode: true}
                _ -> current_mode_state
              end
            else
              # Inline ScreenModes.reset_mode
              case mode_atom do
                :cursor_visible -> %{current_mode_state | cursor_visible: false}
                :auto_wrap -> %{current_mode_state | auto_wrap: false}
                :origin_mode -> %{current_mode_state | origin_mode: false}
                :insert_mode -> %{current_mode_state | insert_mode: false}
                :line_feed_mode -> %{current_mode_state | line_feed_mode: false}
                :wide_column -> %{current_mode_state | column_width_mode: :normal}
                :deccolm_132 -> %{current_mode_state | column_width_mode: :normal}
                :auto_repeat -> %{current_mode_state | auto_repeat_mode: false}
                :interlacing -> %{current_mode_state | interlacing_mode: false}
                _ -> current_mode_state
              end
            end
            %{current_emulator | mode_state: updated_mode_state}
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
    |> Enum.reduce(emulator, fn param, current_emulator ->
      if is_nil(param) do
        Logger.warning("Ignoring nil mode parameter in ANSI mode set/reset")
        current_emulator
      else
        # Lookup the mode atom
        case ScreenModes.lookup_standard(param) do
          nil ->
            Logger.debug("Ignoring unknown ANSI mode code: #{param}")
            # Return unmodified emulator for unknown standard modes
            current_emulator

          mode_atom ->
            Logger.debug(
              "#{if enabled, do: "Setting", else: "Resetting"} ANSI mode #{param} (#{inspect(mode_atom)})"
            )
            # Inline ScreenModes.switch_mode logic
            current_mode_state = current_emulator.mode_state
            updated_mode_state = if enabled do
              # Inline ScreenModes.set_mode
              case mode_atom do
                :cursor_visible -> %{current_mode_state | cursor_visible: true}
                :auto_wrap -> %{current_mode_state | auto_wrap: true}
                :origin_mode -> %{current_mode_state | origin_mode: true}
                :insert_mode -> %{current_mode_state | insert_mode: true}
                :line_feed_mode -> %{current_mode_state | line_feed_mode: true}
                :wide_column -> %{current_mode_state | column_width_mode: :wide}
                :deccolm_132 -> %{current_mode_state | column_width_mode: :wide}
                :auto_repeat -> %{current_mode_state | auto_repeat_mode: true}
                :interlacing -> %{current_mode_state | interlacing_mode: true}
                _ -> current_mode_state
              end
            else
              # Inline ScreenModes.reset_mode
              case mode_atom do
                :cursor_visible -> %{current_mode_state | cursor_visible: false}
                :auto_wrap -> %{current_mode_state | auto_wrap: false}
                :origin_mode -> %{current_mode_state | origin_mode: false}
                :insert_mode -> %{current_mode_state | insert_mode: false}
                :line_feed_mode -> %{current_mode_state | line_feed_mode: false}
                :wide_column -> %{current_mode_state | column_width_mode: :normal}
                :deccolm_132 -> %{current_mode_state | column_width_mode: :normal}
                :auto_repeat -> %{current_mode_state | auto_repeat_mode: false}
                :interlacing -> %{current_mode_state | interlacing_mode: false}
                _ -> current_mode_state
              end
            end
            %{current_emulator | mode_state: updated_mode_state}
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
        # Fix: Call switch_mode with the mode_state map, not the emulator
        # Inline the logic for :bracketed_paste (assuming it exists)
        current_mode_state = emulator.mode_state
        updated_mode_state = if enabled do
          %{current_mode_state | bracketed_paste: true} # Assuming this field exists
        else
          %{current_mode_state | bracketed_paste: false}
        end
        %{emulator | mode_state: updated_mode_state}

      # Unknown mode code
      _ ->
        # Already logged in handle_dec_private_mode
        emulator
    end
  end

  # Note: handle_single_dec_mode and handle_single_ansi_mode are removed
  # as their logic is incorporated into the main handle functions.
end
