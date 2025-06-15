defmodule Raxol.Terminal.Parser.States.CSIIntermediateState do
  @moduledoc """
  Handles the :csi_intermediate state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  alias Raxol.Terminal.Commands.Executor
  require Raxol.Core.Runtime.Log

  @doc """
  Processes input when the parser is in the :csi_intermediate state.
  Collects intermediate bytes (0x20-0x2F).
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:finished, Emulator.t(), State.t()}
          | {:incomplete, Emulator.t(), State.t()}
  def handle(
        emulator,
        %State{state: :csi_intermediate} = parser_state,
        input
      ) do
    case input do
      <<>> ->
        # Incomplete CSI sequence - return current state
        {:incomplete, emulator, parser_state}

      # Collect more intermediate bytes
      <<intermediate_byte, rest_after_intermediate::binary>>
      when intermediate_byte >= 0x20 and intermediate_byte <= 0x2F ->
        # Collect intermediate directly
        next_parser_state = %{
          parser_state
          | intermediates_buffer:
              parser_state.intermediates_buffer <> <<intermediate_byte>>
        }

        {:continue, emulator, next_parser_state, rest_after_intermediate}

      # Parameter byte or separator
      <<param_byte, rest_after_param::binary>>
      when param_byte >= ?0 and param_byte <= ?; ->
        # Accumulate parameter directly
        next_parser_state = %{
          parser_state
          | params_buffer: parser_state.params_buffer <> <<param_byte>>
        }

        # Transition back to csi_param state to continue collecting params
        {:continue, emulator, %{next_parser_state | state: :csi_param},
         rest_after_param}

      # Final byte (0x40 - 0x7E)
      <<final_byte, rest_after_final::binary>>
      when final_byte >= ?@ and final_byte <= ?~ ->
        final_emulator =
          Executor.execute_csi_command(
            emulator,
            parser_state.params_buffer,
            parser_state.intermediates_buffer,
            final_byte
          )

        Raxol.Core.Runtime.Log.debug(
          "CSIIntermediate: After execute, emulator.scroll_region=#{inspect(final_emulator.scroll_region)}"
        )

        # Transition back to Ground state
        next_parser_state = %{
          parser_state
          | state: :ground,
            params_buffer: "",
            intermediates_buffer: "",
            final_byte: nil
        }

        # Continue processing the rest of the input with the new state
        {:continue, final_emulator, next_parser_state, rest_after_final}

      # Ignored byte in CSI Intermediate (e.g., CAN, SUB)
      <<ignored_byte, rest_after_ignored::binary>>
      when ignored_byte == 0x18 or ignored_byte == 0x1A ->
        Raxol.Core.Runtime.Log.debug(
          "Ignoring CAN/SUB byte in CSI Intermediate"
        )

        # Abort sequence, go to ground
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_ignored}

      # Other ignored bytes (0-1F excluding CAN/SUB, 7F)
      <<ignored_byte, rest_after_ignored::binary>>
      when (ignored_byte >= 0 and ignored_byte <= 23 and ignored_byte != 0x18 and
              ignored_byte != 0x1A) or
             (ignored_byte >= 27 and ignored_byte <= 31) or ignored_byte == 127 ->
        Raxol.Core.Runtime.Log.debug(
          "Ignoring C0/DEL byte #{ignored_byte} in CSI Intermediate"
        )

        # Stay in state, ignore byte
        {:continue, emulator, parser_state, rest_after_ignored}

      # Unhandled byte (including 0x30-0x3F which VTTest ignores here) - go to ground
      <<_unhandled_byte, rest_after_unhandled::binary>> ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Unhandled byte #{_unhandled_byte} in CSI Intermediate state, returning to ground.",
          %{}
        )

        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_unhandled}
    end
  end
end
