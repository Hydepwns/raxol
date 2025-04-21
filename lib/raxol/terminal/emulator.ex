defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  Manages the state of the terminal emulator, including screen buffer,
  cursor position, attributes, and modes.
  """

  # alias Raxol.Terminal.ANSI # Unused
  alias Raxol.Terminal.Cell
  # alias Raxol.Terminal.Screen # Unused
  # alias Raxol.Terminal.Style # Unused
  # alias Raxol.Terminal.Modes # Unused
  # alias Raxol.Terminal.Unicode # Unused
  # alias Raxol.Terminal.Buffer.Manager, as: BufferManager # Unused
  # alias Raxol.Terminal.Buffer.Scroll # Unused
  # alias Raxol.Terminal.Emulator # Unused - self alias
  # alias Raxol.Terminal.CommandHistory # Unused
  # alias Raxol.Terminal.Configuration # Unused

  # NOTE: Keep these aliases as they might be used implicitly or are fundamental
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.{Manager, Movement}
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
    memory_limit = Keyword.get(opts, :memorylimit, 1_000_000)
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
        {process_character(emulator, char), ""}

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
  def process_escape_sequence(%Raxol.Terminal.Emulator{} = emulator, sequence) do
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

  # --- Mode Setting ---
  def handle_mode_change(%__MODULE__{} = emulator, type, code, value) do
    mode_atom = lookup_mode_atom(type, code)

    if mode_atom do
      Logger.debug(
        "Emulator: Changing mode: #{type} code #{code} (#{mode_atom}) -> #{value}"
      )

      emulator_after_change =
        if value do
          set_screen_mode(emulator, mode_atom)
        else
          reset_screen_mode(emulator, mode_atom)
        end

      # Specific handling for DECCOLM (Mode 3)
      if mode_atom == :deccolm_132 do
        # Clear screen and home cursor on width change, as per tests
        cleared_emulator = erase_in_display(emulator_after_change, :all)
        move_cursor_absolute(cleared_emulator, 1, 1)
      else
        emulator_after_change
      end
    else
      Logger.warning(
        "Emulator: Unknown mode change requested: #{type} code #{code}"
      )

      # Return unchanged if mode is unknown
      emulator
    end
  end

  # Helper to lookup mode atom from ScreenModes
  defp lookup_mode_atom(:dec_private, code),
    do: ScreenModes.lookup_private(code)

  defp lookup_mode_atom(:standard, code), do: ScreenModes.lookup_standard(code)
  defp lookup_mode_atom(_, _), do: nil

  # Delegate mode setting/resetting to ScreenModes
  defp set_screen_mode(
         %__MODULE__{mode_state: current_mode_state} = emulator,
         mode_atom
       ) do
    new_mode_state =
      ScreenModes.switch_mode(current_mode_state, mode_atom, true)

    %{emulator | mode_state: new_mode_state}
  end

  defp reset_screen_mode(
         %__MODULE__{mode_state: current_mode_state} = emulator,
         mode_atom
       ) do
    new_mode_state =
      ScreenModes.switch_mode(current_mode_state, mode_atom, false)

    %{emulator | mode_state: new_mode_state}
  end

  # --- Command Dispatch (Primary Mechanism) ---

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

      # Add the reset_mode clause here
      {:reset_mode, type, code} ->
        handle_mode_change(emulator, type, code, false)

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
        Logger.warning("Emulator: Unhandled command: #{inspect(command)}")
        # Return unchanged for unhandled commands
        emulator
    end
  end

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
      "Emulator: Erase in Display (type: #{type}) - calling ScreenBuffer.erase_in_display"
    )

    # Call ScreenBuffer.erase_in_display(emulator.screen_buffer, emulator.cursor, type)
    new_buffer =
      ScreenBuffer.erase_in_display(
        emulator.screen_buffer,
        emulator.cursor,
        type
      )

    %{emulator | screen_buffer: new_buffer}
    # emulator
  end

  defp erase_in_line(%__MODULE__{} = emulator, type) do
    Logger.debug(
      "Emulator: Erase in Line (type: #{type}) - calling ScreenBuffer.erase_in_line"
    )

    # Call ScreenBuffer.erase_in_line(emulator.screen_buffer, emulator.cursor, type)
    new_buffer =
      ScreenBuffer.erase_in_line(emulator.screen_buffer, emulator.cursor, type)

    %{emulator | screen_buffer: new_buffer}
    # emulator
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
    # Convert 1-based to 0-based for internal storage
    top_0 = max(0, top - 1)
    bottom_0 = max(0, bottom - 1)

    # TODO: Validate top < bottom?

    Logger.debug(
      "Emulator: Setting Scroll Region (0-based) top=#{top_0}, bottom=#{bottom_0}"
    )

    # Setting the scroll region doesn't modify the buffer contents directly,
    # it affects how scrolling commands operate.
    # The ScreenBuffer might need awareness, but the core state is here.

    # Move cursor to home (0, 0) relative to screen, not scroll region
    new_cursor = Movement.move_to_position(emulator.cursor, 0, 0)

    %{emulator | scroll_region: {top_0, bottom_0}, cursor: new_cursor}
    # Note: ScreenBuffer.set_scroll_region might not be needed if scrolling
    # logic within ScreenBuffer uses emulator.scroll_region.
    # Commenting out buffer modification for now.
    # new_buffer =
    #   ScreenBuffer.set_scroll_region(emulator.screen_buffer, top_0, bottom_0)
    # if new_buffer do
    #   %{emulator | screen_buffer: new_buffer, scroll_region: {top_0, bottom_0}, cursor: new_cursor}
    # else
    #   Logger.error("Emulator: Failed to set scroll region in ScreenBuffer.")
    #   emulator
    # end
  end

  # SGR implementation (simplified example)
  # Alias needed
  alias Raxol.Terminal.ANSI.TextFormatting

  defp apply_sgr(%__MODULE__{} = emulator, params) do
    # Iterate through params, applying each attribute
    new_style =
      Enum.reduce(params, emulator.style, fn param, current_style ->
        # TODO: Map SGR parameter (integer) to attribute atom if needed by apply_attribute
        # Assuming TextFormatting.apply_attribute/2 takes the atom directly
        # Need to map integer codes (e.g., 1 for bold, 30-37 for colors) to atoms (:bold, :black, etc.)
        # Placeholder for mapping function
        sgr_atom = map_sgr_param_to_atom(param)
        TextFormatting.apply_attribute(current_style, sgr_atom)
      end)

    %{emulator | style: new_style}
  end

  # Placeholder function to map SGR integer codes to atoms
  # TODO: Implement this mapping fully based on SGR standards
  defp map_sgr_param_to_atom(0), do: :reset
  defp map_sgr_param_to_atom(1), do: :bold
  defp map_sgr_param_to_atom(4), do: :underline
  defp map_sgr_param_to_atom(5), do: :blink
  defp map_sgr_param_to_atom(7), do: :reverse
  # Often resets bold/faint
  defp map_sgr_param_to_atom(22), do: :normal_intensity
  defp map_sgr_param_to_atom(24), do: :no_underline
  defp map_sgr_param_to_atom(25), do: :no_blink
  defp map_sgr_param_to_atom(27), do: :no_reverse

  defp map_sgr_param_to_atom(n) when n >= 30 and n <= 37,
    do: map_color_code_to_atom(n)

  # Default foreground
  defp map_sgr_param_to_atom(39), do: :default_fg

  defp map_sgr_param_to_atom(n) when n >= 40 and n <= 47,
    do: map_color_code_to_atom(n)

  # Default background
  defp map_sgr_param_to_atom(49), do: :default_bg
  # Bright foreground
  defp map_sgr_param_to_atom(n) when n >= 90 and n <= 97,
    do: map_color_code_to_atom(n)

  # Bright background
  defp map_sgr_param_to_atom(n) when n >= 100 and n <= 107,
    do: map_color_code_to_atom(n)

  # Ignore unknown codes for now
  defp map_sgr_param_to_atom(_), do: :unknown

  defp map_color_code_to_atom(code) do
    case code do
      30 -> :black
      40 -> :bg_black
      90 -> :bright_black
      100 -> :bg_bright_black
      31 -> :red
      41 -> :bg_red
      91 -> :bright_red
      101 -> :bg_bright_red
      32 -> :green
      42 -> :bg_green
      92 -> :bright_green
      102 -> :bg_bright_green
      33 -> :yellow
      43 -> :bg_yellow
      93 -> :bright_yellow
      103 -> :bg_bright_yellow
      34 -> :blue
      44 -> :bg_blue
      94 -> :bright_blue
      104 -> :bg_bright_blue
      35 -> :magenta
      45 -> :bg_magenta
      95 -> :bright_magenta
      105 -> :bg_bright_magenta
      36 -> :cyan
      46 -> :bg_cyan
      96 -> :bright_cyan
      106 -> :bg_bright_cyan
      37 -> :white
      47 -> :bg_white
      97 -> :bright_white
      107 -> :bg_bright_white
      _ -> :unknown
    end
  end

  # Charset implementation (simplified)
  defp designate_charset(%__MODULE__{} = emulator, g, _charset) do
    # G must be 0, 1, 2, or 3
    # Default to G0
    g_index = if g in [0, 1, 2, 3], do: g, else: 0

    # TODO: Map `charset` string (e.g., \"B\", \"0\") to the correct charset atom
    # For now, assuming a direct mapping or placeholder
    # Placeholder, use atom directly
    charset_atom = :us_ascii

    new_charset_state =
      CharacterSets.switch_charset(
        emulator.charset_state,
        g_index,
        charset_atom
      )

    %{emulator | charset_state: new_charset_state}
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
            style: new_text_style,
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
      width: emulator.screen_buffer.width,
      height: emulator.screen_buffer.height
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
      | screen_buffer:
          ScreenBuffer.new(
            emulator.screen_buffer.width,
            emulator.screen_buffer.height
          )
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
      CharacterSets.switch_charset(emulator.charset_state, target_set, charset)

    %{emulator | charset_state: new_state}
  end

  @doc """
  Invokes a character set (designates it as active GL or GR).
  (Placeholder implementation)
  """
  @spec invoke_character_set(t(), atom() | String.t()) :: t()
  def invoke_character_set(%__MODULE__{} = emulator, _gset) do
    # Placeholder based on common usage (LS0/LS1/etc.)
    target_set = :g0
    new_state = CharacterSets.set_gl(emulator.charset_state, target_set)
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

  # --- Internal Helpers ---

  # Helper to get current buffer dimensions
  defp buffer_dimensions(%__MODULE__{
         screen_buffer: %ScreenBuffer{width: w, height: h}
       }) do
    {w, h}
  end

  defp buffer_dimensions(%__MODULE__{}) do
    Logger.warning(
      "Emulator: Attempted to get dimensions from invalid screen_buffer."
    )

    # Default or error dimensions
    {0, 0}
  end

  # Helper to update a cell in the buffer
  defp update_cell(%__MODULE__{} = emulator, {line, col}, cell) do
    # Extract char and style from the Cell struct
    char_to_write = cell.char
    style_to_apply = cell.style

    # Call ScreenBuffer.write_char/5 instead of the non-existent update_cell/3
    new_screen_buffer =
      ScreenBuffer.write_char(
        emulator.screen_buffer,
        col,
        line,
        char_to_write,
        style_to_apply
      )

    # Update the emulator state with the modified screen buffer
    %{emulator | screen_buffer: new_screen_buffer}
  end

  # --- Character Processing ---

  defp process_character(%__MODULE__{} = emulator, char) when is_binary(char) do
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

    if line >= height or col >= width do
      Logger.warning(
        "Emulator: Cursor %{line},%{col} out of bounds %{width}x%{height}. Ignoring char '%{char}'.",
        line: line + 1,
        col: col + 1,
        width: width,
        height: height,
        char: char
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
end
