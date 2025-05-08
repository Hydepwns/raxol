defmodule Raxol.Terminal.Parser.States.DCSPassthroughMaybeSTState do
  @moduledoc """
  Handles the :dcs_passthrough_maybe_st state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  alias Raxol.Terminal.Commands.Executor
  require Logger

  @doc """
  Processes input when the parser is in the :dcs_passthrough_maybe_st state.
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:handled, Emulator.t()}
  def handle(
        emulator,
        %State{state: :dcs_passthrough_maybe_st} = parser_state,
        input
      ) do
    case input do
      # Found ST (ESC \), use literal 92 for '\'
      <<92, rest_after_st::binary>> ->
        # Completed DCS Sequence
        # Call the dispatcher function (now imported)
        new_emulator =
          Executor.execute_dcs_command(
            emulator,
            parser_state.params_buffer,
            parser_state.intermediates_buffer,
            parser_state.final_byte,
            parser_state.payload_buffer
          )

        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after_st}

      # Not ST
      <<_unexpected_byte, rest_after_unexpected::binary>> ->
        Logger.warning(
          "Malformed DCS termination: ESC not followed by ST. Returning to ground."
        )

        # Discard sequence, go to ground
        next_parser_state = %{parser_state | state: :ground}
        # Continue parsing AFTER the unexpected byte
        {:continue, emulator, next_parser_state, rest_after_unexpected}

      # Input ended after ESC, incomplete sequence
      <<>> ->
        Logger.warning(
          "Malformed DCS termination: Input ended after ESC. Returning to ground."
        )

        # Go to ground, return emulator as is
        {:handled, emulator}
    end
  end
end
