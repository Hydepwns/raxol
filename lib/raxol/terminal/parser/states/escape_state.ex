defmodule Raxol.Terminal.Parser.States.EscapeState do
  @moduledoc """
  Handles the :escape state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  alias Raxol.Terminal.ControlCodes
  require Logger

  @doc """
  Processes input when the parser is in the :escape state.
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:finished, Emulator.t(), State.t()}
          | {:incomplete, Emulator.t(), State.t()}
  def handle(emulator, %State{state: :escape} = parser_state, input) do
    case input do
      # Empty input
      <<>> ->
        # IO.inspect({:parse_loop_escape_empty, parser_state.state, ""}, label: "DEBUG_PARSER")
        # Incomplete - return current state
        {:incomplete, emulator, parser_state}

      # CSI
      <<91, rest_after_csi::binary>> ->
        # IO.inspect({:parse_loop_escape_csi, parser_state.state, input}, label: "DEBUG_PARSER")
        # Clear buffers for the new sequence
        next_parser_state = %{parser_state | state: :csi_entry, params_buffer: "", intermediates_buffer: ""}
        {:continue, emulator, next_parser_state, rest_after_csi}

      # OSC
      <<93, rest_after_osc::binary>> ->
        # IO.inspect({:parse_loop_escape_osc, parser_state.state, input}, label: "DEBUG_PARSER")
        next_parser_state = %{parser_state | state: :osc_string, payload_buffer: ""}
        {:continue, emulator, next_parser_state, rest_after_osc}

      # DCS
      <<80, rest_after_dcs::binary>> ->
        # IO.inspect({:parse_loop_escape_dcs, parser_state.state, input}, label: "DEBUG_PARSER")
        next_parser_state = %{
          parser_state
          | state: :dcs_entry,
            params_buffer: "",
            intermediates_buffer: "",
            payload_buffer: ""
        }
        {:continue, emulator, next_parser_state, rest_after_dcs}

      # Designate G0
      <<?(, rest_after::binary>> ->
        # IO.inspect({:parse_loop_escape_designate_g0, parser_state.state, input}, label: "DEBUG_PARSER")
        next_parser_state = %{
          parser_state
          | state: :designate_charset,
            designating_gset: 0
        }
        {:continue, emulator, next_parser_state, rest_after}

      # Designate G1
      <<?), rest_after::binary>> ->
        # IO.inspect({:parse_loop_escape_designate_g1, parser_state.state, input}, label: "DEBUG_PARSER")
        next_parser_state = %{
          parser_state
          | state: :designate_charset,
            designating_gset: 1
        }
        {:continue, emulator, next_parser_state, rest_after}

      # Designate G2
      <<?*, rest_after::binary>> ->
        # IO.inspect({:parse_loop_escape_designate_g2, parser_state.state, input}, label: "DEBUG_PARSER")
        next_parser_state = %{
          parser_state
          | state: :designate_charset,
            designating_gset: 2
        }
        {:continue, emulator, next_parser_state, rest_after}

      # Designate G3
      <<?+, rest_after::binary>> ->
        # IO.inspect({:parse_loop_escape_designate_g3, parser_state.state, input}, label: "DEBUG_PARSER")
        next_parser_state = %{
          parser_state
          | state: :designate_charset,
            designating_gset: 3
        }
        {:continue, emulator, next_parser_state, rest_after}

      # SS2
      <<78, rest_after_ss::binary>> ->
        # IO.inspect({:parse_loop_escape_ss2, parser_state.state, input}, label: "DEBUG_PARSER")
        Logger.info("[Parser] SS2 received - Not implemented")
        # TODO: Implement SS2 handling (invoke G2 for next char)
        # Return to ground after SS2
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_ss}

      # SS3
      <<79, rest_after_ss::binary>> ->
        # IO.inspect({:parse_loop_escape_ss3, parser_state.state, input}, label: "DEBUG_PARSER")
        Logger.info("[Parser] SS3 received - Not implemented")
        # TODO: Implement SS3 handling (invoke G3 for next char)
        # Return to ground after SS3
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_ss}

      # RIS
      <<?c, rest_after::binary>> ->
        # IO.inspect({:parse_loop_escape_ris, parser_state.state, input}, label: "DEBUG_PARSER")
        # Call back to Emulator
        new_emulator = ControlCodes.handle_ris(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # IND
      <<?D, rest_after::binary>> ->
        # IO.inspect({:parse_loop_escape_ind, parser_state.state, input}, label: "DEBUG_PARSER")
        # Call back to Emulator
        new_emulator = ControlCodes.handle_ind(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # NEL
      <<?E, rest_after::binary>> ->
        # IO.inspect({:parse_loop_escape_nel, parser_state.state, input}, label: "DEBUG_PARSER")
        # Call back to Emulator
        new_emulator = ControlCodes.handle_nel(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # HTS
      <<?H, rest_after::binary>> ->
        # IO.inspect({:parse_loop_escape_hts, parser_state.state, input}, label: "DEBUG_PARSER")
        # Call back to Emulator
        new_emulator = ControlCodes.handle_hts(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # RI
      <<?M, rest_after::binary>> ->
        # IO.inspect({:parse_loop_escape_ri, parser_state.state, input}, label: "DEBUG_PARSER")
        # Call back to Emulator
        new_emulator = ControlCodes.handle_ri(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # DECSC
      <<?7, rest_after::binary>> ->
        # IO.inspect({:parse_loop_escape_decsc, parser_state.state, input}, label: "DEBUG_PARSER")
        # Call back to Emulator
        new_emulator = ControlCodes.handle_decsc(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # DECRC
      <<?8, rest_after::binary>> ->
        # IO.inspect({:parse_loop_escape_decrc, parser_state.state, input}, label: "DEBUG_PARSER")
        # Call back to Emulator
        new_emulator = ControlCodes.handle_decrc(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # Fallback for unhandled char after ESC
      <<char_codepoint, rest_after_char::binary>> ->
        # IO.inspect({:parse_loop_escape_fallback, parser_state.state, input, char_codepoint}, label: "DEBUG_PARSER")
        Logger.debug(
          "[Parser] Unhandled char #{inspect(char_codepoint)} after ESC, returning to ground."
        )
        next_parser_state = %{parser_state | state: :ground}
        # Effectively ignore the char and go back to ground with the rest
        {:continue, emulator, next_parser_state, rest_after_char}
    end
  end
end
