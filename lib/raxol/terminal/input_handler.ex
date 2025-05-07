defmodule Raxol.Terminal.InputHandler do
  @moduledoc """
  Handles parsed terminal input events (printable characters, control codes, escape sequences)
  and updates the Emulator state accordingly.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Operations
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.ANSI.TerminalState
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.ModeManager
  alias Raxol.Terminal.Parser
  alias Raxol.Plugins.PluginManager
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ControlCodes
  alias Raxol.Terminal.Style.Manager, as: StyleManager
  alias Raxol.Terminal.CharacterHandling
  alias Raxol.Terminal.Clipboard

  require Logger

  # TODO: Move handler functions here from Emulator module.

  @type t :: %__MODULE__{
          buffer: String.t(),
          cursor_position: non_neg_integer(),
          clipboard: Clipboard.t(),
          tab_completion: map(),
          tab_completion_index: non_neg_integer(),
          tab_completion_matches: list(String.t()),
          mode_manager: ModeManager.t()
        }

  defstruct [
    :buffer,
    :cursor_position,
    :clipboard,
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
      clipboard: Clipboard.new(),
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
    case Clipboard.paste() do # Call Raxol.System.Clipboard.paste/0
      {:ok, text} ->
        new_buffer = insert_text(handler.buffer, handler.cursor_position, text)
        new_position = handler.cursor_position + String.length(text)
        {:ok, %{handler | buffer: new_buffer, cursor_position: new_position}}

      {:error, reason} ->
        {:error, reason} # Pass through error
    end
  end

  @doc """
  Handles clipboard copy operation.
  (Currently copies the entire buffer)
  """
  @spec handle_copy(t()) :: {:ok, t()} | {:error, any()}
  def handle_copy(%__MODULE__{} = handler) do
    case Clipboard.copy(handler.buffer) do # Call Raxol.System.Clipboard.copy/1
      :ok ->
        {:ok, handler} # Return handler unchanged on success
      {:error, reason} ->
        {:error, reason} # Pass through error
    end
  end

  @doc """
  Handles clipboard cut operation.
  (Currently cuts the entire buffer)
  """
  @spec handle_cut(t()) :: {:ok, t()} | {:error, any()}
  def handle_cut(%__MODULE__{} = handler) do
    with :ok <- Clipboard.copy(handler.buffer), # Call Raxol.System.Clipboard.copy/1
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

  # --- C0 and Printable Character Handling ---

  @doc """
  Processes a single character codepoint.
  Delegates to C0 handlers or printable character handlers.
  """
  @spec process_character(Emulator.t(), integer()) :: Emulator.t()
  def process_character(emulator, char_codepoint)
      when (char_codepoint >= 0 and char_codepoint <= 31) or char_codepoint == 127 do
    # Handle C0 Control Codes and DEL using the ControlCodes module
    # ControlCodes functions should now take InputHandler as the first arg if they need
    # to call back for further processing, or just return the updated emulator state.
    # Assuming ControlCodes.handle_c0 returns the updated emulator state directly.
    ControlCodes.handle_c0(emulator, char_codepoint)
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
    translated_codepoint = CharacterSets.translate_char(emulator.charset_state, char_codepoint)
    # Pass the integer codepoint to get_char_width
    char_width = CharacterHandling.get_char_width(translated_codepoint)

    # Check if auto wrap mode (DECAWM) is enabled
    auto_wrap_mode = ModeManager.mode_enabled?(emulator.mode_manager, :decawm)
    {current_cursor_x, current_cursor_y} = emulator.cursor.position

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
        Logger.debug("[InputHandler] Writing char codepoint '#{translated_codepoint}' with style: #{inspect(emulator.style)}")

        # Convert codepoint back to binary for writing
        char_to_write = <<translated_codepoint::utf8>>

        # Get the active buffer for writing
        buffer_for_write = Emulator.get_active_buffer(emulator)

        # Write the character to the buffer - only pass 5 parameters, not 6
        buffer_after_write = Operations.write_char(
          buffer_for_write,
          write_x,
          write_y,
          char_to_write,
          emulator.style
        )

        # Update the emulator with the modified buffer
        Emulator.update_active_buffer(emulator, buffer_after_write)
      else
        Logger.warning(
          "Attempted write out of bounds (y=#{write_y}, height=#{buffer_height}), skipping write."
        )
        emulator # No change to emulator if write is skipped
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
      | cursor: new_cursor, # Put the newly created cursor struct back
        last_col_exceeded: next_last_col_exceeded,
        mode_manager: emulator.mode_manager,
        style: emulator.style,
        charset_state: emulator.charset_state,
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
        last_col_exceeded, # Parameter name changed here
        auto_wrap_mode
      ) do
    cond do
      # Case 0: Previous char caused wrap flag AND autowrap is ON
      last_col_exceeded and auto_wrap_mode ->
        # Write position is start of next line.
        # Cursor position is after writing the char on the new line.
        # Reset flag unless the new char itself fills the line.
        write_y = current_y + 1
        {0, write_y, char_width, write_y, auto_wrap_mode and (char_width >= buffer_width)}

      # Case 0.5: Previous char caused wrap flag BUT autowrap is OFF
      last_col_exceeded and not auto_wrap_mode ->
        # Write OVER the last character of the current line.
        # Cursor stays clamped at the last column index.
        # The wrap flag remains true because we are still at the edge.
        write_x = buffer_width - 1 # Overwrite last cell
        write_y = current_y
        next_cursor_x = buffer_width - 1 # Clamp cursor
        next_cursor_y = current_y
        next_flag = true # Still at the edge
        {write_x, write_y, next_cursor_x, next_cursor_y, next_flag}

      # Case 1: Character fits fully before the right margin (wrap flag is false here)
      current_x + char_width < buffer_width ->
        # Write at current position, advance cursor normally. Flag is false.
        {current_x, current_y, current_x + char_width, current_y, false}

      # Case 2: Character write *reaches* or *exceeds* the right margin (wrap flag is false here)
      true -> # This implies current_x + char_width >= buffer_width
        if auto_wrap_mode do
          # Autowrap ON: Write char at current position (it lands in the last cell).
          # Cursor visually stays at the *last* column index.
          # Set the wrap flag for the *next* character.
          {current_x, current_y, buffer_width - 1, current_y, true}
        else
          # Autowrap OFF: Write char at current position (it lands in the last cell).
          # Clamp cursor at the last column index. Flag is set because we hit the edge.
          {current_x, current_y, buffer_width - 1, current_y, true} # Set flag to true
        end
    end
  end

  # TODO: Move CSI, OSC, and other handlers here

end
