defmodule Raxol.Terminal.InputHandler do
  @moduledoc """
  Handles parsed terminal input events (printable characters, control codes, escape sequences)
  and updates the Emulator state accordingly.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Operations
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ModeManager
  alias Raxol.Terminal.Parser
  alias Raxol.System.Clipboard

  require Raxol.Core.Runtime.Log

  # TODO: Move handler functions here from Emulator module.

  @type t :: %__MODULE__{
          buffer: String.t(),
          cursor_position: non_neg_integer(),
          tab_completion: map(),
          tab_completion_index: non_neg_integer(),
          tab_completion_matches: list(String.t()),
          mode_manager: ModeManager.t()
        }

  defstruct [
    :buffer,
    :cursor_position,
    :tab_completion,
    :tab_completion_index,
    :tab_completion_matches,
    :mode_manager
  ]

  @doc """
  Creates a new input handler with default values.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      buffer: "",
      cursor_position: 0,
      tab_completion: %{},
      tab_completion_index: 0,
      tab_completion_matches: [],
      mode_manager: ModeManager.new()
    }
  end

  @doc """
  Handles clipboard paste operation.
  """
  @spec handle_paste(t()) :: {:ok, t()} | {:error, any()}
  def handle_paste(%__MODULE__{} = handler) do
    # Call Raxol.System.Clipboard.paste/0
    case Clipboard.paste() do
      {:ok, text} ->
        new_buffer = insert_text(handler.buffer, handler.cursor_position, text)
        new_position = handler.cursor_position + String.length(text)
        {:ok, %{handler | buffer: new_buffer, cursor_position: new_position}}

      {:error, reason} ->
        # Pass through error
        {:error, reason}
    end
  end

  @doc """
  Handles clipboard copy operation.
  (Currently copies the entire buffer)
  """
  @spec handle_copy(t()) :: {:ok, t()} | {:error, any()}
  def handle_copy(%__MODULE__{} = handler) do
    # Call Raxol.System.Clipboard.copy/1
    case Clipboard.copy(handler.buffer) do
      :ok ->
        # Return handler unchanged on success
        {:ok, handler}

      {:error, reason} ->
        # Pass through error
        {:error, reason}
    end
  end

  @doc """
  Handles clipboard cut operation.
  (Currently cuts the entire buffer)
  """
  @spec handle_cut(t()) :: {:ok, t()} | {:error, any()}
  def handle_cut(%__MODULE__{} = handler) do
    # Call Raxol.System.Clipboard.copy/1
    with :ok <- Clipboard.copy(handler.buffer),
         new_buffer = "",
         new_position = 0 do
      {:ok,
       %{
         handler
         | buffer: new_buffer,
           cursor_position: new_position
           # No clipboard state to update
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Inserts text at the specified position in the buffer.
  """
  @spec insert_text(String.t(), non_neg_integer(), String.t()) :: String.t()
  def insert_text(buffer, position, text) do
    before_text = String.slice(buffer, 0, position)
    after_text = String.slice(buffer, position..-1//1)
    before_text <> text <> after_text
  end

  @doc """
  Processes a raw input string for the terminal, parsing control sequences and printable characters.
  This function drives the terminal command parser.
  """
  @spec process_terminal_input(Emulator.t(), String.t()) ::
          {Emulator.t(), String.t()}
  def process_terminal_input(emulator, input) when is_binary(input) do
    current_parser_state = emulator.parser_state

    {parsed_emulator, parsed_parser_state, remaining_input_chunk} =
      Parser.parse_chunk(emulator, current_parser_state, input)

    unless remaining_input_chunk == "" do
      Raxol.Core.Runtime.Log.debug(
        "[InputHandler] Parser.parse_chunk returned remaining input: #{inspect(remaining_input_chunk)}"
      )
    end

    final_emulator_updated = %{
      parsed_emulator
      | parser_state: parsed_parser_state
    }

    output_to_send = final_emulator_updated.output_buffer

    final_emulator_state_no_output = %{
      final_emulator_updated
      | output_buffer: ""
    }

    {final_emulator_state_no_output, output_to_send}
  end

  # --- C0 and Printable Character Handling ---

  @doc """
  Processes a single character codepoint.
  Delegates to C0 handlers or printable character handlers.
  """
  @spec process_character(Emulator.t(), integer()) :: Emulator.t()
  def process_character(emulator, char_codepoint)
      when (char_codepoint >= 0 and char_codepoint <= 31) or
             char_codepoint == 127 do
    # Handle C0 Control Codes and DEL using the ControlCodes module
    # ControlCodes functions should now take InputHandler as the first arg if they need
    # to call back for further processing, or just return the updated emulator state.
    # Assuming ControlCodes.handle_c0 returns the updated emulator state directly.
    Raxol.Terminal.ControlCodes.handle_c0(emulator, char_codepoint)
  end

  def process_character(emulator, char_codepoint) do
    # It's a printable character
    process_printable_character(emulator, char_codepoint)
  end

  @doc """
  Processes a single printable character codepoint.
  Handles writing the character to the buffer, cursor advancement, and line wrapping.
  """
  @spec process_printable_character(Emulator.t(), integer()) :: Emulator.t()
  def process_printable_character(emulator, char_codepoint) do
    # Get current active buffer dimensions once
    active_buffer = Emulator.get_active_buffer(emulator)
    buffer_width = ScreenBuffer.get_width(active_buffer)
    buffer_height = ScreenBuffer.get_height(active_buffer)

    # Translate character based on current charset state
    translated_char =
      CharacterSets.translate_char(char_codepoint, emulator.charset_state)

    new_charset_state = emulator.charset_state

    unless is_binary(translated_char) do
      Raxol.Core.Runtime.Log.error(
        "Expected translated_char to be a string, got: #{inspect(translated_char)}"
      )
    end

    # Pass the integer codepoint to get_char_width
    char_width = Raxol.Terminal.CharacterHandling.get_char_width(char_codepoint)

    # Check if auto wrap mode (DECAWM) is enabled
    auto_wrap_mode = ModeManager.mode_enabled?(emulator.mode_manager, :decawm)

    {current_cursor_x, current_cursor_y} =
      Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    # --- Calculate Write Position & Next Cursor Position ---
    {write_x, write_y, next_cursor_x, next_cursor_y, next_last_col_exceeded} =
      calculate_write_and_cursor_position(
        current_cursor_x,
        current_cursor_y,
        buffer_width,
        char_width,
        emulator.last_col_exceeded,
        auto_wrap_mode
      )

    # --- Write Character ---
    emulator_after_write =
      if write_y < buffer_height do
        # Use Operations module for buffer modifications
        Raxol.Core.Runtime.Log.debug(
          "[InputHandler] Writing char codepoint '#{translated_char}' with style: #{inspect(emulator.style)}"
        )

        # Convert codepoint back to binary for writing
        char_to_write = translated_char

        # Get the active buffer for writing
        buffer_for_write = Emulator.get_active_buffer(emulator)

        # Write the character to the buffer - only pass 5 parameters, not 6
        buffer_after_write =
          Operations.write_char(
            buffer_for_write,
            write_x,
            write_y,
            char_to_write,
            emulator.style
          )

        # Update the emulator with the modified buffer
        Emulator.update_active_buffer(emulator, buffer_after_write)
      else
        Raxol.Core.Runtime.Log.warning_with_context(
          "Attempted write out of bounds (y=#{write_y}, height=#{buffer_height}), skipping write.",
          %{}
        )

        # No change to emulator if write is skipped
        emulator
      end

    # --- Update Cursor & State ---
    # Get the cursor struct from the state after writing
    cursor_before_move = emulator_after_write.cursor
    # Calculate the new position tuple
    new_position_tuple = {next_cursor_x, next_cursor_y}
    # Create a new cursor struct with the updated position
    new_cursor = %{cursor_before_move | position: new_position_tuple}

    # Update the emulator state with the new cursor and the flag
    %{
      emulator_after_write
      | # Put the newly created cursor struct back
        cursor: new_cursor,
        last_col_exceeded: next_last_col_exceeded,
        mode_manager: emulator.mode_manager,
        style: emulator.style,
        charset_state: new_charset_state,
        scroll_region: emulator.scroll_region,
        cursor_style: emulator.cursor_style,
        state_stack: emulator.state_stack
    }
  end

  @doc false
  # Helper to calculate write position and next cursor position based on current state
  # and wrapping modes. Returns {write_x, write_y, next_cursor_x, next_cursor_y, next_last_col_exceeded}
  def calculate_write_and_cursor_position(
        current_x,
        current_y,
        buffer_width,
        char_width,
        # Parameter name changed here
        last_col_exceeded,
        auto_wrap_mode
      ) do
    cond do
      # Case 0: Previous char caused wrap flag AND autowrap is ON
      last_col_exceeded and auto_wrap_mode ->
        # Write position is start of next line.
        # Cursor position is after writing the char on the new line.
        # Reset flag unless the new char itself fills the line.
        write_y = current_y + 1

        {0, write_y, char_width, write_y,
         auto_wrap_mode and char_width >= buffer_width}

      # Case 0.5: Previous char caused wrap flag BUT autowrap is OFF
      last_col_exceeded and not auto_wrap_mode ->
        # Write OVER the last character of the current line.
        # Cursor stays clamped at the last column index.
        # The wrap flag remains true because we are still at the edge.
        # Overwrite last cell
        write_x = buffer_width - 1
        write_y = current_y
        # Clamp cursor
        next_cursor_x = buffer_width - 1
        next_cursor_y = current_y
        # Still at the edge
        next_flag = true
        {write_x, write_y, next_cursor_x, next_cursor_y, next_flag}

      # Case 1: Character fits fully before the right margin (wrap flag is false here)
      current_x + char_width < buffer_width ->
        # Write at current position, advance cursor normally. Flag is false.
        {current_x, current_y, current_x + char_width, current_y, false}

      # Case 2: Character write *reaches* or *exceeds* the right margin (wrap flag is false here)
      # This implies current_x + char_width >= buffer_width
      true ->
        if auto_wrap_mode do
          # Autowrap ON: Write char at current position (it lands in the last cell).
          # Cursor visually stays at the *last* column index.
          # Set the wrap flag for the *next* character.
          {current_x, current_y, buffer_width - 1, current_y, true}
        else
          # Autowrap OFF: Write char at current position (it lands in the last cell).
          # Clamp cursor at the last column index. Flag is set because we hit the edge.
          # Set flag to true
          {current_x, current_y, buffer_width - 1, current_y, true}
        end
    end
  end

  # TODO: Move CSI, OSC, and other handlers here

  @doc """
  Process a character or string input, handling character sets and translations.
  """
  @spec process_input(String.t(), CharacterSets.t()) ::
          {String.t(), CharacterSets.t()}
  def process_input(input, char_sets) do
    # Convert input to graphemes for proper Unicode handling
    graphemes = String.graphemes(input)

    # Process each grapheme
    {processed, updated_sets} =
      Enum.reduce(graphemes, {"", char_sets}, fn grapheme, {acc, sets} ->
        # Get the first codepoint of the grapheme
        case String.first(grapheme) do
          nil ->
            {acc, sets}

          codepoint ->
            # Check if it's a control character
            if codepoint < 0x20 or codepoint == 0x7F do
              # Handle control characters
              {acc <> grapheme, sets}
            else
              # Get character width (unused)
              _width =
                Raxol.Terminal.CharacterHandling.get_char_width(codepoint)

              # Translate character based on current character set
              translated = CharacterSets.translate_char(codepoint, sets)

              # Handle combining characters
              if Raxol.Terminal.CharacterHandling.is_combining_char?(codepoint) do
                # For combining characters, append to previous character
                case String.last(acc) do
                  nil ->
                    # No previous character, treat as standalone
                    {acc <> translated, sets}

                  last ->
                    # Combine with previous character
                    {String.slice(acc, 0..-2//-1) <> last <> translated, sets}
                end
              else
                # Normal character processing
                {acc <> translated, sets}
              end
            end
        end
      end)

    # Process bidirectional text
    bidi_segments =
      Raxol.Terminal.CharacterHandling.process_bidi_text(processed)

    # Combine segments in correct order
    final_text =
      bidi_segments
      |> Enum.map(fn {_type, text} -> text end)
      |> Enum.join()

    {final_text, updated_sets}
  end

  @doc """
  Handle a control sequence in the input.
  """
  @spec handle_control_sequence(String.t(), CharacterSets.t()) ::
          {String.t(), CharacterSets.t()}
  def handle_control_sequence(sequence, char_sets) do
    case sequence do
      # Character set designations
      <<0x1B, 0x28, set>> ->
        {char_sets, CharacterSets.set_designator(:G0, set, char_sets)}

      <<0x1B, 0x29, set>> ->
        {char_sets, CharacterSets.set_designator(:G1, set, char_sets)}

      <<0x1B, 0x2A, set>> ->
        {char_sets, CharacterSets.set_designator(:G2, set, char_sets)}

      <<0x1B, 0x2B, set>> ->
        {char_sets, CharacterSets.set_designator(:G3, set, char_sets)}

      # Character set invocations
      <<0x0E>> ->
        {char_sets, CharacterSets.invoke_designator(:G1, :GL)}

      <<0x0F>> ->
        {char_sets, CharacterSets.invoke_designator(:G0, :GL)}

      <<0x1B, 0x4E>> ->
        {char_sets, CharacterSets.invoke_designator(:G2, :GL)}

      <<0x1B, 0x4F>> ->
        {char_sets, CharacterSets.invoke_designator(:G3, :GL)}

      <<0x1B, 0x7C>> ->
        {char_sets, CharacterSets.invoke_designator(:G2, :GR)}

      <<0x1B, 0x7D>> ->
        {char_sets, CharacterSets.invoke_designator(:G3, :GR)}

      <<0x1B, 0x7E>> ->
        {char_sets, CharacterSets.invoke_designator(:G1, :GR)}

      # Unknown sequence
      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Unknown control sequence: #{inspect(sequence)}",
          %{}
        )

        {char_sets, char_sets}
    end
  end

  @doc """
  Process a complete input string, handling both normal characters and control sequences.
  """
  @spec process_complete_input(String.t(), CharacterSets.t()) ::
          {String.t(), CharacterSets.t()}
  def process_complete_input(input, char_sets) do
    # Split input into control sequences and normal text
    {text, sequences} =
      input
      |> String.split(~r/\x1B[^a-zA-Z]*[a-zA-Z]/, include_captures: true)
      |> Enum.reduce({[], []}, fn
        <<0x1B, _::binary>> = seq, {text, seqs} -> {text, [seq | seqs]}
        text, {texts, seqs} -> {[text | texts], seqs}
      end)

    # Process control sequences
    {updated_sets, _} =
      Enum.reduce(sequences, {char_sets, []}, fn seq, {sets, _} ->
        handle_control_sequence(seq, sets)
      end)

    # Process remaining text
    process_input(Enum.join(text), updated_sets)
  end

  @doc """
  Handles a printable character, using single_shift if set (for SS2/SS3).
  """
  @spec handle_printable_character(
          Emulator.t(),
          integer(),
          any(),
          nil | :ss2 | :ss3
        ) :: {Emulator.t(), list()}
  def handle_printable_character(
        emulator,
        char_codepoint,
        _params,
        single_shift
      ) do
    # Use single_shift to select the charset for this character if set
    charset_state = emulator.charset_state

    charset_state =
      case single_shift do
        :ss2 ->
          Raxol.Terminal.ANSI.CharacterSets.set_single_shift(
            charset_state,
            :ss2
          )

        :ss3 ->
          Raxol.Terminal.ANSI.CharacterSets.set_single_shift(
            charset_state,
            :ss3
          )

        _ ->
          charset_state
      end

    # Translate the character using the possibly single-shifted charset
    _translated_char =
      Raxol.Terminal.ANSI.CharacterSets.translate_char(
        char_codepoint,
        charset_state
      )

    # After using single_shift, clear it
    charset_state =
      Raxol.Terminal.ANSI.CharacterSets.clear_single_shift(charset_state)

    emulator = %{emulator | charset_state: charset_state}

    # Write the translated character to the buffer
    updated_emulator = process_printable_character(emulator, char_codepoint)
    {updated_emulator, []}
  end
end
