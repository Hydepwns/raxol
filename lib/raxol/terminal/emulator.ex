defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  The Raxol Terminal Emulator module provides a terminal emulation layer that
  handles screen buffer management, cursor positioning, input handling, and
  terminal state management.

  Note: When running in certain environments, stdin may be excluded from Credo analysis
  due to how it's processed. This is expected behavior and doesn't affect functionality.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.{Manager, Movement}
  alias Raxol.Terminal.Cursor.Style
  alias Raxol.Terminal.EscapeSequence
  alias Raxol.Terminal.ANSI.ScreenModes
  alias Raxol.Terminal.ANSI.CharacterSets
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Plugins.PluginManager
  alias Raxol.Terminal.ANSI.TerminalState
  require Logger

  @type t :: %__MODULE__{
          screen_buffer: ScreenBuffer.t(),
          cursor: Manager.t(),
          scroll_region: {non_neg_integer(), non_neg_integer()} | nil,
          style: TextFormatting.text_style(),
          memory_limit: non_neg_integer(),
          charset_state: CharacterSets.charset_state(),
          mode_state: ScreenModes.screen_state(),
          state_stack: TerminalState.state_stack(),
          plugin_manager: PluginManager.t(),
          options: map(),
          current_hyperlink_url: String.t() | nil
        }

  # Use Manager struct
  defstruct cursor: Manager.new(),
            # TODO: This might need updating to save Manager state?
            saved_cursor: {1, 1},
            style: TextFormatting.new(),
            # Manages G0-G3 designation and invocation
            charset_state: CharacterSets.new(),
            # Tracks various modes (like DECCKM, DECOM)
            mode_state: ScreenModes.new(),
            # <--- Change: Store the ScreenBuffer struct here
            screen_buffer: nil,
            # Stack for DECSC/DECRC like operations
            state_stack: TerminalState.new(),
            # Active scroll region {top_line, bottom_line} (1-based), nil for full screen
            scroll_region: nil,
            # Default memory limit (e.g., bytes or lines)
            memory_limit: 1_000_000,
            # Flag for VT100 line wrapping behavior (DECAWM)
            last_col_exceeded: false,
            # State for the ANSI parser
            parser_state: :ground,
            # Buffer for accumulating escape sequence bytes
            parser_buffer: "",
            # Parameters extracted from escape sequence
            parser_params: [],
            # Intermediate characters in escape sequence
            parser_intermediates: "",
            # Initialize Plugin Manager,
            plugin_manager: PluginManager.new(),
            options: %{},
            current_hyperlink_url: nil

  @doc """
  Creates a new terminal emulator instance with the specified dimensions and options.

  ## Examples

      iex> emulator = Raxol.Terminal.Emulator.new(80, 24, %{})
      iex> emulator.width
      80
      iex> emulator.height
      24
      iex> emulator.cursor.position
      {0, 0}

  """
  @spec new(non_neg_integer(), non_neg_integer(), map()) :: t()
  @dialyzer {:nowarn_function, new: 3}
  def new(width \\ 80, height \\ 24, opts \\ []) do
    scrollback_limit = Keyword.get(opts, :scrollback, 1000)
    memory_limit = Keyword.get(opts, :memory_limit, 1_000_000)
    plugin_manager = PluginManager.new()
    # Initialize Manager
    initial_cursor = Manager.new()
    initial_buffer = ScreenBuffer.new(width, height, scrollback_limit)
    initial_modes = ScreenModes.new()
    initial_charset_state = CharacterSets.new()
    initial_state_stack = TerminalState.new()

    %{
      # Assign Manager struct
      cursor: initial_cursor,
      # TODO: Update saved_cursor logic?
      saved_cursor: {1, 1},
      style: TextFormatting.new(),
      charset_state: initial_charset_state,
      mode_state: initial_modes,
      # <--- Change: Store the full struct
      screen_buffer: initial_buffer,
      state_stack: initial_state_stack,
      scroll_region: nil,
      # Initialize from variable
      memory_limit: memory_limit,
      last_col_exceeded: false,
      parser_state: :ground,
      parser_buffer: "",
      parser_params: [],
      parser_intermediates: "",
      # Assign initialized Plugin Manager
      plugin_manager: plugin_manager
    }
  end

  @doc """
  Processes input from the user, handling both regular characters and escape sequences.

  ## Examples

      iex> emulator = Raxol.Terminal.Emulator.new(80, 24, %{})
      iex> {emulator, _} = Raxol.Terminal.Emulator.process_input(emulator, "a")
      iex> emulator.cursor.position
      {1, 0}

  """
  @spec process_input(t(), String.t()) :: {t(), String.t()} | {:error, any()}
  def process_input(emulator, input) do
    case input do
      "\e" <> rest ->
        process_escape_sequence(emulator, "\e" <> rest)

      char when is_binary(char) and byte_size(char) == 1 ->
        process_character(emulator, char)

      _ ->
        {emulator, ""}
    end
  end

  @doc """
  Processes an escape sequence, updating the terminal state accordingly.

  ## Examples

      iex> emulator = Raxol.Terminal.Emulator.new(80, 24, %{})
      iex> {emulator, _} = Raxol.Terminal.Emulator.process_escape_sequence(emulator, "\e[10;5H")
      iex> emulator.cursor.position
      {4, 9}

  """
  @spec process_escape_sequence(t(), String.t()) :: {t(), String.t()}
  def process_escape_sequence(%__MODULE__{} = emulator, sequence) do
    case EscapeSequence.parse(sequence) do
      {:ok, command_data, rest} ->
        # Dispatch based on parsed command
        updated_emulator = dispatch_command(emulator, command_data)
        {updated_emulator, rest}

      {:incomplete, _} ->
        # Sequence is incomplete, need more input
        # TODO: How should the emulator handle incomplete sequences? Buffer?
        Logger.debug("Incomplete escape sequence: #{inspect(sequence)}")
        # For now, consume nothing and return unchanged
        {emulator, ""}

      {:error, reason, invalid_part} ->
        Logger.error(
          "Error parsing escape sequence (#{reason}): #{inspect(sequence)}, invalid part: #{inspect(invalid_part)}"
        )

        # Decide how to handle errors, e.g., consume the invalid part?
        # Consume the invalid part
        {emulator, invalid_part}
    end
  end

  # Helper to dispatch parsed commands to emulator functions
  defp dispatch_command(emulator, {:batch, commands}) do
    Enum.reduce(commands, emulator, &dispatch_command/2)
  end

  defp dispatch_command(emulator, {:cursor_position, {row, col}}) do
    move_cursor_absolute(emulator, row, col)
  end

  defp dispatch_command(emulator, {:cursor_move, :up, count}) do
    move_cursor(emulator, :up, count)
  end

  defp dispatch_command(emulator, {:cursor_move, :down, count}) do
    move_cursor(emulator, :down, count)
  end

  defp dispatch_command(emulator, {:cursor_move, :right, count}) do
    move_cursor(emulator, :forward, count)
  end

  defp dispatch_command(emulator, {:cursor_move, :left, count}) do
    move_cursor(emulator, :backward, count)
  end

  defp dispatch_command(emulator, {:cursor_next_line, count}) do
    move_cursor(emulator, :next_line, count)
  end

  defp dispatch_command(emulator, {:cursor_prev_line, count}) do
    move_cursor(emulator, :prev_line, count)
  end

  defp dispatch_command(emulator, {:cursor_col_abs, col}) do
    move_cursor_absolute(emulator, nil, col)
  end

  # Mode setting uses a helper to map codes to atoms
  defp dispatch_command(emulator, {:set_mode, type, code, value}) do
    handle_mode_change(emulator, type, code, value)
  end

  # Character Sets
  defp dispatch_command(emulator, {:designate_charset, g_set, charset_atom}) do
    designate_charset(emulator, g_set, charset_atom)
  end

  defp dispatch_command(emulator, {:invoke_charset_gr, g_set}) do
    # TODO: Implement GR invocation logic (updates GR mapping in Charset state)
    Logger.debug("GR Invocation not fully implemented yet: #{g_set}")
    emulator
  end

  # SGR - Needs mapping codes to style changes
  defp dispatch_command(emulator, {:set_graphic_rendition, codes}) do
    # TODO: Implement SGR logic - map codes to TextFormatting changes
    # Requires TextFormatting module interaction
    Logger.debug("SGR not fully implemented: #{inspect(codes)}")
    emulator
  end

  # Scroll Region
  defp dispatch_command(emulator, {:set_scroll_region, region_tuple}) do
    case region_tuple do
      nil -> clear_scroll_region(emulator)
      {top, bottom} -> set_scroll_region(emulator, top, bottom)
    end
  end

  # Erasing
  defp dispatch_command(emulator, {:erase_display, _mode}) do
    # TODO: Implement erase display logic (using ScreenBuffer.clear_region?)
    Logger.debug("Erase Display (ED) not implemented yet")
    emulator
  end

  defp dispatch_command(emulator, {:erase_line, _mode}) do
    # TODO: Implement erase line logic
    Logger.debug("Erase Line (EL) not implemented yet")
    emulator
  end

  # Scrolling
  defp dispatch_command(emulator, {:scroll, :up, count}) do
    scroll_up(emulator, count)
  end

  defp dispatch_command(emulator, {:scroll, :down, count}) do
    scroll_down(emulator, count)
  end

  # Cursor Saving/Restoring (DEC)
  defp dispatch_command(emulator, {:dec_save_cursor, _}) do
    # Use general state stack for now
    push_state(emulator)
  end

  defp dispatch_command(emulator, {:dec_restore_cursor, _}) do
    pop_state(emulator)
  end

  # DSR
  defp dispatch_command(emulator, {:device_status_report, type}) do
    # TODO: Implement DSR response generation
    Logger.debug(
      "Device Status Report (DSR) response not implemented yet: #{type}"
    )

    emulator
  end

  # Default: Unknown/unhandled command
  defp dispatch_command(emulator, command_data) do
    Logger.warning(
      "Unhandled parsed command in dispatch_command: #{inspect(command_data)}"
    )

    emulator
  end

  # --- Mode Setting ---
  def set_screen_mode(%__MODULE__{} = emulator, mode_atom) do
    new_mode_state = ScreenModes.set_mode(emulator.mode_state, mode_atom)
    emulator_with_state = %{emulator | mode_state: new_mode_state}

    # Handle side effects for specific modes
    case mode_atom do
      # Mode 3: 132 Column Mode
      :columns_132 ->
        new_width = 132
        Logger.debug("Emulator: Setting 132 column mode. Resizing buffer.")
        # ---> Change: Pass the struct and use struct's height <---
        new_buffer =
          ScreenBuffer.resize(
            emulator.screen_buffer,
            new_width,
            emulator.screen_buffer.height
          )

        # ---> Change: Replace old struct with new one, remove width update <---
        if new_buffer do
          %{emulator_with_state | screen_buffer: new_buffer}
        else
          Logger.error(
            "Emulator: Failed to resize screen buffer for 132 columns."
          )

          # Return unchanged state on resize failure
          emulator_with_state
        end

      # Mode 47/1047/1049: Alternate Screen Buffer
      # ... (keep existing TODOs/logging) ...
      :alternate_screen ->
        # TODO: Implement alternate buffer saving/clearing logic
        Logger.debug(
          "Emulator: Set Alternate Screen Buffer (not fully implemented)"
        )

        # Return state with mode updated for now
        emulator_with_state

      :alternate_screen_sc ->
        # TODO: Implement alternate buffer saving/clearing logic
        Logger.debug(
          "Emulator: Set Alternate Screen Buffer SC (not fully implemented)"
        )

        emulator_with_state

      :alternate_screen_full ->
        # TODO: Implement alternate buffer saving/clearing logic
        Logger.debug(
          "Emulator: Set Alternate Screen Buffer Full (not fully implemented)"
        )

        emulator_with_state

      _ ->
        # No special side effects for other modes
        emulator_with_state
    end
  end

  def reset_screen_mode(%__MODULE__{} = emulator, mode_atom) do
    new_mode_state = ScreenModes.reset_mode(emulator.mode_state, mode_atom)
    emulator_with_state = %{emulator | mode_state: new_mode_state}

    # Handle side effects for specific modes
    case mode_atom do
      # Mode 3: 80 Column Mode
      :columns_132 ->
        new_width = 80
        Logger.debug("Emulator: Resetting to 80 column mode. Resizing buffer.")
        # ---> Change: Pass the struct and use struct's height <---
        new_buffer =
          ScreenBuffer.resize(
            emulator.screen_buffer,
            new_width,
            emulator.screen_buffer.height
          )

        # ---> Change: Replace old struct with new one, remove width update <---
        if new_buffer do
          %{emulator_with_state | screen_buffer: new_buffer}
        else
          Logger.error(
            "Emulator: Failed to resize screen buffer for 80 columns."
          )

          # Return unchanged state on resize failure
          emulator_with_state
        end

      # Mode 47/1047/1049: Main Screen Buffer
      # ... (keep existing TODOs/logging) ...
      :alternate_screen ->
        # TODO: Implement main buffer restoring logic
        Logger.debug(
          "Emulator: Reset Alternate Screen Buffer (not fully implemented)"
        )

        # Return state with mode updated for now
        emulator_with_state

      :alternate_screen_sc ->
        # TODO: Implement main buffer restoring logic
        Logger.debug(
          "Emulator: Reset Alternate Screen Buffer SC (not fully implemented)"
        )

        emulator_with_state

      :alternate_screen_full ->
        # TODO: Implement main buffer restoring logic
        Logger.debug(
          "Emulator: Reset Alternate Screen Buffer Full (not fully implemented)"
        )

        emulator_with_state

      _ ->
        # No special side effects for other modes
        emulator_with_state
    end
  end

  # --- Internal Command Processing ---

  # Helper to get current buffer dimensions
  defp buffer_dimensions(%__MODULE__{
         screen_buffer: %ScreenBuffer{width: w, height: h}
       }) do
    {w, h}
  end

  defp buffer_dimensions(%__MODULE__{}) do
    Logger.warn(
      "Emulator: Attempted to get dimensions from invalid screen_buffer."
    )

    # Default or error dimensions
    {0, 0}
  end

  # Helper to update a cell in the buffer
  defp update_cell(%__MODULE__{} = emulator, {line, col}, cell) do
    new_screen_buffer =
      ScreenBuffer.update_cell(emulator.screen_buffer, {line, col}, cell)

    if new_screen_buffer do
      %{emulator | screen_buffer: new_screen_buffer}
    else
      Logger.error("Emulator: Failed to update cell at {#{line}, #{col}}")
      # Return unchanged on failure
      emulator
    end
  end

  # ... potentially other helpers using screen_buffer ...

  # --- Character Processing ---

  defp process_character(%__MODULE__{} = emulator, char) do
    # Check for C0/C1 control codes first (TODO)

    # Handle printable characters
    {line, col} = emulator.cursor.position
    # ---> Change: Get dimensions from struct <---
    {width, height} = buffer_dimensions(emulator)

    # Autowrap (DECAWM) handling
    # Needs refinement based on exact DECAWM logic
    # wrapped = if col > width and ScreenModes.is_set?(emulator.mode_state, :autowrap) do
    #   # Move to start of next line, potentially scrolling
    #   # This logic needs ScreenBuffer.scroll_up integration
    #   new_line = min(line + 1, height) # Simplified - needs scroll check
    #   emulator = %{emulator | cursor: {new_line, 1}}
    #   true
    # else
    #   false
    # end
    # {line, col} = emulator.cursor # Re-fetch cursor after potential wrap

    if line > height or col > width do
      Logger.warn(
        "Emulator: Cursor #{line},#{col} out of bounds #{width}x#{height}. Ignoring char '#{char}'."
      )

      # Ignore characters if cursor is out of bounds
      emulator
    end

    # Apply current style to the character
    cell_to_write = Cell.new(char, emulator.style)

    # Update the cell in the buffer
    # ---> Change: Use helper <---
    emulator_with_update = update_cell(emulator, {line, col}, cell_to_write)

    # Advance cursor
    new_col = col + 1

    # TODO: Handle DECAWM wrap explicitly here if needed, maybe set last_col_exceeded
    %{emulator_with_update | cursor: {line, new_col}}
  end

  # ... existing code ...

  # --- Command Dispatch ---

  defp dispatch_command(emulator, command) do
    Logger.debug("Emulator: Dispatching command: #{inspect(command)}")

    case command do
      # --- Cursor Movement ---
      {:cursor_up, count} ->
        move_cursor(emulator, :up, count)

      {:cursor_down, count} ->
        move_cursor(emulator, :down, count)

      {:cursor_forward, count} ->
        move_cursor(emulator, :forward, count)

      {:cursor_backward, count} ->
        move_cursor(emulator, :backward, count)

      {:cursor_next_line, count} ->
        move_cursor(emulator, :next_line, count)

      {:cursor_prev_line, count} ->
        move_cursor(emulator, :prev_line, count)

      {:cursor_horizontal_absolute, col} ->
        move_cursor_absolute(emulator, nil, col)

      {:cursor_position, line, col} ->
        move_cursor_absolute(emulator, line + 1, col + 1)

      {:cursor_save, :dec} ->
        %{emulator | saved_cursor: emulator.cursor}

      {:cursor_restore, :dec} ->
        %{emulator | cursor: emulator.saved_cursor}

      # --- Mode Setting ---
      {:set_mode, :dec_private, code, value} ->
        handle_mode_change(emulator, :dec_private, code, value)

      {:set_mode, :standard, code, value} ->
        handle_mode_change(emulator, :standard, code, value)

      # --- Batch Commands ---
      {:batch, commands} ->
        Enum.reduce(commands, emulator, &dispatch_command(&2, &1))

      # TODO: Add SCO cursor save/restore if needed

      # --- Erasing ---
      # Requires ScreenBuffer erase functions
      {:erase_in_display, type} ->
        erase_in_display(emulator, type)

      {:erase_in_line, type} ->
        erase_in_line(emulator, type)

      # --- Scrolling ---
      # Requires ScreenBuffer scroll functions
      {:scroll_up, count} ->
        scroll_window(emulator, :up, count)

      {:scroll_down, count} ->
        scroll_window(emulator, :down, count)

      {:set_scroll_region, top, bottom} ->
        set_scroll_region(emulator, top, bottom)

      # --- Mode Setting (Unified handling) ---
      {:set_mode, type, code, value} ->
        handle_mode_change(emulator, type, code, value)

      # --- Character Attributes (SGR) ---
      {:select_graphic_rendition, params} ->
        apply_sgr(emulator, params)

      # --- Character Sets ---
      {:designate_charset, g, charset} ->
        designate_charset(emulator, g, charset)

      # TODO: Map GL correctly (usually G0)
      {:shift_in, _} ->
        %{emulator | current_charset: 0}

      # TODO: Map GL correctly (usually G1)
      {:shift_out, _} ->
        %{emulator | current_charset: 1}

      # --- Device Status Report (DSR) ---
      # TODO: Implement DSR responses

      # --- Window Manipulation ---
      # TODO: Implement window manipulation commands if needed (DTTERM / XTWINOPS)

      # --- Other ---
      # TODO: Implement other commands (tabs, etc.)

      _ ->
        Logger.warn("Emulator: Unhandled command: #{inspect(command)}")
        # Return unchanged for unhandled commands
        emulator
    end
  end

  # --- Specific Command Implementations ---

  # Helper for relative cursor movement
  defp move_cursor(%__MODULE__{} = emulator, direction, count) do
    # Get current 0-based position from Manager struct
    {col, line} = emulator.cursor.position
    # Get dimensions (assuming buffer_dimensions returns {width, height})
    {width, height} = buffer_dimensions(emulator)

    # Calculate new 0-based position
    {new_col, new_line} =
      case direction do
        # Emulator uses 1-based, Manager 0-based. Calculations done in 0-based.
        :up -> {col, max(0, line - count)}
        :down -> {col, min(height - 1, line + count)}
        :forward -> {min(width - 1, col + count), line}
        :backward -> {max(0, col - count), line}
        # Emulator next/prev line moves to col 1 (0-based)
        :next_line -> {0, min(height - 1, line + count)}
        :prev_line -> {0, max(0, line - count)}
      end

    # Update cursor struct using Manager function
    new_cursor_manager = Manager.move_to(emulator.cursor, new_col, new_line)

    %{emulator | cursor: new_cursor_manager}
  end

  # Helper for absolute cursor movement (HVP / CUP)
  defp move_cursor_absolute(%__MODULE__{} = emulator, line_1_based, col_1_based) do
    {width, height} = buffer_dimensions(emulator)

    # Default to 1 if parameter is 0 or missing (nil), then clamp (1-based)
    effective_line_1_based =
      clamp(
        if(line_1_based == nil or line_1_based == 0, do: 1, else: line_1_based),
        1,
        height
      )

    effective_col_1_based =
      clamp(
        if(col_1_based == nil or col_1_based == 0, do: 1, else: col_1_based),
        1,
        width
      )

    # Convert to 0-based for Manager
    col_0_based = effective_col_1_based - 1
    line_0_based = effective_line_1_based - 1

    # Update cursor struct using Manager function
    new_cursor_manager =
      Manager.move_to(emulator.cursor, col_0_based, line_0_based)

    %{emulator | cursor: new_cursor_manager}
  end

  # Placeholder for erase functions (requires ScreenBuffer integration)
  defp erase_in_display(%__MODULE__{} = emulator, type) do
    Logger.debug(
      "Emulator: Erase in Display (type: #{type}) - requires ScreenBuffer implementation"
    )

    # TODO: Call ScreenBuffer.erase_in_display(emulator.screen_buffer, emulator.cursor, type)
    # new_buffer = ScreenBuffer.erase_in_display(emulator.screen_buffer, emulator.cursor, type)
    # %{emulator | screen_buffer: new_buffer}
    emulator
  end

  defp erase_in_line(%__MODULE__{} = emulator, type) do
    Logger.debug(
      "Emulator: Erase in Line (type: #{type}) - requires ScreenBuffer implementation"
    )

    # TODO: Call ScreenBuffer.erase_in_line(emulator.screen_buffer, emulator.cursor, type)
    # new_buffer = ScreenBuffer.erase_in_line(emulator.screen_buffer, emulator.cursor, type)
    # %{emulator | screen_buffer: new_buffer}
    emulator
  end

  # Placeholder for scroll functions (requires ScreenBuffer integration)
  defp scroll_window(%__MODULE__{} = emulator, direction, count) do
    Logger.debug(
      "Emulator: Scroll Window (#{direction}, #{count}) - requires ScreenBuffer implementation"
    )

    # TODO: Call ScreenBuffer.scroll(emulator.screen_buffer, direction, count)
    # new_buffer = ScreenBuffer.scroll(emulator.screen_buffer, direction, count)
    # %{emulator | screen_buffer: new_buffer}
    emulator
  end

  defp set_scroll_region(%__MODULE__{} = emulator, top, bottom) do
    Logger.debug(
      "Emulator: Set Scroll Region (#{top}, #{bottom}) - requires ScreenBuffer implementation"
    )

    # ---> Change: Update struct within screen_buffer <---
    new_buffer =
      ScreenBuffer.set_scroll_region(emulator.screen_buffer, top, bottom)

    if new_buffer do
      # Move cursor to home
      %{emulator | screen_buffer: new_buffer, cursor: {1, 1}}
    else
      Logger.error("Emulator: Failed to set scroll region.")
      emulator
    end
  end

  # SGR implementation (simplified example)
  defp apply_sgr(%__MODULE__{} = emulator, params) do
    new_style = Enum.reduce(params, emulator.style, &Style.apply_sgr_code/2)
    %{emulator | style: new_style}
  end

  # Charset implementation (simplified)
  defp designate_charset(%__MODULE__{} = emulator, g, charset_atom) do
    # G must be 0, 1, 2, or 3
    # Default to G0
    g_index = if g in [0, 1, 2, 3], do: g, else: 0
    new_charsets = Map.put(emulator.charset_state, g_index, charset_atom)
    %{emulator | charset_state: new_charsets}
  end

  # Mode setting dispatchers (delegating to set/reset_screen_mode)
  # defp set_standard_mode(emulator, code), do: set_screen_mode(emulator, ScreenModes.lookup_standard(code))
  # defp set_private_mode(emulator, code), do: set_screen_mode(emulator, ScreenModes.lookup_private(code))
  # defp reset_standard_mode(emulator, code), do: reset_screen_mode(emulator, ScreenModes.lookup_standard(code))
  # defp reset_private_mode(emulator, code), do: reset_screen_mode(emulator, ScreenModes.lookup_private(code))

  # --- Unified Mode Handling ---
  @doc """
  Handles setting or resetting a standard or DEC private mode.
  Looks up the mode atom and applies the change based on the value.
  """
  defp handle_mode_change(%__MODULE__{} = emulator, type, code, value) do
    mode_atom =
      case type do
        :standard ->
          ScreenModes.lookup_standard(code)

        :dec_private ->
          ScreenModes.lookup_private(code)

        _ ->
          Logger.warn(
            "Emulator: Unknown mode type '#{type}' for code '#{code}'"
          )

          nil
      end

    if mode_atom do
      # Delegate to a function that handles the specific mode atom change
      # This function will encapsulate the logic previously in set_screen_mode/reset_screen_mode
      apply_mode_change(emulator, mode_atom, value)
    else
      Logger.warn("Emulator: Unknown mode code '#{code}' for type '#{type}'")
      # Return unchanged if mode is unknown
      emulator
    end
  end

  # Placeholder for the function that applies the actual mode change logic
  # Needs to handle specific mode_atoms like :deccolm_132, :decawm, etc.
  defp apply_mode_change(%__MODULE__{} = emulator, mode_atom, value) do
    # TODO: Implement the logic for each mode atom based on \'value\' (true/false)
    # This might involve updating emulator.mode_state, calling ScreenBuffer functions,
    # adjusting cursor, clearing screen, etc.
    Logger.debug("Emulator: Applying mode change: #{mode_atom} -> #{value}")

    # Example: Handling :deccolm_132 (Column Width)
    case mode_atom do
      :deccolm_132 ->
        # Update mode_state using ScreenModes functions
        new_mode_state =
          if value do
            ScreenModes.set_mode(emulator.mode_state, :wide_column)
          else
            ScreenModes.reset_mode(emulator.mode_state, :wide_column)
          end

        # Determine new width
        new_width = if value, do: 132, else: 80
        current_height = emulator.screen_buffer.height

        # Resize the buffer
        resized_buffer =
          ScreenBuffer.resize(emulator.screen_buffer, new_width, current_height)

        # Clear the resized buffer
        cleared_buffer =
          ScreenBuffer.clear_region(
            resized_buffer,
            0,
            0,
            new_width - 1,
            current_height - 1
          )

        # Move cursor to home position (0, 0)
        # Use the dedicated function from the Movement module
        new_cursor = Movement.move_home(emulator.cursor)

        Logger.info(
          "Emulator: Mode :deccolm_132 set to #{value}. Resized to #{new_width}x#{current_height}, cleared screen, and reset cursor."
        )

        # Update emulator state
        %{
          emulator
          | mode_state: new_mode_state,
            screen_buffer: cleared_buffer,
            cursor: new_cursor
        }

      # TODO: Add cases for other modes (:decawm, :decom, :decsclm, :insert_mode, etc.)

      _ ->
        Logger.warn(
          "Emulator: Unhandled mode atom in apply_mode_change: #{mode_atom}"
        )

        emulator
    end

    # Placeholder return
    # emulator
  end

  # Helper for clamping values
  defp clamp(val, min_val, max_val) do
    max(min_val, min(val, max_val))
  end

  @doc """
  Pops the most recently saved terminal state from the stack and applies it.
  """
  @spec pop_state(t()) :: t()
  def pop_state(%__MODULE__{state_stack: stack} = emulator) do
    # Call restore_state with the current stack
    case Raxol.Terminal.ANSI.TerminalState.restore_state(stack) do
      # Match {new_stack, state_map}
      {updated_stack, %{} = restored_state} ->
        Logger.debug("Popped and restoring state: #{inspect(restored_state)}")

        # Apply the restored state components to the emulator
        # Restore the full cursor state saved under :cursor
        new_cursor =
          Map.get(restored_state, :cursor, emulator.cursor)

        # Restore attributes (saved from text_style) under :attributes key
        new_text_style =
          Map.get(restored_state, :attributes, emulator.style)

        new_charset_state =
          Map.get(restored_state, :charset_state, emulator.charset_state)

        new_mode_state =
          Map.get(restored_state, :mode_state, emulator.mode_state)

        new_scroll_region =
          Map.get(restored_state, :scroll_region, emulator.scroll_region)

        %{
          emulator
          | state_stack: updated_stack,
            # Assign the updated cursor manager
            cursor: new_cursor,
            text_style: new_text_style,
            charset_state: new_charset_state,
            mode_state: new_mode_state,
            scroll_region: new_scroll_region
        }

      # Handle case where state couldn't be popped/restored (stack empty)
      {updated_stack, nil} ->
        Logger.warning(
          "pop_state called, but no state was restored (stack might be empty)."
        )

        %{emulator | state_stack: updated_stack}
    end
  end

  @doc """
  Gets the current terminal state.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> state = Emulator.get_state(emulator)
      iex> state.cursor_visible
      true
  """
  def get_state(%__MODULE__{} = emulator) do
    # Return a map representing the current state, not from stack
    %{
      cursor_position: emulator.cursor.position,
      cursor_style: emulator.cursor.style,
      cursor_state: emulator.cursor.state,
      text_style: emulator.style,
      mode_state: emulator.mode_state,
      charset_state: emulator.charset_state,
      scroll_region: emulator.scroll_region,
      width: emulator.width,
      height: emulator.height
      # Add other relevant state fields as needed
    }
  end

  @doc """
  Sets the terminal state.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_state(emulator, %{cursor_style: :block, text_style: %{bold: true}})
      iex> emulator.cursor.style
      :block
      iex> emulator.text_style.bold
      true
  """
  def set_state(%__MODULE__{} = emulator, state_map) when is_map(state_map) do
    # Apply the state map to the current emulator state, don't modify stack
    new_cursor =
      Map.take(state_map, [:cursor_position, :cursor_style, :cursor_state])
      |> Enum.reduce(emulator.cursor, fn {key, value}, acc ->
        case key do
          :cursor_position ->
            Manager.move_to(acc, elem(value, 0), elem(value, 1))

          :cursor_style ->
            Manager.set_style(acc, value)

          :cursor_state ->
            Manager.set_state(acc, value)

          _ ->
            acc
        end
      end)

    new_text_style =
      Map.merge(emulator.style, Map.get(state_map, :style, %{}))

    new_mode_state =
      Map.merge(emulator.mode_state, Map.get(state_map, :mode_state, %{}))

    new_charset_state =
      Map.merge(emulator.charset_state, Map.get(state_map, :charset_state, %{}))

    new_scroll_region =
      Map.get(state_map, :scroll_region, emulator.scroll_region)

    # Add logic to update width/height if they are included in state_map and resizing is intended

    %{
      emulator
      | cursor: new_cursor,
        style: new_text_style,
        mode_state: new_mode_state,
        charset_state: new_charset_state,
        scroll_region: new_scroll_region
        # Update other fields as necessary
    }
  end

  @doc """
  Gets the current screen buffer contents.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.process_input(emulator, "Hello")
      iex> buffer = Emulator.get_buffer(emulator)
      iex> String.length(buffer)
      5
  """
  def get_buffer(%__MODULE__{} = emulator) do
    # Returns the actual screen buffer struct
    emulator.screen_buffer
  end

  @doc """
  Sets the screen buffer to a new value.
  """
  @spec set_buffer(t(), ScreenBuffer.t()) :: t()
  def set_buffer(%__MODULE__{} = emulator, new_buffer) do
    %{emulator | screen_buffer: new_buffer}
  end

  @doc """
  Clears the screen buffer.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.process_input(emulator, "Hello")
      iex> emulator = Emulator.clear_buffer(emulator)
      iex> Emulator.get_buffer(emulator) # This test might fail until get_buffer is implemented
      ""
  """
  def clear_buffer(%__MODULE__{} = emulator) do
    # Replace undefined clear/1 with a call to new/2 to reset the buffer
    %{
      emulator
      | screen_buffer: ScreenBuffer.new(emulator.width, emulator.height)
    }
  end

  @doc """
  Gets the current cursor position.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.move_cursor(emulator, 10, 5)
      iex> Emulator.get_cursor_position(emulator)
      {10, 5}
  """
  def get_cursor_position(%__MODULE__{} = emulator) do
    emulator.cursor.position
  end

  @doc """
  Gets the current cursor style.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_cursor_style(emulator, :block)
      iex> Emulator.get_cursor_style(emulator)
      :block
  """
  def get_cursor_style(%__MODULE__{} = emulator) do
    emulator.cursor.style
  end

  @doc """
  Gets the current cursor visibility.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_cursor_visible(emulator, false)
      iex> Emulator.get_cursor_visible(emulator)
      false
  """
  def get_cursor_visible(%__MODULE__{} = emulator) do
    emulator.cursor.visible
  end

  @doc """
  Gets the current text style.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_text_style(emulator, %{bold: true})
      iex> Emulator.get_text_style(emulator).bold
      true
  """
  def get_text_style(%__MODULE__{} = emulator) do
    emulator.style
  end

  @doc """
  Gets the current terminal mode state.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> Emulator.get_mode_state(emulator).insert_mode
      false
  """
  def get_mode_state(%__MODULE__{} = emulator) do
    emulator.mode_state
  end

  @doc """
  Gets the current charset state.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> Emulator.get_charset_state(emulator).current_charset
      :ascii
  """
  def get_charset_state(%__MODULE__{} = emulator) do
    emulator.charset_state
  end

  @doc """
  Gets the current scroll region.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_scroll_region(emulator, 5, 15)
      iex> Emulator.get_scroll_region(emulator)
      {5, 15}
  """
  def get_scroll_region(%__MODULE__{} = emulator) do
    emulator.scroll_region
  end

  @doc """
  Gets the terminal dimensions.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> Emulator.get_dimensions(emulator)
      {80, 24}
  """
  def get_dimensions(%__MODULE__{} = emulator) do
    {emulator.screen_buffer.width, emulator.screen_buffer.height}
  end

  @doc """
  Resizes the terminal to the specified dimensions.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.resize(emulator, 100, 30)
      iex> Emulator.get_dimensions(emulator)
      {100, 30}
  """
  def resize(%__MODULE__{} = emulator, width, height) do
    new_buffer = ScreenBuffer.resize(emulator.screen_buffer, width, height)

    if new_buffer do
      %{emulator | screen_buffer: new_buffer}
    else
      Logger.error("Emulator: Failed to resize screen buffer.")
      emulator
    end
  end

  @doc """
  Gets the terminal options.

  ## Examples

      iex> emulator = Emulator.new(80, 24, %{option1: true})
      iex> Emulator.get_options(emulator)
      %{option1: true}
  """
  def get_options(%__MODULE__{} = emulator) do
    emulator.options
  end

  @doc """
  Sets the terminal options.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_options(emulator, %{option1: true})
      iex> Emulator.get_options(emulator)
      %{option1: true}
  """
  def set_options(%__MODULE__{} = emulator, options) do
    %{emulator | options: options}
  end

  @doc """
  Gets the plugin manager.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> Emulator.get_plugin_manager(emulator)
      %Raxol.Plugins.PluginManager{}
  """
  def get_plugin_manager(%__MODULE__{} = emulator) do
    emulator.plugin_manager
  end

  @doc """
  Sets the plugin manager.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> manager = Raxol.Plugins.PluginManager.new()
      iex> emulator = Emulator.set_plugin_manager(emulator, manager)
      iex> Emulator.get_plugin_manager(emulator) == manager
      true
  """
  def set_plugin_manager(%__MODULE__{} = emulator, manager) do
    %{emulator | plugin_manager: manager}
  end

  @doc """
  Gets the memory limit.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> Emulator.get_memory_limit(emulator)
      1000
  """
  def get_memory_limit(%__MODULE__{} = emulator) do
    emulator.memory_limit
  end

  @doc """
  Sets the memory limit.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_memory_limit(emulator, 2000)
      iex> Emulator.get_memory_limit(emulator)
      2000
  """
  def set_memory_limit(%__MODULE__{} = emulator, limit) do
    %{emulator | memory_limit: limit}
  end

  @doc """
  Writes text to the terminal emulator at the current cursor position.
  (Placeholder implementation)
  """
  @spec write(t(), String.t()) :: t()
  def write(%__MODULE__{} = emulator, text) do
    {x, y} = emulator.cursor.position

    # Use write_string/4 which exists in ScreenBuffer
    new_screen_buffer =
      ScreenBuffer.write_string(
        emulator.screen_buffer,
        x,
        y,
        text
        # text_style and charset_state are not used by write_string
      )

    # Calculate new cursor position (simplified: assumes fixed width, basic wrap)
    # TODO: Use CharacterHandling.calculate_string_width for accuracy
    # Simple length for now
    text_length = String.length(text)
    new_x = x + text_length
    new_y = y + div(new_x, emulator.screen_buffer.width)
    final_x = rem(new_x, emulator.screen_buffer.width)

    # Clamp y position to height
    final_y = min(new_y, emulator.screen_buffer.height - 1)

    new_cursor = Movement.move_to_position(emulator.cursor, final_x, final_y)

    %{emulator | screen_buffer: new_screen_buffer, cursor: new_cursor}
  end

  @doc """
  Clears the entire screen buffer and moves the cursor to the home position (0, 0).
  """
  @spec clear_screen(t()) :: t()
  def clear_screen(%__MODULE__{} = emulator) do
    # TODO: Determine correct arguments for ScreenBuffer.clear_region/5 or fix ScreenBuffer.clear/1
    # Placeholder
    updated_buffer = emulator.screen_buffer
    # Move cursor to 0,0 using the Cursor Manager
    updated_cursor = Movement.move_to_position(emulator.cursor, 0, 0)
    %{emulator | screen_buffer: updated_buffer, cursor: updated_cursor}
  end

  @doc """
  Scrolls the terminal buffer by the specified number of lines.
  (Placeholder implementation)
  """
  @spec scroll(t(), integer()) :: t()
  def scroll(%__MODULE__{} = emulator, _lines) do
    # TODO: Implement scrolling logic, updating screen_buffer.
    emulator
  end

  @doc """
  Gets the visible content of the terminal buffer.
  (Placeholder implementation)
  """
  @spec get_visible_content(t()) :: String.t()
  def get_visible_content(%__MODULE__{} = _emulator) do
    # TODO: Implement logic to retrieve visible content from screen_buffer.
    # Placeholder return
    ""
  end

  @doc """
  Sets the character set for a specific designation (G0-G3).
  (Placeholder implementation)
  """
  @spec set_character_set(t(), atom() | String.t(), atom() | String.t()) :: t()
  def set_character_set(%__MODULE__{} = emulator, target_set, charset) do
    new_state =
      CharacterSets.set_designator(emulator.charset_state, target_set, charset)

    %{emulator | charset_state: new_state}
  end

  @doc """
  Invokes a character set (designates it as active GL or GR).
  (Placeholder implementation)
  """
  @spec invoke_character_set(t(), atom() | String.t()) :: t()
  def invoke_character_set(%__MODULE__{} = emulator, gset) do
    new_state = CharacterSets.invoke_designator(emulator.charset_state, gset)
    %{emulator | charset_state: new_state}
  end

  @doc """
  Checks if a specific screen mode is enabled.
  (Placeholder implementation)
  """
  @spec screen_mode_enabled?(t(), atom() | String.t()) :: false
  def screen_mode_enabled?(%__MODULE__{} = _emulator, _mode) do
    # TODO: Implement screen mode checking logic, reading mode_state.
    # Placeholder return
    false
  end

  @doc """
  Switches to the alternate screen buffer.
  (Placeholder implementation)
  """
  @spec switch_to_alternate_buffer(t()) :: t()
  def switch_to_alternate_buffer(%__MODULE__{} = emulator) do
    # TODO: Implement alternate buffer switching logic (DECSCUSR/DECSCA).
    emulator
  end

  @doc """
  Switches back to the main screen buffer.
  (Placeholder implementation)
  """
  @spec switch_to_main_buffer(t()) :: t()
  def switch_to_main_buffer(%__MODULE__{} = emulator) do
    # TODO: Implement main buffer switching logic.
    emulator
  end

  @doc """
  Handles a device status query, returning the appropriate response string.
  (Placeholder implementation)
  """
  @spec handle_device_status_query(t(), String.t()) :: {t(), String.t()}
  def handle_device_status_query(%__MODULE__{} = emulator, _query) do
    # TODO: Implement device status query handling (e.g., cursor position report).
    # Placeholder return
    {emulator, ""}
  end

  @doc """
  Scrolls the content within the scroll region (or entire screen) upwards by N lines.
  New lines at the bottom are filled with the current background color/style.
  """
  @spec scroll_up(t(), non_neg_integer()) :: t()
  def scroll_up(%__MODULE__{} = emulator, lines \\ 1) do
    # Prefix unused vars
    {_scroll_top, _scroll_bottom} =
      case emulator.scroll_region do
        {top, bottom} -> {top, bottom}
        # Default to full screen
        nil -> {0, emulator.screen_buffer.height - 1}
      end

    # Call ScreenBuffer.scroll_up/2
    updated_buffer = ScreenBuffer.scroll_up(emulator.screen_buffer, lines)
    %{emulator | screen_buffer: updated_buffer}
  end

  @doc """
  Scrolls the content within the scroll region (or entire screen) downwards by N lines.
  New lines at the top are filled with the current background color/style.
  """
  @spec scroll_down(t(), non_neg_integer()) :: t()
  def scroll_down(%__MODULE__{} = emulator, lines \\ 1) do
    # Prefix unused vars
    {_scroll_top, _scroll_bottom} =
      case emulator.scroll_region do
        {top, bottom} -> {top, bottom}
        # Default to full screen
        nil -> {0, emulator.screen_buffer.height - 1}
      end

    # Call ScreenBuffer.scroll_down/2
    updated_buffer = ScreenBuffer.scroll_down(emulator.screen_buffer, lines)
    %{emulator | screen_buffer: updated_buffer}
  end

  @doc """
  Gets the cell at the specified coordinates from the screen buffer.
  Returns nil if coordinates are out of bounds.
  """
  @spec get_cell_at(t(), non_neg_integer(), non_neg_integer()) ::
          Raxol.Terminal.Cell.t() | nil
  def get_cell_at(%__MODULE__{} = emulator, x, y) when x >= 0 and y >= 0 do
    ScreenBuffer.get_cell_at(emulator.screen_buffer, x, y)
  end

  # Private functions

  # Map DEC Private Mode codes from escape sequence parser to ScreenModes atoms
  # Based on map from Raxol.Terminal.ANSI
  @dec_mode_map %{
    # DECCKM - Cursor Keys Mode (Application vs. Normal)
    "1" => :cursor_keys,
    # DECCOLM - Column Mode (132 vs. 80)
    "3" => :wide_column,
    # DECSCNM - Screen Mode (Reverse Video)
    "5" => :screen,
    # DECOM - Origin Mode (Relative vs. Absolute)
    "6" => :origin,
    # DECAWM - Autowrap Mode
    "7" => :auto_wrap,
    # DECARM - Auto-repeat Keys Mode
    "8" => :auto_repeat,
    # DECX10MOUSE - X10 Mouse Reporting
    "9" => :mouse_x10,
    # ATT610 - Start/Stop Blinking Cursor (xterm)
    "12" => :cursor_blink,
    # DECTCEM - Text Cursor Enable Mode
    "25" => :cursor_visible,
    # Use Alternate Screen Buffer
    "47" => :alternate_screen,
    # VT200 Mouse Reporting
    "1000" => :mouse_vt200,
    # Button-event tracking
    "1002" => :mouse_button_event,
    # Any-event tracking
    "1003" => :mouse_any_event,
    # FocusIn/FocusOut events
    "1004" => :mouse_focus_event,
    # UTF8 mouse coordinates
    "1005" => :mouse_utf8,
    # SGR mouse coordinates
    "1006" => :mouse_sgr,
    # Alternate Scroll Mode (xterm)
    "1007" => :mouse_alternate_scroll,
    # urxvt mouse mode
    "1015" => :mouse_urxvt,
    # SGR Pixels mouse coordinates
    "1016" => :mouse_sgr_pixels,
    # 8-Bit Meta Key
    "1034" => :interpret_meta,
    # Num Lock Modifier
    "1035" => :num_lock_mod,
    # Meta Key sends ESC prefix
    "1036" => :meta_esc_prefix,
    # Delete key sends DEL
    "1037" => :delete_del,
    # Alt key sends ESC prefix
    "1039" => :alt_esc_prefix,
    # Use Alt Screen Buffer (and clear)
    "1047" => :alternate_screen_and_clear,
    # Save cursor as in DECSC
    "1048" => :save_cursor,
    # Combines 1047 and 1048
    "1049" => :alternate_screen_and_cursor
    # Add more mappings as needed
  }

  # Maps mode codes from the parser (:private or :standard, code string)
  # to internal mode atoms used by ScreenModes.
  defp map_mode_code(:private, code_str) do
    case Map.get(@dec_mode_map, code_str) do
      nil -> {:error, :unknown_private_mode}
      mode_atom -> {:ok, mode_atom}
    end
  end

  defp map_mode_code(:standard, code_str) do
    # TODO: Implement mapping for standard modes if needed
    Logger.warning(
      "Standard mode mapping not implemented for code: #{code_str}"
    )

    {:error, :unsupported_standard_mode}
  end

  defp map_mode_code(type, code_str) do
    Logger.error(
      "Unknown mode type '#{type}' for code '#{code_str}' in map_mode_code"
    )

    {:error, :unknown_mode_type}
  end

  # Pushes relevant emulator state onto the state_stack.
  # Used for DEC Save Cursor (DECSC) like operations.
  defp push_state(%__MODULE__{} = emulator) do
    # Extract the state components needed by TerminalState.save_state/2
    state_to_save = %{
      cursor: emulator.cursor,
      # Assuming style holds the attributes map
      attributes: emulator.style,
      charset_state: emulator.charset_state,
      mode_state: emulator.mode_state,
      scroll_region: emulator.scroll_region
    }

    new_stack = TerminalState.save_state(emulator.state_stack, state_to_save)
    %{emulator | state_stack: new_stack}
  end

  # Clears the scroll region by setting it back to the full screen.
  defp clear_scroll_region(%__MODULE__{} = emulator) do
    # Set scroll region to nil (representing full screen) in ScreenBuffer
    new_buffer =
      ScreenBuffer.set_scroll_region(emulator.screen_buffer, nil, nil)

    if new_buffer do
      # Move cursor to home position (1, 1) after resetting scroll region
      %{emulator | screen_buffer: new_buffer, cursor: {1, 1}}
    else
      Logger.error("Emulator: Failed to clear scroll region in ScreenBuffer.")
      # Return unchanged on failure
      emulator
    end
  end

  defp process_transformed_output(emulator, output) do
    # This function needs to iterate through the output string,
    # handling both regular characters and potential embedded escape sequences.
    # For now, a simplified approach writing char by char.

    {final_emulator, _remaining_output} =
      Enum.reduce(
        String.graphemes(output),
        {emulator, ""},
        fn grapheme, {current_emulator, _acc_output} ->
          {x, y} = current_emulator.cursor.position

          # Combine current text style with hyperlink if active
          current_style = current_emulator.style

          style_with_link =
            if current_emulator.current_hyperlink_url do
              %{
                current_style
                | hyperlink: current_emulator.current_hyperlink_url
              }
            else
              current_style
            end

          updated_buffer =
            ScreenBuffer.write_char(
              current_emulator.screen_buffer,
              x,
              y,
              grapheme,
              # Pass style here
              style_with_link
            )

          # Move cursor forward
          # TODO: Handle wrapping and scrolling
          # Placeholder
          new_x = x + 1

          new_cursor =
            Movement.move_to_position(current_emulator.cursor, new_x, y)

          updated_emulator = %{
            current_emulator
            | screen_buffer: updated_buffer,
              cursor: new_cursor
          }

          # Continue reduction
          {updated_emulator, ""}
        end
      )

    final_emulator
  end

  @spec handle_escape_sequence(t(), atom(), [non_neg_integer()], String.t()) ::
          t()
  def handle_escape_sequence(emulator, command, _params, _intermediate) do
    case command do
      # ... other cases ...
      :restore_state ->
        # TODO: Ensure state_stack is handled correctly
        {restored_stack, _popped_value} =
          Raxol.Terminal.ANSI.TerminalState.restore_state(emulator.state_stack)

        %{emulator | state_stack: restored_stack}
        # ... other cases ...
    end
  end
end
