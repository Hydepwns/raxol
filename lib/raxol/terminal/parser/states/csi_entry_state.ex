defmodule Raxol.Terminal.Parser.States.CSIEntryState do
  @moduledoc """
  Handles the :csi_entry state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  alias Raxol.Terminal.Commands.Executor
  require Logger

  @doc """
  Processes input when the parser is in the :csi_entry state.
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:finished, Emulator.t(), State.t()}
          | {:incomplete, Emulator.t(), State.t()}
  def handle(emulator, %State{state: :csi_entry} = parser_state, input) do
    # IO.inspect({:parse_loop_csi_entry, parser_state.state, input}, label: "DEBUG_PARSER")
    case input do
      <<>> ->
        # Incomplete CSI sequence - return current state
        {:incomplete, emulator, parser_state}

      # Parameter byte
      <<param_byte, rest_after_param::binary>>
      when param_byte >= ?0 and param_byte <= ?9 ->
        # Accumulate parameter directly
        next_parser_state = %{
          parser_state
          | params_buffer: parser_state.params_buffer <> <<param_byte>>
        }
        # Transition to csi_param state
        {:continue, emulator, %{next_parser_state | state: :csi_param}, rest_after_param}

      # Semicolon parameter separator
      <<?;, rest_after_param::binary>> ->
        # Accumulate separator directly
        next_parser_state = %{
          parser_state
          | params_buffer: parser_state.params_buffer <> <<?;>>
        }
        # Transition to csi_param state
        {:continue, emulator, %{next_parser_state | state: :csi_param}, rest_after_param}

      # Intermediate byte
      <<intermediate_byte, rest_after_intermediate::binary>>
      when intermediate_byte >= 0x20 and intermediate_byte <= 0x2F ->
        # Collect intermediate directly
        next_parser_state = %{
          parser_state
          | intermediates_buffer: parser_state.intermediates_buffer <> <<intermediate_byte>>
        }
        # Transition to csi_intermediate state
        {:continue, emulator, %{next_parser_state | state: :csi_intermediate}, rest_after_intermediate}

      # Private marker / CSI leader byte (? > = <)
      <<private_marker, rest_after_private::binary>>
      when private_marker >= 0x3C and private_marker <= 0x3F ->
        # Collect private marker as intermediate directly
        next_parser_state = %{
          parser_state
          | intermediates_buffer: parser_state.intermediates_buffer <> <<private_marker>>
        }
        # Transition to csi_param state AFTER collecting marker
        {:continue, emulator, %{next_parser_state | state: :csi_param}, rest_after_private}

      # Final byte
      <<final_byte, rest_after_final::binary>>
      when final_byte >= ?@ and final_byte <= ?~ ->
        # Check for X10 Mouse Report: CSI M Cb Cx Cy ( ESC [ M Cb Cx Cy )
        # This is identified by final_byte == ?M, empty params, and empty intermediates.
        if final_byte == ?M and parser_state.params_buffer == "" and
           parser_state.intermediates_buffer == "" do
          active_mouse_mode = emulator.mode_manager.mouse_report_mode

          # Relevant modes that might expect to echo/process raw X10 reports:
          # :normal (set by \e[?1000h for X10 reporting) - Note: ModeManager now sets :x10 for 1000h
          # :cell_motion (set by \e[?1002h for X11 button-event)
          # :all_motion (set by \e[?1003h for X11 all-motion)
          if active_mouse_mode in [:x10, :normal, :cell_motion, :all_motion] do
            # Try to consume Cb, Cx, Cy (3 bytes) from the rest of the input
            case rest_after_final do
              <<cb, cx, cy, actual_rest::binary>> ->
                # Successfully got 3 bytes for mouse report
                mouse_report_sequence = <<27, 91, ?M, cb, cx, cy>> # Construct \e[MCbCxCy

                Logger.debug(
                  "[CSIEntryState] X10-style Mouse Report detected. Mode: #{active_mouse_mode}. Echoing: #{inspect(mouse_report_sequence)}"
                )

                new_output_buffer = emulator.output_buffer <> mouse_report_sequence
                new_emulator = %{emulator | output_buffer: new_output_buffer}
                # Transition back to Ground state, clearing buffers
                next_parser_state = %{parser_state | state: :ground, params_buffer: "", intermediates_buffer: "", final_byte: nil}
                {:continue, new_emulator, next_parser_state, actual_rest}

              _ ->
                # Not enough bytes for a full CbCxCy mouse report.
                # This could be an incomplete sequence or just CSI M (DL).
                # Fallback to default M (e.g., Delete Character via Executor).
                Logger.debug(
                  "[CSIEntryState] CSI M with active mouse mode, but not enough bytes for X10 CbCxCy. Falling back to Executor."
                )
                new_emulator_fallback =
                  Executor.execute_csi_command(
                    emulator,
                    "", # params_buffer is empty
                    "", # intermediates_buffer is empty
                    final_byte # ?M
                  )
                next_parser_state_fallback = %{parser_state | state: :ground, params_buffer: "", intermediates_buffer: "", final_byte: nil}
                {:continue, new_emulator_fallback, next_parser_state_fallback, rest_after_final}
            end
          else
            # Not a mouse mode that processes raw X10, or it's CSI M intended for DL.
            # Proceed with normal execution for M (Delete Character).
            Logger.debug(
              "[CSIEntryState] CSI M detected, but not in a relevant X10-echoing mouse mode (mode: #{active_mouse_mode}) or params/intermediates were present. Executing."
            )
            new_emulator_default =
              Executor.execute_csi_command(
                emulator,
                parser_state.params_buffer, # Will be empty here
                parser_state.intermediates_buffer, # Will be empty here
                final_byte # ?M
              )
            next_parser_state_default = %{parser_state | state: :ground, params_buffer: "", intermediates_buffer: "", final_byte: nil}
            {:continue, new_emulator_default, next_parser_state_default, rest_after_final}
          end
        else
          # Not (final_byte == ?M with empty params/intermediates). Handle all other final bytes normally.
          Logger.debug(
            "[CSIEntryState] Standard CSI Final Byte: #{<<final_byte>>}. Params: '#{parser_state.params_buffer}', Intermediates: '#{parser_state.intermediates_buffer}'. Executing."
          )
          new_emulator_other =
            Executor.execute_csi_command(
              emulator,
              parser_state.params_buffer,
              parser_state.intermediates_buffer,
              final_byte
            )
          # Transition back to Ground state, clearing buffers for the next sequence
          next_parser_state_other = %{parser_state | state: :ground, params_buffer: "", intermediates_buffer: "", final_byte: nil}
          {:continue, new_emulator_other, next_parser_state_other, rest_after_final}
        end

      # Ignored byte in CSI Entry (e.g., CAN, SUB)
      <<ignored_byte, rest_after_ignored::binary>>
      when ignored_byte == 0x18 or ignored_byte == 0x1A ->
        Logger.debug("Ignoring CAN/SUB byte in CSI Entry")
        # Abort sequence, go to ground
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_ignored}

      # Other ignored bytes (0-1F excluding CAN/SUB, 7F)
      <<ignored_byte, rest_after_ignored::binary>>
      when (ignored_byte >= 0 and ignored_byte <= 23) or
             (ignored_byte >= 27 and ignored_byte <= 31) or ignored_byte == 127 ->
        Logger.debug("Ignoring C0/DEL byte #{ignored_byte} in CSI Entry")
        # Stay in state, ignore byte
        {:continue, emulator, parser_state, rest_after_ignored}

      # Unhandled byte - go to ground
      <<unhandled_byte, rest_after_unhandled::binary>> ->
        Logger.warning(
          "Unhandled byte #{unhandled_byte} in CSI Entry state, returning to ground."
        )
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_unhandled}
    end
  end
end
