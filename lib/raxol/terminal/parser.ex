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
  Parses a chunk of input data, updating the parser state and emulator.

  Takes the current emulator state and input binary, returns the updated emulator state
  after processing the input chunk.

  Takes the emulator state, the *current* parser state, and the input binary.
  Returns `{final_emulator_state, final_parser_state}`.
  """
  @spec parse_chunk(Emulator.t(), State.t(), String.t()) ::
          {Emulator.t(), State.t(), String.t()}
  def parse_chunk(emulator, state, data) do
    # IO.inspect(emulator.main_screen_buffer, limit: :infinity, label: "PARSER_CHUNK_ENTRY: main_screen_buffer")

    # IO.inspect(state, label: "PARSER_CHUNK_ENTRY: state")
    # IO.inspect(data, label: "PARSER_CHUNK_ENTRY: data")
    parse_loop(emulator, state, data)
  end

  def parse(emulator, input) do
    initial_parser_state = %State{}
    result = parse_loop(emulator, initial_parser_state, input)
    result
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
        # --- REMOVED DEBUG ---
        # IO.inspect({:parse_loop_ground_return, next_parser_state.state}, label: "PARSE_LOOP_GROUND_DEBUG")
        # --- END DEBUG ---
        parse_loop(next_emulator, next_parser_state, next_input)
    end
  end

  # --- Escape State ---
  # Delegates to EscapeState handler
  defp parse_loop(
         emulator,
         %State{state: :escape} = parser_state,
         input
       ) do
    # --- REMOVED DEBUG ---
    # IO.inspect({:parse_loop_escape_entry, parser_state.state, input}, label: "PARSE_LOOP_DEBUG")
    # --- END DEBUG ---
    case EscapeState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      # Add case for incomplete
      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}

        # Escape state might return finished after handling a non-transitioning sequence
        # Clause removed as compiler indicates it's unreachable
        # {:finished, final_emulator, final_parser_state} ->
        #   {final_emulator, final_parser_state}
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
        # --- REMOVED DEBUG ---
        # IO.inspect({:parse_loop_after_designate, next_emulator.charset_state}, label: "DESIGNATE_DEBUG")
        # --- END DEBUG ---
        parse_loop(next_emulator, next_parser_state, next_input)

      # Add case for incomplete
      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
        # Previous version had {:handled, emu, state} - ensure that's covered
        # Assuming handle now returns :finished if it used to return :handled
        # Clause removed as compiler indicates it's unreachable
        # {:finished, final_emulator, final_parser_state} ->
        #   {final_emulator, final_parser_state}
    end
  end

  # --- CSI Entry State ---
  # Delegates to CSIEntryState handler
  defp parse_loop(
         emulator,
         %State{state: :csi_entry} = parser_state,
         input
       ) do
    IO.inspect(emulator.main_screen_buffer,
      label: "PRE_CSI_ENTRY_HANDLE: main_screen_buffer"
    )

    case CSIEntryState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        IO.inspect(next_emulator.main_screen_buffer,
          label: "POST_CSI_ENTRY_HANDLE (continue): main_screen_buffer"
        )

        parse_loop(next_emulator, next_parser_state, next_input)

      # Add case for incomplete
      {:incomplete, final_emulator, final_parser_state} ->
        IO.inspect(final_emulator.main_screen_buffer,
          label: "POST_CSI_ENTRY_HANDLE (incomplete): main_screen_buffer"
        )

        {final_emulator, final_parser_state}
        # Previous version had {:handled, emu, state} - ensure that's covered
        # Assuming handle now returns :finished if it used to return :handled
        # Clause removed as compiler indicates it's unreachable
        # {:finished, final_emulator, final_parser_state} ->
        #   {final_emulator, final_parser_state}
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

      # Clause removed as compiler indicates it's unreachable
      # {:finished, final_emulator, final_parser_state} ->
      #   {final_emulator, final_parser_state}
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
    IO.inspect(emulator.main_screen_buffer,
      label: "PRE_CSI_INTERMEDIATE_HANDLE: main_screen_buffer"
    )

    case CSIIntermediateState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        IO.inspect(next_emulator.main_screen_buffer,
          label: "POST_CSI_INTERMEDIATE_HANDLE (continue): main_screen_buffer"
        )

        parse_loop(next_emulator, next_parser_state, next_input)

      # Clause removed as compiler indicates it's unreachable
      # {:finished, final_emulator, final_parser_state} ->
      #   {final_emulator, final_parser_state}
      {:incomplete, final_emulator, final_parser_state} ->
        IO.inspect(final_emulator.main_screen_buffer,
          label: "POST_CSI_INTERMEDIATE_HANDLE (incomplete): main_screen_buffer"
        )

        {final_emulator, final_parser_state}
    end
  end

  # --- OSC String State ---
  # Delegates to OSCStringState handler
  defp parse_loop(emulator, %State{state: :osc_string} = parser_state, input) do
    case OSCStringState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

      # Clause removed as compiler indicates it's unreachable
      # {:finished, final_emulator, final_parser_state} ->
      #   {final_emulator, final_parser_state}
      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
    end
  end

  # Helper state to check for ST after ESC in OSC String
  # Delegates to OSCStringMaybeSTState handler
  defp parse_loop(
         emulator,
         %State{state: :osc_string_maybe_st} = parser_state,
         input
       ) do
    case OSCStringMaybeSTState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)
        # Clauses removed as compiler indicates they are unreachable
        # {:finished, final_emulator, final_parser_state} ->
        #   {final_emulator, final_parser_state}
        # {:incomplete, final_emulator, final_parser_state} ->
        #   {final_emulator, final_parser_state}
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

      # Clause removed as compiler indicates it's unreachable
      # {:finished, final_emulator, final_parser_state} ->
      #   {final_emulator, final_parser_state}
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

      # Clause removed as compiler indicates it's unreachable
      # {:finished, final_emulator, final_parser_state} ->
      #   {final_emulator, final_parser_state}
      {:incomplete, final_emulator, final_parser_state} ->
        {final_emulator, final_parser_state}
    end
  end

  # --- DCS Passthrough Maybe ST State ---
  # Delegates to DCSPassthroughMaybeSTState handler
  defp parse_loop(
         emulator,
         %State{state: :dcs_passthrough_maybe_st} = parser_state,
         input
       ) do
    case DCSPassthroughMaybeSTState.handle(emulator, parser_state, input) do
      {:continue, next_emulator, next_parser_state, next_input} ->
        parse_loop(next_emulator, next_parser_state, next_input)

        # Clauses removed as compiler indicates they are unreachable
        # {:finished, final_emulator, final_parser_state} ->
        #   {final_emulator, final_parser_state}
        # {:incomplete, final_emulator, final_parser_state} ->
        #   {final_emulator, final_parser_state}
    end
  end
end
