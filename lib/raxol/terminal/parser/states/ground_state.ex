defmodule Raxol.Terminal.Parser.States.GroundState do
  @moduledoc '''
  Handles parsing in the ground state, the default state of the terminal.
  '''
  alias Raxol.Terminal.Commands.History
  alias Raxol.Terminal.InputHandler
  alias Raxol.Terminal.Parser
  require Raxol.Core.Runtime.Log

  @behaviour Raxol.Terminal.Parser.StateBehaviour

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle(emulator, parser_state, input) do
    handle_input(input, emulator, parser_state)
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_byte(byte, emulator, state) do
    case byte do
      # ESC (C0 Code)
      27 ->
        {:ok, emulator, %{state | state: :escape}}

      # Other bytes are handled by the main handle/3 function
      _ ->
        {:ok, emulator, state}
    end
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_escape(emulator, state) do
    {:ok, emulator, %{state | state: :escape}}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_control_sequence(emulator, state) do
    {:ok, emulator, %{state | state: :control_sequence}}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_osc_string(emulator, state) do
    {:ok, emulator, %{state | state: :osc_string}}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_dcs_string(emulator, state) do
    {:ok, emulator, %{state | state: :dcs_string}}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_apc_string(emulator, state) do
    {:ok, emulator, %{state | state: :apc_string}}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_pm_string(emulator, state) do
    {:ok, emulator, %{state | state: :pm_string}}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_sos_string(emulator, state) do
    {:ok, emulator, %{state | state: :sos_string}}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_unknown(emulator, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "GroundState received unknown command",
      %{emulator: emulator, state: state}
    )

    {:ok, emulator, state}
  end

  defp handle_input(data, emulator, parser_state) do
    Raxol.Core.Runtime.Log.debug(
      "GroundState handling input: #{inspect(data)}, current parser state: #{inspect(parser_state)}"
    )

    case data do
      # ESC (C0 Code) - Transition to EscapeState
      <<27, rest_after_esc::binary>> ->
        Raxol.Core.Runtime.Log.debug(
          "GroundState: ESC detected, transitioning to EscapeState."
        )

        {new_emulator, new_parser_state, new_rest_input} =
          Parser.transition_to_escape(emulator, rest_after_esc)

        {:continue, new_emulator, new_parser_state, new_rest_input}

      # LF (C0 Code)
      <<10, rest_after_lf::binary>> ->
        # Handle LF: move cursor down or scroll if at bottom
        # Start Command History Logic
        emulator_with_history = History.maybe_add_to_history(emulator, 10)
        # End Command History Logic

        new_emulator =
          Raxol.Terminal.ControlCodes.handle_c0(emulator_with_history, 10)

        {:continue, new_emulator, parser_state, rest_after_lf}

      # CR (C0 Code)
      <<13, rest_after_cr::binary>> ->
        # Handle CR: move cursor to beginning of line
        new_emulator = Raxol.Terminal.ControlCodes.handle_c0(emulator, 13)
        {:continue, new_emulator, parser_state, rest_after_cr}

      # Other C0 Codes (0-31 excluding ESC, LF, CR)
      <<control_code, rest_after_control::binary>>
      when control_code >= 0 and control_code <= 31 and control_code != 27 ->
        new_emulator =
          Raxol.Terminal.ControlCodes.handle_c0(emulator, control_code)

        {:continue, new_emulator, parser_state, rest_after_control}

      # SS2 (C1 Control, 0x8E)
      <<142, rest_after_ss2::binary>> ->
        Raxol.Core.Runtime.Log.info(
          "[Parser] SS2 (C1, 0x8E) received - will use G2 for next char only"
        )

        {:continue, emulator, %{parser_state | single_shift: :ss2},
         rest_after_ss2}

      # SS3 (C1 Control, 0x8F)
      <<143, rest_after_ss3::binary>> ->
        Raxol.Core.Runtime.Log.info(
          "[Parser] SS3 (C1, 0x8F) received - will use G3 for next char only"
        )

        {:continue, emulator, %{parser_state | single_shift: :ss3},
         rest_after_ss3}

      # Printable character (UTF-8)
      <<char_codepoint::utf8, rest::binary>> ->
        # Process printable character
        # Start Command History Logic
        emulator_with_history =
          History.maybe_add_to_history(emulator, char_codepoint)

        # End Command History Logic

        # If single_shift is set, pass it to InputHandler and clear it after
        {updated_emulator, _output_events} =
          InputHandler.handle_printable_character(
            emulator_with_history,
            char_codepoint,
            parser_state.params,
            parser_state.single_shift
          )

        # Clear single_shift after use
        next_parser_state = %{parser_state | single_shift: nil}
        {:continue, updated_emulator, next_parser_state, rest}

      # Empty data - no further processing needed
      <<>> ->
        {new_emulator, new_parser_state, new_rest_input} =
          Parser.transition_to_ground(emulator)

        {:continue, new_emulator, new_parser_state, new_rest_input}

      # Unhandled case
      other ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "GroundState unhandled input: #{inspect(other)} with emulator: #{inspect(emulator)}",
          %{}
        )

        {:error, :unhandled_input, emulator, parser_state}
    end
  end
end
