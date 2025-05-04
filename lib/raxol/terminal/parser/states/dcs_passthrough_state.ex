defmodule Raxol.Terminal.Parser.States.DCSPassthroughState do
  @moduledoc """
  Handles the :dcs_passthrough state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  alias Raxol.Terminal.Commands.Executor
  require Logger

  @doc """
  Processes input when the parser is in the :dcs_passthrough state.
  Collects the DCS data string until ST (ESC \).
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:finished, Emulator.t(), State.t()}
          | {:incomplete, Emulator.t(), State.t()}
  def handle(
        emulator,
        %State{state: :dcs_passthrough} = parser_state,
        input
      ) do
    # IO.inspect({:parse_loop_dcs_passthrough, parser_state.state, input}, label: "DEBUG_PARSER")
    case input do
      <<>> ->
        # Incomplete DCS string - return current state
        Logger.debug("[Parser] Incomplete DCS string, input ended.")
        {:incomplete, emulator, parser_state}

      # String Terminator (ST - ESC \) -- Use escape_char check first
      <<27, rest_after_esc::binary>> ->
        {:continue, emulator, %{parser_state | state: :dcs_passthrough_maybe_st}, rest_after_esc}

      # Collect payload bytes (>= 0x20), excluding DEL (0x7F)
      <<byte, rest_after_byte::binary>> when byte >= 0x20 and byte != 0x7F ->
        next_parser_state = %{
          parser_state
          | payload_buffer: parser_state.payload_buffer <> <<byte>>
        }
        {:continue, emulator, next_parser_state, rest_after_byte}

      # CAN/SUB abort DCS passthrough
      <<abort_byte, rest_after_abort::binary>>
      when abort_byte == 0x18 or abort_byte == 0x1A ->
        Logger.debug("Aborting DCS Passthrough due to CAN/SUB")
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_abort}

      # Ignore C0 bytes (0x00-0x1F) and DEL (0x7F) during DCS passthrough
      # (ESC, CAN, SUB handled explicitly)
      <<_ignored_byte, rest_after_ignored::binary>> ->
        Logger.debug("Ignoring C0/DEL byte in DCS Passthrough")
        {:continue, emulator, parser_state, rest_after_ignored}
    end
  end
end
