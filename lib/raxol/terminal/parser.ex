defmodule Raxol.Terminal.Parser do
  @moduledoc """
  Parses raw byte streams into terminal events and commands.
  Handles escape sequences (CSI, OSC, DCS, etc.) and plain text.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.States.GroundState
  alias Raxol.Terminal.Parser.States.EscapeState
  alias Raxol.Terminal.Parser.States.DesignateCharsetState
  alias Raxol.Terminal.Parser.States.CSIEntryState
  alias Raxol.Terminal.Parser.States.CSIParamState
  alias Raxol.Terminal.Parser.States.CSIIntermediateState
  alias Raxol.Terminal.Parser.States.OSCStringState
  alias Raxol.Terminal.Parser.States.OSCStringMaybeSTState
  alias Raxol.Terminal.Parser.States.DCSEntryState
  alias Raxol.Terminal.Parser.States.DCSPassthroughState
  alias Raxol.Terminal.Parser.States.DCSPassthroughMaybeSTState
  require Raxol.Core.Runtime.Log

  # --- Public API ---

  @doc """
  Parses a chunk of input data, updating the parser state and emulator.

  Takes the current emulator state and input binary, returns the updated emulator state
  after processing the input chunk.

  Takes the emulator state, the *current* parser state, and the input binary.
  Returns `{final_emulator_state, final_parser_state}`.
  """
  @spec parse_chunk(Emulator.t(), Raxol.Terminal.Parser.State.t(), String.t()) ::
          {Emulator.t(), Raxol.Terminal.Parser.State.t(), String.t()}
  def parse_chunk(emulator, nil, data) do
    parse_chunk(emulator, %Raxol.Terminal.Parser.State{state: :ground}, data)
  end

  def parse_chunk(emulator, state, data) do
    Raxol.Core.Runtime.Log.debug(
      "[Parser.parse_chunk] Starting with state=#{inspect(state.state)}, data=#{inspect(data)}"
    )

    result = parse_loop(emulator, state, data)

    case result do
      {emu, state, rest} when is_map(emu) ->
        Raxol.Core.Runtime.Log.debug(
          "[Parser.parse_chunk] AFTER: emu.scroll_region=#{inspect(emu.scroll_region)}"
        )

        {emu, state, rest}

      unexpected_result ->
        Raxol.Core.Runtime.Log.error(
          "[Parser.parse_chunk] Unexpected result from parse_loop: #{inspect(unexpected_result)}"
        )

        # Return a safe fallback
        {emulator, state, data}
    end
  end

  def parse(emulator, input) do
    initial_parser_state = %Raxol.Terminal.Parser.State{}
    result = parse_loop(emulator, initial_parser_state, input)
    result
  end

  # --- Internal Parsing State Machine (Renamed do_parse_chunk -> parse_loop) ---

  # Base case: End of input
  # Accepts emulator, parser_state, and empty input
  defp parse_loop(emulator, parser_state, "") do
    IO.puts("DEBUG: parse_loop - empty input, returning final state")

    # Return the final emulator, the parser state it ended in, and empty remaining input.
    {emulator, parser_state, ""}
  end

  # --- Ground State ---
  # Delegates to GroundState handler
  defp parse_loop(
         emulator,
         %Raxol.Terminal.Parser.State{state: :ground} = parser_state,
         input
       ) do
    IO.puts(
      "DEBUG: parse_loop - ground state with input: #{inspect(input)}, parser_state: #{inspect(parser_state)}"
    )

    case GroundState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        IO.puts(
          "DEBUG: parse_loop - ground state continuing with next_input: #{inspect(next_input)}, next_parser_state: #{inspect(next_parser_state)}"
        )

        parse_loop(next_emulator, next_parser_state, next_input)

      other ->
        IO.puts(
          "DEBUG: parse_loop - ground state received unexpected value: #{inspect(other)}"
        )

        other
    end
  end

  # --- Escape State ---
  # Delegates to EscapeState handler
  defp parse_loop(
         emulator,
         %Raxol.Terminal.Parser.State{state: :escape} = parser_state,
         input
       ) do
    IO.puts("DEBUG: parse_loop - escape state with input: #{inspect(input)}")

    case EscapeState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state, input}
    end
  end

  # --- Designate Charset State ---
  # Delegates to DesignateCharsetState handler
  defp parse_loop(
         emulator,
         %Raxol.Terminal.Parser.State{state: :designate_charset} = parser_state,
         input
       ) do
    IO.puts(
      "DEBUG: parse_loop - designate_charset state with input: #{inspect(input)}"
    )

    case DesignateCharsetState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state, input}
    end
  end

  # --- CSI Entry State ---
  # Delegates to CSIEntryState handler
  defp parse_loop(
         emulator,
         %Raxol.Terminal.Parser.State{state: :csi_entry} = parser_state,
         input
       ) do
    IO.puts("DEBUG: parse_loop - csi_entry state with input: #{inspect(input)}")

    case CSIEntryState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state, input}
    end
  end

  # --- CSI Param State ---
  # Delegates to CSIParamState handler
  defp parse_loop(
         emulator,
         %Raxol.Terminal.Parser.State{state: :csi_param} = parser_state,
         input
       ) do
    IO.puts("DEBUG: parse_loop - csi_param state with input: #{inspect(input)}")

    case CSIParamState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state, input}
    end
  end

  # --- CSI Intermediate State ---
  # Delegates to CSIIntermediateState handler
  defp parse_loop(
         emulator,
         %Raxol.Terminal.Parser.State{state: :csi_intermediate} = parser_state,
         input
       ) do
    IO.puts(
      "DEBUG: parse_loop - csi_intermediate state with input: #{inspect(input)}"
    )

    case CSIIntermediateState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state, input}
    end
  end

  # --- OSC String State ---
  # Delegates to OSCStringState handler
  defp parse_loop(
         emulator,
         %Raxol.Terminal.Parser.State{state: :osc_string} = parser_state,
         input
       ) do
    IO.puts(
      "DEBUG: parse_loop - osc_string state with input: #{inspect(input)}"
    )

    case OSCStringState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state, input}
    end
  end

  # Helper state to check for ST after ESC in OSC String
  # Delegates to OSCStringMaybeSTState handler
  defp parse_loop(
         emulator,
         %Raxol.Terminal.Parser.State{state: :osc_string_maybe_st} =
           parser_state,
         input
       ) do
    IO.puts(
      "DEBUG: parse_loop - osc_string_maybe_st state with input: #{inspect(input)}"
    )

    case OSCStringMaybeSTState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)
    end
  end

  # --- DCS Entry State ---
  # Delegates to DCSEntryState handler
  defp parse_loop(
         emulator,
         %Raxol.Terminal.Parser.State{state: :dcs_entry} = parser_state,
         input
       ) do
    IO.puts("DEBUG: parse_loop - dcs_entry state with input: #{inspect(input)}")

    case DCSEntryState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state, input}
    end
  end

  # --- DCS Passthrough State ---
  # Delegates to DCSPassthroughState handler
  defp parse_loop(
         emulator,
         %Raxol.Terminal.Parser.State{state: :dcs_passthrough} = parser_state,
         input
       ) do
    IO.puts(
      "DEBUG: parse_loop - dcs_passthrough state with input: #{inspect(input)}"
    )

    case DCSPassthroughState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state, input}
    end
  end

  # --- DCS Passthrough Maybe ST State ---
  # Delegates to DCSPassthroughMaybeSTState handler
  defp parse_loop(
         emulator,
         %Raxol.Terminal.Parser.State{state: :dcs_passthrough_maybe_st} =
           parser_state,
         input
       ) do
    IO.puts(
      "DEBUG: parse_loop - dcs_passthrough_maybe_st state with input: #{inspect(input)}"
    )

    case DCSPassthroughMaybeSTState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)
    end
  end

  # --- CATCH-ALL CLAUSE FOR UNHANDLED STATES ---
  defp parse_loop(emulator, parser_state, input) do
    IO.puts(
      "DEBUG: parse_loop - unhandled state: #{inspect(parser_state.state)} with input: #{inspect(input)}"
    )

    msg =
      "[parse_loop] Unhandled parser state: #{inspect(parser_state)} with input: #{inspect(input)}"

    Raxol.Core.Runtime.Log.warning(msg)
    # Ensure 3-tuple, pass input through
    {emulator, parser_state, input}
  end

  def transition_to_escape(emulator, rest_after_esc) do
    new_parser_state = %Raxol.Terminal.Parser.State{state: :escape}
    {emulator, new_parser_state, rest_after_esc}
  end

  def transition_to_ground(emulator) do
    new_parser_state = %Raxol.Terminal.Parser.State{state: :ground}
    {emulator, new_parser_state, ""}
  end

  # In parse_loop/3, add a log when executing a CSI command (look for ?r)
  # defp parse_loop(emulator, parser_state, <<27, 91, rest::binary>>) do
  #   Raxol.Core.Runtime.Log.debug("[Parser.parse_loop] CSI detected in input: #{inspect(rest)}")
  #   # CSI handling should be delegated to the appropriate state handler or removed if not needed
  #   {emulator, parser_state}
  # end
end
