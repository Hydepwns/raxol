defmodule Raxol.Terminal.Parser.States.EscapeState do
  @moduledoc """
  Handles the :escape state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State

  @behaviour Raxol.Terminal.Parser.StateBehaviour

  @impl Raxol.Terminal.Parser.StateBehaviour

  @doc """
  Handles input when the parser is in the Escape state.
  ESC C: RIS (Reset to Initial State)
  ESC D: IND (Index)
  ESC E: NEL (Next Line)
  ESC H: HTS (Horizontal Tabulation Set)
  ESC M: RI (Reverse Index)
  ESC N: SS2 (Single Shift Two)
  ESC O: SS3 (Single Shift Three)
  ESC P: DCS (Device Control String)
  ESC Z: DECID (Return Terminal ID)
  ESC [: CSI (Control Sequence Introducer)
  ESC ]: OSC (Operating System Command)
  ESC ^: PM (Privacy Message)
  ESC _: APC (Application Program Command)
  ESC (: Designate G0 Character Set
  ESC ): Designate G1 Character Set
  ESC *: Designate G2 Character Set
  ESC +: Designate G3 Character Set
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:finished, Emulator.t(), State.t()}
          | {:incomplete, Emulator.t(), State.t()}
  def handle(emulator, %State{state: :escape} = parser_state, input) do
    case input do
      # Incomplete sequence
      <<>> ->
        {:incomplete, emulator, parser_state}

      # CSI (Control Sequence Introducer)
      # Moves to CSI_ENTRY state
      <<91, rest_after_csi::binary>> ->
        # Clear buffers for the new sequence
        next_parser_state = %{
          parser_state
          | state: :csi_entry,
            params_buffer: "",
            intermediates_buffer: ""
        }

        {:continue, emulator, next_parser_state, rest_after_csi}

      # OSC (Operating System Command)
      # Moves to OSC_STRING state
      <<93, rest_after_osc::binary>> ->
        next_parser_state = %{
          parser_state
          | state: :osc_string,
            payload_buffer: ""
        }

        {:continue, emulator, next_parser_state, rest_after_osc}

      # DCS (Device Control String)
      # Moves to DCS_INTRO state
      <<80, rest_after_dcs::binary>> ->
        next_parser_state = %{
          parser_state
          | state: :dcs_intro,
            params_buffer: "",
            intermediates_buffer: "",
            payload_buffer: ""
        }

        {:continue, emulator, next_parser_state, rest_after_dcs}

      # Character set designation G0-G3
      <<?(, char, rest::binary>> ->
        updated_emulator = Emulator.designate_charset(emulator, :g0, char)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, updated_emulator, next_parser_state, rest}

      <<?), char, rest::binary>> ->
        updated_emulator = Emulator.designate_charset(emulator, :g1, char)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, updated_emulator, next_parser_state, rest}

      <<?*, char, rest::binary>> ->
        updated_emulator = Emulator.designate_charset(emulator, :g2, char)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, updated_emulator, next_parser_state, rest}

      <<?+, char, rest::binary>> ->
        updated_emulator = Emulator.designate_charset(emulator, :g3, char)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, updated_emulator, next_parser_state, rest}

      # Other escape sequences
      # RIS - Reset to Initial State
      <<?c, rest::binary>> ->
        updated_emulator = Emulator.reset_to_initial_state(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, updated_emulator, next_parser_state, rest}

      # IND - Index
      <<?D, rest::binary>> ->
        updated_emulator = Emulator.index(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, updated_emulator, next_parser_state, rest}

      # NEL - Next Line
      <<?E, rest::binary>> ->
        updated_emulator = Emulator.next_line(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, updated_emulator, next_parser_state, rest}

      # HTS - Horizontal Tabulation Set
      <<?H, rest::binary>> ->
        updated_emulator = Emulator.set_horizontal_tab(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, updated_emulator, next_parser_state, rest}

      # RI - Reverse Index
      <<?M, rest::binary>> ->
        updated_emulator = Emulator.reverse_index(emulator)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, updated_emulator, next_parser_state, rest}

      # SS2 - Single Shift Two
      <<?N, rest::binary>> ->
        # TODO: Implement SS2 logic if needed
        # This might involve setting a temporary charset for the next char
        next_parser_state = %{parser_state | state: :ground, single_shift: :g2}
        {:continue, emulator, next_parser_state, rest}

      # SS3 - Single Shift Three
      <<?O, rest::binary>> ->
        # TODO: Implement SS3 logic if needed
        next_parser_state = %{parser_state | state: :ground, single_shift: :g3}
        {:continue, emulator, next_parser_state, rest}

      # DECID - Return Terminal ID (DEC private)
      <<?Z, rest::binary>> ->
        # Example: Sending back primary device attributes "\e[?6c"
        # A common response for VT102
        output = "\e[?6c"
        updated_emulator = Emulator.enqueue_output(emulator, output)
        next_parser_state = %{parser_state | state: :ground}
        {:continue, updated_emulator, next_parser_state, rest}

      # PM - Privacy Message, APC - Application Program Command
      # Typically, these just transition to ground state after consuming their respective introducers
      # The actual content of PM, APC might be handled by dedicated states if complex, or ignored.
      # PM (Privacy Message) - Often ignored or handled simply
      <<?^, _rest::binary>> ->
        # For now, transition to ground. A real PM parser would go to a PM_STRING state.
        next_parser_state = %{parser_state | state: :ground}
        # TODO: decide if we consume one char or go to a dedicated state
        # For now, consume the first char of rest for simplicity if it's part of PM content.
        # Or, if PM is like OSC/DCS, it would have a delimiter or a fixed length.
        # Let's assume it's just an indicator and we go back to ground.
        # The actual rest of the PM string would be parsed in ground state if not specially handled.
        {:continue, emulator, next_parser_state, input}

      # APC (Application Program Command) - Similar to PM
      <<?_, _rest::binary>> ->
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, input}

      # Unhandled escape sequence character - Execute C0/C1 and transition to ground
      # This is a fallback for any byte following ESC that isn't part of a recognized sequence.
      # The VT500 manual, for example, says that an ESC followed by a C0 or C1 control character
      # (other than CAN, SUB, ESC which are special) has no effect and the C0/C1 character is ignored.
      # For other characters, it's often an error or undefined behavior.
      # A robust approach might be to execute the character if it's a C0/C1 control,
      # or simply transition to ground state, effectively ignoring the ESC.
      <<char_val, rest::binary>> ->
        # Check if char_val is a C0 or C1 control character (excluding ESC, CAN, SUB)
        # This is a simplification. A full implementation would check ranges.
        if char_val in [0..31, 128..159] and char_val not in [24, 26, 27] do
          # Execute the control character (this might involve calling a handler)
          # For now, let's assume most are handled by Emulator.execute_control_character or similar
          # or simply ignored if not directly actionable.
          # Transitioning to ground state is a safe default.
          updated_emulator =
            Raxol.Terminal.ControlCodes.handle_c0(emulator, char_val)

          next_parser_state = %{parser_state | state: :ground}
          {:continue, updated_emulator, next_parser_state, rest}
        else
          # If not a recognized control or part of another sequence, treat as an error or ignore.
          # Transition to ground state is a common recovery mechanism.
          # Optionally log an error or unexpected sequence.
          # For now, just go to ground state.
          next_parser_state = %{parser_state | state: :ground}
          {:continue, emulator, next_parser_state, rest}
        end
    end
  end
end
