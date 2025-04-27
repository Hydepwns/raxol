defmodule Raxol.Terminal.Parser.States.CSIParamState do
  @moduledoc """
  Handles the :csi_param state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  alias Raxol.Terminal.Commands.Executor
  require Logger

  @doc """
  Processes input when the parser is in the :csi_param state.
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()} | {:handled, Emulator.t()}
  def handle(emulator, %State{state: :csi_param} = parser_state, input) do
    # IO.inspect({:parse_loop_csi_param, parser_state.state, input}, label: "DEBUG_PARSER")
    case input do
      # Incomplete
      <<>> ->
        {:handled, emulator}

      # Parameter byte or separator
      <<param_byte, rest_after_param::binary>>
      when param_byte >= ?0 and param_byte <= ?; ->
        # Accumulate parameter directly
        next_parser_state = %{
          parser_state
          | params_buffer: parser_state.params_buffer <> <<param_byte>>
        }
        # Stay in csi_param state
        {:continue, emulator, next_parser_state, rest_after_param}

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

      # Final byte
      <<final_byte, rest_after_final::binary>>
      when final_byte >= 0x40 and final_byte <= 0x7E ->
        new_emulator =
          Executor.execute_csi_command(
            emulator,
            parser_state.params_buffer,
            parser_state.intermediates_buffer,
            final_byte
          )
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after_final}

      # Ignored byte in CSI Param (e.g., CAN, SUB)
      <<ignored_byte, rest_after_ignored::binary>>
      when ignored_byte == 0x18 or ignored_byte == 0x1A ->
        Logger.debug("Ignoring CAN/SUB byte in CSI Param")
        # Abort sequence, go to ground
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_ignored}

      # Other ignored bytes (0-1F excluding CAN/SUB, 7F)
      <<ignored_byte, rest_after_ignored::binary>>
      when (ignored_byte >= 0 and ignored_byte <= 23) or
             (ignored_byte >= 27 and ignored_byte <= 31) or ignored_byte == 127 ->
        Logger.debug("Ignoring C0/DEL byte #{ignored_byte} in CSI Param")
        # Stay in state, ignore byte
        {:continue, emulator, parser_state, rest_after_ignored}

      # Unhandled byte - go to ground
      <<unhandled_byte, rest_after_unhandled::binary>> ->
        Logger.warning(
          "Unhandled byte #{unhandled_byte} in CSI Param state, returning to ground."
        )
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_unhandled}
    end
  end
end
