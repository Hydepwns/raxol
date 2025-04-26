defmodule Raxol.Terminal.Parser.States.OSCStringMaybeSTState do
  @moduledoc """
  Handles the :osc_string_maybe_st state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  # Import main parser for helper functions
  import Raxol.Terminal.Parser, only: [dispatch_osc_command: 2]
  require Logger

  @doc """
  Processes input when the parser is in the :osc_string_maybe_st state.
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()} | {:handled, Emulator.t()}
  def handle(
        emulator,
        %State{state: :osc_string_maybe_st} = parser_state,
        input
      ) do
    case input do
      # Found ST (ESC \), use literal 92 for '\'
      <<92, rest_after_st::binary>> ->
        # Call the dispatcher function (now imported)
        new_emulator =
          dispatch_osc_command(
            emulator,
            parser_state.payload_buffer
          )
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after_st}

      # Not ST
      <<_unexpected_byte, rest_after_unexpected::binary>> ->
        Logger.warning(
          "Malformed OSC termination: ESC not followed by ST. Returning to ground."
        )
        # Discard sequence, go to ground
        next_parser_state = %{parser_state | state: :ground}
        # Continue parsing AFTER the unexpected byte
        {:continue, emulator, next_parser_state, rest_after_unexpected}

      # Input ended after ESC, incomplete sequence
      <<>> ->
        Logger.warning(
          "Malformed OSC termination: Input ended after ESC. Returning to ground."
        )
        # Go to ground, return emulator as is
        {:handled, emulator}
    end
  end
end
