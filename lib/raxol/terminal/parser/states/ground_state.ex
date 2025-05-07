defmodule Raxol.Terminal.Parser.States.GroundState do
  @moduledoc """
  Handles the :ground state of the terminal parser.
  Processes plain text and transitions to other states on control codes/escape sequences.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.InputHandler
  alias Raxol.Terminal.Parser.State
  alias Raxol.Terminal.ControlCodes
  require Logger

  @doc """
  Processes input when the parser is in the :ground state.

  Returns:
    - `{:continue, new_emulator, next_parser_state, remaining_input}` to continue parsing.
    - `{:handled, final_emulator}` if the input is fully processed or an error occurs.
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()} | {:handled, Emulator.t()}
  def handle(emulator, %State{state: :ground} = parser_state, input) do
    # --- REMOVED DEBUG ---
    # IO.inspect({:ground_state_entry, input}, label: "GROUND_STATE_ENTRY_DEBUG")
    # --- END DEBUG ---
    case input do
      # ESC
      <<27, rest_after_esc::binary>> ->
        # Transition to escape state
        next_parser_state = %{parser_state | state: :escape}
        # --- REMOVED DEBUG ---
        # IO.inspect({:ground_state_esc_clause_return, next_parser_state.state}, label: "GROUND_ESC_DEBUG")
        # --- END DEBUG ---
        {:continue, emulator, next_parser_state, rest_after_esc}

      # LF (C0 Code)
      <<10, rest_after_lf::binary>> ->
        # Command History Logic
        trimmed_command = String.trim(emulator.current_command_buffer)
        updated_history =
          if trimmed_command != "" do
            [trimmed_command | emulator.command_history]
            |> Enum.take(emulator.max_command_history)
          else
            emulator.command_history
          end

        emulator_with_history = %{
          emulator
          | command_history: updated_history,
            current_command_buffer: ""
        }
        # End Command History Logic

        new_emulator = ControlCodes.handle_c0(emulator_with_history, 10)
        {:continue, new_emulator, parser_state, rest_after_lf}

      # CR (C0 Code)
      <<13, rest_after_cr::binary>> ->
        # For CR, we might also consider it as command input submission,
        # or let LF be the sole trigger. For now, let's assume LF is the main trigger
        # and CR just does its usual control code action.
        # If CR should also submit commands, the LF logic would be duplicated here.
        new_emulator = ControlCodes.handle_c0(emulator, 13)
        {:continue, new_emulator, parser_state, rest_after_cr}

      # Other C0 Codes (0-31 excluding ESC, LF, CR)
      <<control_code, rest_after_control::binary>>
      when control_code >= 0 and control_code <= 31 and control_code != 27 ->
        new_emulator = ControlCodes.handle_c0(emulator, control_code)
        {:continue, new_emulator, parser_state, rest_after_control}

      # Printable character
      <<char_codepoint::utf8, rest_after_char::binary>>
      when char_codepoint >= 32 ->
        # Command History Logic
        char_as_string = <<char_codepoint::utf8>>
        updated_command_buffer = emulator.current_command_buffer <> char_as_string
        emulator_with_buffer = %{emulator | current_command_buffer: updated_command_buffer}
        # End Command History Logic

        # Call InputHandler instead of non-existent Emulator.write
        new_emulator = InputHandler.process_printable_character(emulator_with_buffer, char_codepoint)
        {:continue, new_emulator, parser_state, rest_after_char}

      # Fallback for invalid UTF-8 or other unhandled bytes
      <<byte, rest::binary>> ->
        Logger.warning(
          "[Parser] Unhandled/Ignored byte #{inspect(byte)} in ground state. Skipping."
        )
        {:continue, emulator, parser_state, rest}

      # Base case: Empty input (should be handled by main loop, but good to have)
      <<>> ->
         {:continue, emulator, parser_state, <<>>}

    end
  end

  # Accepts emulator, parser_state, and empty input
  # defp parse_loop(emulator, parser_state, "") do # Remove this unused function
  #   if parser_state.state != :ground do
  #     Logger.debug("Input ended while in parser state: #{parser_state.state}")
  #   end
  #
  #   {:handled, emulator}
  # end
end
