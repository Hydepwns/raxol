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
  require Logger

  # --- Define Internal Parser State ---
  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
          state: atom(),
          params_buffer: String.t(),
          intermediates_buffer: String.t(),
          payload_buffer: String.t(),
          final_byte: integer() | nil,
          designating_gset: non_neg_integer() | nil
        }
    defstruct state: :ground,
              # Raw params string buffer (e.g., "1;31")
              params_buffer: "",
              # Raw intermediates string buffer (e.g., "?")
              intermediates_buffer: "",
              # Buffer for OSC/DCS/etc. content
              payload_buffer: "",
              # Final byte collected for CSI/DCS sequence (before payload for DCS)
              final_byte: nil,
              # G-set being designated (0-3)
              designating_gset: nil
  end

  # --- Public API ---

  @doc """
  Parses a chunk of input using a state machine.

  Takes the current emulator state and input binary, returns the updated emulator state
  after processing the input chunk.

  Takes the emulator state, the *current* parser state, and the input binary.
  Returns `{final_emulator_state, final_parser_state}`.
  """
  @spec parse_chunk(Emulator.t(), State.t(), binary()) :: {Emulator.t(), State.t()}
  def parse_chunk(emulator, current_parser_state, input) when is_binary(input) do
    # Start the internal recursive parsing with the provided parser state
    parse_loop(emulator, current_parser_state, input)
  end

  # --- Internal Parsing State Machine (Renamed do_parse_chunk -> parse_loop) ---

  # Base case: End of input
  # Accepts emulator, parser_state, and empty input
  defp parse_loop(emulator, parser_state, "") do
    # Return the final emulator and the parser state it ended in.
    {emulator, parser_state}
  end

  # --- Ground State ---
  # Delegates to GroundState handler
  defp parse_loop(emulator, %State{state: :ground} = parser_state, input) do
    case GroundState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        # --- DEBUG LOG ---
        # IO.inspect({:parse_loop_ground_recurse, next_emulator.cursor.position}, label: "DEBUG")
        # --- END DEBUG LOG ---
        parse_loop(next_emulator, next_parser_state, next_input)
      # GroundState.handle only returns :continue, so no other cases needed here.
    end
  end

  # --- Escape State ---
  # Delegates to EscapeState handler
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         input
       ) do
    case EscapeState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      # Add case for incomplete
      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
      # Escape state might return finished after handling a non-transitioning sequence
      {:finished, final_emulator, final_parser_state} ->
         {final_emulator, final_parser_state}
    end
  end

  # --- Designate Charset State ---
  # Delegates to DesignateCharsetState handler
  defp parse_loop(
         emulator,
         %State{state: :designate_charset} = parser_state,
         input
       ) do
    case DesignateCharsetState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      # Add case for incomplete
      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
      # Previous version had {:handled, emu, state} - ensure that's covered
      # Assuming handle now returns :finished if it used to return :handled
      {:finished, final_emulator, final_parser_state} ->
         {final_emulator, final_parser_state}
    end
  end

  # --- CSI Entry State ---
  # Delegates to CSIEntryState handler
  defp parse_loop(
         emulator,
         %State{state: :csi_entry} = parser_state,
         input
       ) do
    case CSIEntryState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      # Add case for incomplete
      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
      # Previous version had {:handled, emu, state} - ensure that's covered
      # Assuming handle now returns :finished if it used to return :handled
      {:finished, final_emulator, final_parser_state} ->
         {final_emulator, final_parser_state}
    end
  end

  # --- CSI Param State ---
  # Delegates to CSIParamState handler
  defp parse_loop(
         emulator,
         %State{state: :csi_param} = parser_state,
         input
       ) do
    case CSIParamState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:finished, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
    end
  end

  # --- CSI Intermediate State ---
  # Delegates to CSIIntermediateState handler
  defp parse_loop(
         emulator,
         %State{state: :csi_intermediate} = parser_state,
         input
       ) do
    case CSIIntermediateState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:finished, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
    end
  end

  # --- OSC String State ---
  # Delegates to OSCStringState handler
  defp parse_loop(emulator, %State{state: :osc_string} = parser_state, input) do
    case OSCStringState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)
      {:finished, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
    end
  end

  # Helper state to check for ST after ESC in OSC String
  # Delegates to OSCStringMaybeSTState handler
  defp parse_loop(emulator, %State{state: :osc_string_maybe_st} = parser_state, input) do
    case OSCStringMaybeSTState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)
      {:finished, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
    end
  end

  # --- DCS Entry State ---
  # Delegates to DCSEntryState handler
  defp parse_loop(
         emulator,
         %State{state: :dcs_entry} = parser_state,
         input
       ) do
    case DCSEntryState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:finished, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
    end
  end

  # --- DCS Passthrough State ---
  # Delegates to DCSPassthroughState handler
  defp parse_loop(
         emulator,
         %State{state: :dcs_passthrough} = parser_state,
         input
       ) do
    case DCSPassthroughState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      {:finished, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
    end
  end

  # Helper state to check for ST after ESC in DCS Passthrough
  # Delegates to DCSPassthroughMaybeSTState handler
  defp parse_loop(emulator, %State{state: :dcs_passthrough_maybe_st} = parser_state, input) do
    case DCSPassthroughMaybeSTState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)
      {:finished, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
    end
  end
end
