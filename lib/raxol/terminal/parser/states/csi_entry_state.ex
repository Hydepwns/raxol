defmodule Raxol.Terminal.Parser.States.CSIEntryState do
  @moduledoc """
  Handles the :csi_entry state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  alias Raxol.Terminal.Commands.Executor
  require Raxol.Core.Runtime.Log

  @doc """
  Processes input when the parser is in the :csi_entry state.
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:handled, Emulator.t()}
  def handle(
        emulator,
        %State{state: :csi_entry} = parser_state,
        input
      ) do
    case input do
      # Handle CAN/SUB bytes first (abort sequence)
      <<ignored_byte, rest_after_ignored::binary>>
      when ignored_byte == 0x18 or ignored_byte == 0x1A ->
        Raxol.Core.Runtime.Log.debug(
          "Ignoring CAN/SUB byte during CSI Entry state"
        )

        # Abort sequence, go to ground
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_ignored}

      # Handle parameter bytes (0-9, ;)
      <<param_byte, rest_after_param::binary>>
      when param_byte in ?0..?9 or param_byte == ?; ->
        next_parser_state = %{
          parser_state
          | state: :csi_param,
            params_buffer: parser_state.params_buffer <> <<param_byte>>
        }
        {:continue, emulator, next_parser_state, rest_after_param}

      # Handle intermediate bytes (0x20-0x2F)
      <<intermediate_byte, rest_after_intermediate::binary>>
      when intermediate_byte in 0x20..0x2F ->
        next_parser_state = %{
          parser_state
          | state: :csi_intermediate,
            intermediates_buffer: parser_state.intermediates_buffer <> <<intermediate_byte>>
        }
        {:continue, emulator, next_parser_state, rest_after_intermediate}

      # Handle final byte (0x30-0x7E)
      <<final_byte, rest_after_final::binary>>
      when final_byte in 0x30..0x7E ->
        # Execute CSI command
        new_emulator =
          Executor.execute_csi_command(
            emulator,
            parser_state.params_buffer,
            parser_state.intermediates_buffer,
            <<final_byte>>
          )

        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after_final}

      # Handle unhandled bytes
      <<unhandled_byte, rest_after_unhandled::binary>> ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Unhandled byte in CSI Entry state: #{inspect(unhandled_byte)}",
          %{}
        )

        # Go to ground state
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_unhandled}

      # Handle incomplete sequence
      <<>> ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Incomplete CSI sequence",
          %{}
        )

        # Stay in CSI entry state
        {:incomplete, emulator, parser_state}
    end
  end
end
