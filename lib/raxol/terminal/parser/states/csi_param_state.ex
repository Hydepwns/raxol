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
  Collects parameter digits (0-9) and semicolons (;).
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:finished, Emulator.t(), State.t()}
          | {:incomplete, Emulator.t(), State.t()}
  def handle(emulator, %State{state: :csi_param} = parser_state, input) do
    Logger.debug(
      "CSIParamState ENTER: input=#{inspect(input)}, params_buffer=#{inspect(parser_state.params_buffer)}"
    )

    # IO.inspect({:parse_loop_csi_param, parser_state.state, input}, label: "DEBUG_PARSER")
    case input do
      <<>> ->
        # Incomplete CSI sequence - return current state
        {:incomplete, emulator, parser_state}

      # Parameter digit
      <<digit, rest::binary>> when digit >= ?0 and digit <= ?9 ->
        next_parser_state = %{
          parser_state
          | params_buffer: parser_state.params_buffer <> <<digit>>
        }

        {:continue, emulator, next_parser_state, rest}

      # Parameter separator
      <<?;, rest::binary>> ->
        next_parser_state = %{
          parser_state
          | params_buffer: parser_state.params_buffer <> <<?;>>
        }

        {:continue, emulator, next_parser_state, rest}

      # Intermediate byte
      <<intermediate_byte, rest_after_intermediate::binary>>
      when intermediate_byte >= 0x20 and intermediate_byte <= 0x2F ->
        # Collect intermediate directly
        next_parser_state = %{
          parser_state
          | intermediates_buffer:
              parser_state.intermediates_buffer <> <<intermediate_byte>>
        }

        # Transition to csi_intermediate state
        {:continue, emulator, %{next_parser_state | state: :csi_intermediate},
         rest_after_intermediate}

      # Final byte (0x40 - 0x7E) -> Execute command
      <<final_byte, rest::binary>> when final_byte >= ?@ and final_byte <= ?~ ->
        # Logger.debug("[CSIParam Final] Calling Executor with intermediates: #{inspect(parser_state.intermediates_buffer)}") # Remove Log
        final_emulator =
          Executor.execute_csi_command(
            emulator,
            parser_state.params_buffer,
            parser_state.intermediates_buffer,
            final_byte
          )

        # Logger.debug("CSIParamState: After execute, emulator.scroll_region=#{inspect(final_emulator.scroll_region)}")
        # Transition back to Ground state
        next_parser_state = %{
          parser_state
          | state: :ground,
            params_buffer: "",
            intermediates_buffer: "",
            final_byte: nil
        }

        # Continue processing the rest of the input with the new state
        {:continue, final_emulator, next_parser_state, rest}

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
