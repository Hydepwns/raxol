defmodule Raxol.Terminal.Parser.States.GroundState do
  @moduledoc """
  Handles the :ground state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
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
    case input do
      # Base case: Empty input handled by main loop

      # ESC
      <<27, rest_after_esc::binary>> ->
        # Update parser state: change state atom, reset buffers
        next_parser_state = %State{
          parser_state
          | state: :escape,
            params_buffer: "",
            payload_buffer: "",
            intermediates_buffer: ""
        }

        {:continue, emulator, next_parser_state, rest_after_esc}

      # LF
      <<10, rest_after_lf::binary>> ->
        # Call back to Emulator
        new_emulator = Emulator.handle_lf(emulator)
        # Continue with same parser state
        {:continue, new_emulator, parser_state, rest_after_lf}

      # CR
      <<13, rest_after_cr::binary>> ->
        # Call back to Emulator
        new_emulator = Emulator.handle_cr(emulator)
        # Continue with same parser state
        {:continue, new_emulator, parser_state, rest_after_cr}

      # Printable character
      <<char_codepoint::utf8, rest_after_char::binary>>
      when char_codepoint >= 32 ->
        # Call back to Emulator
        new_emulator = Emulator.process_character(emulator, char_codepoint)
        # Continue with same parser state
        {:continue, new_emulator, parser_state, rest_after_char}

      # Fallback for other C0 or invalid UTF-8
      <<byte, rest::binary>> ->
        if byte >= 0 and byte <= 31 and byte != 10 and byte != 13 do
          # Call back to Emulator for C0
          new_emulator = Emulator.process_character(emulator, byte)
          {:continue, new_emulator, parser_state, rest}
        else
          Logger.warning(
            "[Parser] Unhandled/Ignored byte #{inspect(byte)} in ground state. Skipping."
          )

          {:continue, emulator, parser_state, rest}
        end

      # Empty input (should be caught by main loop, but handle defensively)
      "" ->
        {:handled, emulator}
    end
  end
end
