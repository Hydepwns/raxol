defmodule Raxol.Terminal.Parser.States.DesignateCharsetState do
  @moduledoc """
  Handles the :designate_charset state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  alias Raxol.Terminal.ANSI.CharacterSets
  require Logger

  @doc """
  Processes input when the parser is in the :designate_charset state.
  Expects a single character designating the character set.
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:finished, Emulator.t(), State.t()}
          | {:incomplete, Emulator.t(), State.t()}
  def handle(
        emulator,
        %State{state: :designate_charset, designating_gset: gset} =
          parser_state,
        input
      ) do
    # IO.inspect({:parse_loop_designate, parser_state.state, input}, label: "DEBUG_PARSER")
    case input do
      # Incomplete
      <<>> ->
        # Incomplete designate sequence - return current state
        {:incomplete, emulator, parser_state}

      <<charset_code, rest_after_code::binary>> ->
        # Call CharacterSets module to update the state
        new_charset_state =
          CharacterSets.designate_charset(
            emulator.charset_state,
            gset,
            charset_code
          )

        # Update the emulator state
        new_emulator = %{emulator | charset_state: new_charset_state}

        # IO.inspect({:designate_charset_handle_return, new_emulator.charset_state}, label: "DEBUG")
        # IO.inspect(new_emulator.charset_state, label: "[DesignateCharsetState] Returning charset_state:")

        # Transition back to ground state
        next_parser_state = %{
          parser_state
          | state: :ground,
            designating_gset: nil
        }

        # --- ADDED DEBUG ---
        IO.inspect(
          {:designate_handle_return, gset, charset_code,
           new_emulator.charset_state},
          label: "DESIGNATE_DEBUG"
        )

        # --- END DEBUG ---

        {:continue, new_emulator, next_parser_state, rest_after_code}
    end
  end
end
