defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  The Raxol Terminal Emulator module provides a terminal emulation layer that
  handles screen buffer management, cursor positioning, input handling, and
  terminal state management.

  Note: When running in certain environments, stdin may be excluded from Credo analysis
  due to how it's processed. This is expected behavior and doesn't affect functionality.
  """

  alias Raxol.Terminal.{Cell, ScreenBuffer, Input}
  alias Raxol.Terminal.ANSI.{CharacterSets, ScreenModes, TerminalState, TextFormatting}
  alias Raxol.Terminal.Cursor.{Manager, Movement, Style}
  alias Raxol.Terminal.Modes
  alias Raxol.Terminal.EscapeSequence
  alias Raxol.Plugins.PluginManager

  @type t :: %__MODULE__{
    width: non_neg_integer(),
    height: non_neg_integer(),
    screen_buffer: ScreenBuffer.t(),
    cursor: Manager.t(),
    scroll_region: {non_neg_integer(), non_neg_integer()} | nil,
    text_style: TextFormatting.text_style(),
    memory_limit: non_neg_integer(),
    charset_state: CharacterSets.charset_state(),
    mode_state: Modes.mode_state(),
    state_stack: TerminalState.state_stack(),
    plugin_manager: PluginManager.t(),
    options: map()
  }

  defstruct [
    :width,
    :height,
    :screen_buffer,
    :cursor,
    :scroll_region,
    :text_style,
    :memory_limit,
    :charset_state,
    :mode_state,
    :state_stack,
    :plugin_manager,
    :options
  ]

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
  def new(width, height, options \\ %{}) do
    %__MODULE__{
      width: width,
      height: height,
      screen_buffer: ScreenBuffer.new(width, height),
      cursor: Manager.new(),
      scroll_region: nil,
      text_style: TextFormatting.new(),
      memory_limit: 1000,
      charset_state: CharacterSets.new(),
      mode_state: Modes.new(),
      state_stack: TerminalState.new(),
      plugin_manager: PluginManager.new(),
      options: options
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
  @spec process_input(t(), String.t()) :: {t(), String.t()}
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
    {cursor, mode_state, message} = EscapeSequence.process_sequence(
      emulator.cursor,
      emulator.mode_state,
      sequence
    )

    # Update cursor visibility based on terminal mode
    cursor = if Map.get(mode_state, :cursor_visible, true) do
      Style.show(cursor)
    else
      Style.hide(cursor)
    end

    # Update cursor style based on terminal mode
    cursor = if Map.get(mode_state, :block_cursor, false) do
      Style.set_block(cursor)
    else
      Style.set_underline(cursor)
    end

    %{emulator |
      cursor: cursor,
      mode_state: mode_state
    }
  end

  @doc """
  Processes a regular character, updating the screen buffer and cursor position.

  ## Examples

      iex> emulator = Raxol.Terminal.Emulator.new(80, 24, %{})
      iex> {emulator, _} = Raxol.Terminal.Emulator.process_character(emulator, "a")
      iex> emulator.cursor.position
      {1, 0}

  """
  @spec process_character(t(), String.t()) :: {t(), String.t()}
  def process_character(emulator, char) do
    translated_char = CharacterSets.translate_char(emulator.charset_state, char)

    # Process output through plugins
    case PluginManager.process_output(emulator.plugin_manager, translated_char) do
      {:ok, updated_manager, transformed_output} ->
        emulator = %{emulator | plugin_manager: updated_manager}
        process_transformed_output(emulator, transformed_output)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Processes mouse input for the terminal emulator.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.process_mouse(emulator, {:click, 1, 2, 1})
      iex> emulator.input.buffer
      ""
  """
  def process_mouse(%__MODULE__{} = emulator, event) do
    # Process mouse event through plugins first
    case PluginManager.process_mouse(emulator.plugin_manager, event) do
      {:ok, updated_manager} ->
        emulator = %{emulator | plugin_manager: updated_manager}
        %{emulator | input: Input.process_mouse(emulator.input, event)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Moves the cursor to the specified position.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.move_cursor(emulator, 10, 5)
      iex> emulator.cursor.position
      {10, 5}
  """
  def move_cursor(%__MODULE__{} = emulator, x, y) do
    # Ensure cursor stays within bounds
    x = max(0, min(x, emulator.width - 1))
    y = max(0, min(y, emulator.height - 1))

    %{emulator | cursor: Movement.move_to_position(emulator.cursor, x, y)}
  end

  @doc """
  Moves the cursor up by the specified number of lines.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.move_cursor_up(emulator, 2)
      iex> emulator.cursor.position
      {0, 0}  # Already at top, no change
  """
  def move_cursor_up(%__MODULE__{} = emulator, n \\ 1) do
    %{emulator | cursor: Movement.move_up(emulator.cursor, n)}
  end

  @doc """
  Moves the cursor down by the specified number of lines.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.move_cursor_down(emulator, 2)
      iex> emulator.cursor.position
      {0, 2}
  """
  def move_cursor_down(%__MODULE__{} = emulator, n \\ 1) do
    %{emulator | cursor: Movement.move_down(emulator.cursor, n)}
  end

  @doc """
  Moves the cursor left by the specified number of columns.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.move_cursor(emulator, 5, 0)
      iex> emulator = Emulator.move_cursor_left(emulator, 2)
      iex> emulator.cursor.position
      {3, 0}
  """
  def move_cursor_left(%__MODULE__{} = emulator, n \\ 1) do
    %{emulator | cursor: Movement.move_left(emulator.cursor, n)}
  end

  @doc """
  Moves the cursor right by the specified number of columns.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.move_cursor_right(emulator, 5)
      iex> emulator.cursor.position
      {5, 0}
  """
  def move_cursor_right(%__MODULE__{} = emulator, n \\ 1) do
    %{emulator | cursor: Movement.move_right(emulator.cursor, n)}
  end

  @doc """
  Sets the cursor style.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_cursor_style(emulator, :block)
      iex> emulator.cursor.style
      :block
  """
  def set_cursor_style(%__MODULE__{} = emulator, style) do
    %{emulator | cursor: Style.set_style(emulator.cursor, style)}
  end

  @doc """
  Shows or hides the cursor.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_cursor_visible(emulator, false)
      iex> emulator.cursor.visible
      false
  """
  def set_cursor_visible(%__MODULE__{} = emulator, visible) do
    %{emulator | cursor: Style.set_visible(emulator.cursor, visible)}
  end

  @doc """
  Sets the scroll region.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_scroll_region(emulator, 5, 15)
      iex> emulator.scroll_region
      {5, 15}
  """
  def set_scroll_region(%__MODULE__{} = emulator, top, bottom) do
    %{emulator | scroll_region: {top, bottom}}
  end

  @doc """
  Clears the scroll region.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_scroll_region(emulator, 5, 15)
      iex> emulator = Emulator.clear_scroll_region(emulator)
      iex> emulator.scroll_region
      nil
  """
  def clear_scroll_region(%__MODULE__{} = emulator) do
    %{emulator | scroll_region: nil}
  end

  @doc """
  Sets the text style.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_text_style(emulator, %{bold: true, foreground: :red})
      iex> emulator.text_style.bold
      true
      iex> emulator.text_style.foreground
      :red
  """
  def set_text_style(%__MODULE__{} = emulator, style) do
    %{emulator | text_style: TextFormatting.merge(emulator.text_style, style)}
  end

  @doc """
  Resets the text style to default.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_text_style(emulator, %{bold: true})
      iex> emulator = Emulator.reset_text_style(emulator)
      iex> emulator.text_style.bold
      false
  """
  def reset_text_style(%__MODULE__{} = emulator) do
    %{emulator | text_style: TextFormatting.new()}
  end

  @doc """
  Pushes the current terminal state onto the stack.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.push_state(emulator)
      iex> length(emulator.state_stack.states)
      1
  """
  def push_state(%__MODULE__{} = emulator) do
    %{emulator | state_stack: TerminalState.push(emulator.state_stack)}
  end

  @doc """
  Pops the terminal state from the stack.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.push_state(emulator)
      iex> emulator = Emulator.pop_state(emulator)
      iex> length(emulator.state_stack.states)
      0
  """
  def pop_state(%__MODULE__{} = emulator) do
    case TerminalState.pop(emulator.state_stack) do
      {:ok, state_stack} ->
        %{emulator | state_stack: state_stack}
      :error ->
        emulator
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
    TerminalState.current(emulator.state_stack)
  end

  @doc """
  Sets the terminal state.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_state(emulator, %{cursor_visible: false})
      iex> emulator.cursor.visible
      false
  """
  def set_state(%__MODULE__{} = emulator, state) do
    %{emulator | state_stack: TerminalState.set_current(emulator.state_stack, state)}
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
    ScreenBuffer.get_contents(emulator.screen_buffer)
  end

  @doc """
  Clears the screen buffer.

  ## Examples

      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.process_input(emulator, "Hello")
      iex> emulator = Emulator.clear_buffer(emulator)
      iex> Emulator.get_buffer(emulator)
      ""
  """
  def clear_buffer(%__MODULE__{} = emulator) do
    %{emulator | screen_buffer: ScreenBuffer.clear(emulator.screen_buffer)}
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
    emulator.text_style
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
    {emulator.width, emulator.height}
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
    %{emulator |
      width: width,
      height: height,
      screen_buffer: ScreenBuffer.resize(emulator.screen_buffer, width, height)
    }
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
    new_screen_buffer = ScreenBuffer.write_string(
      emulator.screen_buffer,
      x, y,
      text
      # text_style and charset_state are not used by write_string
    )

    # Calculate new cursor position (simplified: assumes fixed width, basic wrap)
    # TODO: Use CharacterHandling.calculate_string_width for accuracy
    text_length = String.length(text) # Simple length for now
    new_x = x + text_length
    new_y = y + div(new_x, emulator.width)
    final_x = rem(new_x, emulator.width)

    # Clamp y position to height
    final_y = min(new_y, emulator.height - 1)

    new_cursor = Movement.move_to_position(emulator.cursor, final_x, final_y)

    %{emulator |
      screen_buffer: new_screen_buffer,
      cursor: new_cursor
    }
  end

  @doc """
  Clears the terminal screen.
  (Placeholder implementation)
  """
  @spec clear_screen(t()) :: t()
  def clear_screen(%__MODULE__{} = emulator) do
    # TODO: Implement screen clearing, potentially calling ScreenBuffer.clear
    emulator
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
    "" # Placeholder return
  end

  @doc """
  Sets the character set for a specific designation (G0-G3).
  (Placeholder implementation)
  """
  @spec set_character_set(t(), atom() | String.t(), atom() | String.t()) :: t()
  def set_character_set(%__MODULE__{} = emulator, _gset, _charset) do
    # TODO: Implement character set logic, updating charset_state.
    emulator
  end

  @doc """
  Invokes a character set (designates it as active GL or GR).
  (Placeholder implementation)
  """
  @spec invoke_character_set(t(), atom() | String.t()) :: t()
  def invoke_character_set(%__MODULE__{} = emulator, _gset) do
    # TODO: Implement character set invocation logic, updating charset_state.
    emulator
  end

  @doc """
  Enables a specific screen mode.
  (Placeholder implementation)
  """
  @spec set_screen_mode(t(), atom() | String.t()) :: t()
  def set_screen_mode(%__MODULE__{} = emulator, _mode) do
    # TODO: Implement screen mode setting logic, updating mode_state.
    emulator
  end

  @doc """
  Disables (resets) a specific screen mode.
  (Placeholder implementation)
  """
  @spec reset_screen_mode(t(), atom() | String.t()) :: t()
  def reset_screen_mode(%__MODULE__{} = emulator, _mode) do
    # TODO: Implement screen mode resetting logic, updating mode_state.
    emulator
  end

  @doc """
  Checks if a specific screen mode is enabled.
  (Placeholder implementation)
  """
  @spec screen_mode_enabled?(t(), atom() | String.t()) :: boolean()
  def screen_mode_enabled?(%__MODULE__{} = _emulator, _mode) do
    # TODO: Implement screen mode checking logic, reading mode_state.
    false # Placeholder return
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
    {emulator, ""} # Placeholder return
  end

  # Private functions

  defp process_transformed_output(emulator, output) do
    # Process the transformed output
    case output do
      "" ->
        {emulator, ""}
      _ ->
        # Update the screen buffer with the output
        {cursor_x, cursor_y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)
        screen_buffer = ScreenBuffer.write_string(emulator.screen_buffer, cursor_x, cursor_y, output)
        # Move the cursor
        cursor = Movement.move_right(emulator.cursor, String.length(output))
        {%{emulator | screen_buffer: screen_buffer, cursor: cursor}, ""}
    end
  end
end
