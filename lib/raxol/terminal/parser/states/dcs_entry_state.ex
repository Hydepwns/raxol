defmodule Raxol.Terminal.Parser.States.DCSEntryState do
  @moduledoc """
  Handles the :dcs_entry state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  require Logger

  @doc """
  Processes input when the parser is in the :dcs_entry state.
  Similar to CSI Entry - collects params/intermediates/final byte.
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:finished, Emulator.t(), State.t()}
          | {:incomplete, Emulator.t(), State.t()}
  def handle(emulator, %State{state: :dcs_entry} = parser_state, input) do
    # IO.inspect({:parse_loop_dcs_entry, parser_state.state, input}, label: "DEBUG_PARSER")
    case input do
      <<>> ->
        # Incomplete DCS sequence - return current state
        {:incomplete, emulator, parser_state}

      # Parameter byte
      <<param_byte, rest_after_param::binary>>
      when param_byte >= ?0 and param_byte <= ?9 ->
        # Accumulate parameter directly
        next_parser_state = %{
          parser_state
          | params_buffer: parser_state.params_buffer <> <<param_byte>>
        }

        # Stay in dcs_entry while collecting params/intermediates
        {:continue, emulator, next_parser_state, rest_after_param}

      # Semicolon parameter separator
      <<?;, rest_after_param::binary>> ->
        # Accumulate separator directly
        next_parser_state = %{
          parser_state
          | params_buffer: parser_state.params_buffer <> <<?;>>
        }

        {:continue, emulator, next_parser_state, rest_after_param}

      # Intermediate byte
      <<intermediate_byte, rest_after_intermediate::binary>>
      when intermediate_byte >= 0x20 and intermediate_byte <= 0x2F ->
        # Collect intermediate directly
        next_parser_state = %{
          parser_state
          | intermediates_buffer:
              parser_state.intermediates_buffer <> <<intermediate_byte>>
        }

        {:continue, emulator, next_parser_state, rest_after_intermediate}

      # Final byte (ends DCS header, moves to passthrough)
      <<final_byte, rest_after_final::binary>>
      when final_byte >= 0x40 and final_byte <= 0x7E ->
        next_parser_state = %{
          parser_state
          | state: :dcs_passthrough,
            final_byte: final_byte,
            payload_buffer: ""
        }

        {:continue, emulator, next_parser_state, rest_after_final}

      # Ignored byte in DCS Entry (e.g., CAN, SUB)
      <<ignored_byte, rest_after_ignored::binary>>
      when ignored_byte == 0x18 or ignored_byte == 0x1A ->
        Logger.debug("Ignoring CAN/SUB byte in DCS Entry")
        # Abort sequence, go to ground
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_ignored}

      # Other ignored bytes (0-1F excluding CAN/SUB, 7F)
      <<ignored_byte, rest_after_ignored::binary>>
      when (ignored_byte >= 0 and ignored_byte <= 23) or
             (ignored_byte >= 27 and ignored_byte <= 31) or ignored_byte == 127 ->
        Logger.debug("Ignoring C0/DEL byte #{ignored_byte} in DCS Entry")
        # Stay in state, ignore byte
        {:continue, emulator, parser_state, rest_after_ignored}

      # Unhandled byte - go to ground
      <<unhandled_byte, rest_after_unhandled::binary>> ->
        Logger.warning(
          "Unhandled byte #{unhandled_byte} in DCS Entry state, returning to ground."
        )

        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_unhandled}
    end
  end
end
