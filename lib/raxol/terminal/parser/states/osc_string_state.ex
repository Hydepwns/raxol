defmodule Raxol.Terminal.Parser.States.OSCStringState do
  @moduledoc """
  Handles the :osc_string state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  alias Raxol.Terminal.Commands.Executor
  require Raxol.Core.Runtime.Log

  @doc """
  Processes input when the parser is in the :osc_string state.
  Collects the OSC string until ST (ESC \) or BEL.
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:finished, Emulator.t(), State.t()}
          | {:incomplete, Emulator.t(), State.t()}
  def handle(
        emulator,
        %State{state: :osc_string} = parser_state,
        input
      ) do
    case input do
      <<>> ->
        # Incomplete OSC string - return current state
        Raxol.Core.Runtime.Log.debug(
          "[Parser] Incomplete OSC string, input ended."
        )

        {:incomplete, emulator, parser_state}

      # String Terminator (ST - ESC \) -- Use escape_char check first
      <<27, rest_after_esc::binary>> ->
        {:continue, emulator, %{parser_state | state: :osc_string_maybe_st},
         rest_after_esc}

      # BEL (7) is another valid terminator for OSC
      <<7, rest_after_bel::binary>> ->
        # Call the dispatcher function (now imported)
        new_emulator =
          Executor.execute_osc_command(
            emulator,
            parser_state.payload_buffer
          )

        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after_bel}

      # CAN/SUB abort OSC string
      <<abort_byte, rest_after_abort::binary>>
      when abort_byte == 0x18 or abort_byte == 0x1A ->
        Raxol.Core.Runtime.Log.debug("Aborting OSC String due to CAN/SUB")
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_abort}

      # Standard printable ASCII
      <<byte, rest_after_byte::binary>> when byte >= 32 and byte <= 126 ->
        next_parser_state = %{
          parser_state
          | payload_buffer: parser_state.payload_buffer <> <<byte>>
        }

        {:continue, emulator, next_parser_state, rest_after_byte}

      # Ignore C0/DEL bytes within OSC string
      <<_ignored_byte, rest_after_ignored::binary>> ->
        Raxol.Core.Runtime.Log.debug("Ignoring C0/DEL byte in OSC String")
        # Stay in state, ignore byte
        {:continue, emulator, parser_state, rest_after_ignored}
    end
  end
end
