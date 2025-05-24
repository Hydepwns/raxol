defmodule Raxol.Terminal.Parser.States.EscapeState do
  @moduledoc """
  Handles the :escape state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  alias Raxol.Terminal.ControlCodes
  alias Raxol.Terminal.ANSI.CharacterSets
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
        # Incomplete - return current state
        {:incomplete, emulator, parser_state}

      # CSI
      <<91, rest_after_csi::binary>> ->
        # Clear buffers for the new sequence
        next_parser_state = %{
          parser_state
          | state: :csi_entry,
            params_buffer: "",
            intermediates_buffer: ""
        }

        {:continue, emulator, next_parser_state, rest_after_csi}

      # OSC
      <<93, rest_after_osc::binary>> ->
        next_parser_state = %{
          parser_state
          | state: :osc_string,
            payload_buffer: ""
        }

        {:continue, emulator, next_parser_state, rest_after_osc}

      # DCS
      <<80, rest_after_dcs::binary>> ->
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
        next_parser_state = %{
          parser_state
          | state: :designate_charset,
            designating_gset: 0
        }

        {:continue, emulator, next_parser_state, rest_after}

      # Designate G1
      <<?), rest_after::binary>> ->
        next_parser_state = %{
          parser_state
          | state: :designate_charset,
            designating_gset: 1
        }

        {:continue, emulator, next_parser_state, rest_after}

      # Designate G2
      <<?*, rest_after::binary>> ->
        next_parser_state = %{
          parser_state
          | state: :designate_charset,
            designating_gset: 2
        }

        {:continue, emulator, next_parser_state, rest_after}

      # Designate G3
      <<?+, rest_after::binary>> ->
        next_parser_state = %{
          parser_state
          | state: :designate_charset,
            designating_gset: 3
        }

        {:continue, emulator, next_parser_state, rest_after}

      # SS2 (Single Shift 2)
      <<78, rest_after_ss::binary>> ->
        Logger.info("[Parser] SS2 received - will use G2 for next char only")
        # Set single_shift to :ss2 and return to ground
        next_parser_state = %{parser_state | state: :ground, single_shift: :ss2}
        {:continue, emulator, next_parser_state, rest_after_ss}

      # SS3 (Single Shift 3)
      <<79, rest_after_ss3::binary>> ->
        Logger.info("[Parser] SS3 received - will use G3 for next char only")
        # Set single_shift to :ss3 and return to ground
        next_parser_state = %{parser_state | state: :ground, single_shift: :ss3}
        {:continue, emulator, next_parser_state, rest_after_ss3}

      # LS2 (Invoke G2 in GL)
      <<?n, rest_after::binary>> ->
        new_charset_state = CharacterSets.set_gl(emulator.charset_state, :g2)
        new_emulator = %{emulator | charset_state: new_charset_state}
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # LS3 (Invoke G3 in GL)
      <<?o, rest_after::binary>> ->
        new_charset_state = CharacterSets.set_gl(emulator.charset_state, :g3)
        new_emulator = %{emulator | charset_state: new_charset_state}
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # LS2R (Invoke G2 in GR)
      <<?~, rest_after::binary>> ->
        new_charset_state = CharacterSets.set_gr(emulator.charset_state, :g2)
        new_emulator = %{emulator | charset_state: new_charset_state}
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # LS3R (Invoke G3 in GR)
      <<?}, rest_after::binary>> ->
        new_charset_state = CharacterSets.set_gr(emulator.charset_state, :g3)
        new_emulator = %{emulator | charset_state: new_charset_state}
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # RIS
      <<?c, rest_after::binary>> ->
        # Call back to Emulator
        new_emulator = ControlCodes.handle_ris(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # IND
      <<?D, rest_after::binary>> ->
        # Call back to Emulator
        new_emulator = ControlCodes.handle_ind(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # NEL
      <<?E, rest_after::binary>> ->
        # Call back to Emulator
        new_emulator = ControlCodes.handle_nel(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # HTS
      <<?H, rest_after::binary>> ->
        # Call back to Emulator
        new_emulator = ControlCodes.handle_hts(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # RI
      <<?M, rest_after::binary>> ->
        # Call back to Emulator
        new_emulator = ControlCodes.handle_ri(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # DECSC
      <<?7, rest_after::binary>> ->
        # Call back to Emulator
        new_emulator = ControlCodes.handle_decsc(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # DECRC
      <<?8, rest_after::binary>> ->
        # Call back to Emulator
        new_emulator = ControlCodes.handle_decrc(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, new_emulator, next_parser_state, rest_after}

      # Fallback for unhandled char after ESC
      <<char_codepoint, rest_after_char::binary>> ->
        Logger.debug(
          "[Parser] Unhandled char #{inspect(char_codepoint)} after ESC, returning to ground."
        )

        next_parser_state = %{parser_state | state: :ground}
        # Effectively ignore the char and go back to ground with the rest
        {:continue, emulator, next_parser_state, rest_after_char}
    end
  end
end
