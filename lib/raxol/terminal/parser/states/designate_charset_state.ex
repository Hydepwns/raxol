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
        %State{state: :designate_charset, designating_gset: gset} = parser_state,
        input
      ) do
    # IO.inspect({:parse_loop_designate, parser_state.state, input}, label: "DEBUG_PARSER")
    case input do
      # Incomplete
      <<>> ->
        # Incomplete designate sequence - return current state
        {:incomplete, emulator, parser_state}

      <<charset_code, rest_after_code::binary>> ->
        # Pass explicit gset and charset_code to Emulator
        new_charset_state =
          CharacterSets.designate_charset(
            emulator.charset_state,
            gset,
            charset_code
          )

        new_emulator = %{emulator | charset_state: new_charset_state}

        next_parser_state = %{
          parser_state
          | state: :ground,
            designating_gset: nil
        }

        {:continue, new_emulator, next_parser_state, rest_after_code}
    end
  end
end
