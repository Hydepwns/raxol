defmodule Raxol.Terminal.Emulator do
  @moduledoc """
  Terminal emulator module that handles screen buffer management, cursor positioning,
  input handling, character set management, screen modes, and terminal state management.
  """

  alias Raxol.Terminal.{Cell, ScreenBuffer, Input}
  alias Raxol.Terminal.ANSI.{CharacterSets, ScreenModes, TerminalState, TextFormatting}
  alias Raxol.Plugins.PluginManager

  @type t :: %__MODULE__{
    width: non_neg_integer(),
    height: non_neg_integer(),
    screen_buffer: list(list(String.t())),
    cursor: {non_neg_integer(), non_neg_integer()},
    saved_cursor: {non_neg_integer(), non_neg_integer()} | nil,
    scroll_region: {non_neg_integer(), non_neg_integer()} | nil,
    text_style: TextFormatting.text_style(),
    memory_limit: non_neg_integer(),
    charset_state: CharacterSets.charset_state(),
    mode_state: ScreenModes.mode_state(),
    state_stack: TerminalState.state_stack(),
    plugin_manager: PluginManager.t()
  }

  defstruct [
    :width,
    :height,
    :screen_buffer,
    :cursor,
    :saved_cursor,
    :scroll_region,
    :text_style,
    :memory_limit,
    :charset_state,
    :mode_state,
    :state_stack,
    :plugin_manager
  ]

  @doc """
  Creates a new terminal emulator with the specified dimensions.
  """
  def new(width \\ 80, height \\ 24, memory_limit \\ 1000) do
    %__MODULE__{
      width: width,
      height: height,
      screen_buffer: List.duplicate(List.duplicate(" ", width), height),
      cursor: {0, 0},
      saved_cursor: nil,
      scroll_region: nil,
      text_style: TextFormatting.new(),
      memory_limit: memory_limit,
      charset_state: CharacterSets.new(),
      mode_state: ScreenModes.new(),
      state_stack: TerminalState.new(),
      plugin_manager: PluginManager.new()
    }
  end

  @doc """
  Processes input for the terminal emulator.
  
  ## Examples
  
      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.process_input(emulator, "a")
      iex> emulator.input.buffer
      "a"
  """
  def process_input(%__MODULE__{} = emulator, input) do
    # Process input through plugins first
    case PluginManager.process_input(emulator.plugin_manager, input) do
      {:ok, updated_manager} ->
        emulator = %{emulator | plugin_manager: updated_manager}
        %{emulator | input: Input.process_keyboard(emulator.input, input)}
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
  Writes a character at the current cursor position.
  The character is translated according to the current character set.
  
  ## Examples
  
      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.write_char(emulator, "a")
      iex> cell = ScreenBuffer.get_cell(emulator.screen_buffer, 0, 0)
      iex> Cell.get_char(cell)
      "a"
  """
  def write_char(%__MODULE__{} = emulator, char) do
    translated_char = CharacterSets.translate_char(emulator.charset_state, char)
    
    # Process output through plugins
    case PluginManager.process_output(emulator.plugin_manager, translated_char) do
      {:ok, updated_manager, transformed_output} ->
        emulator = %{emulator | plugin_manager: updated_manager}
        cell = Cell.new(transformed_output, emulator.text_style)
        new_screen_buffer = ScreenBuffer.set_cell(emulator.screen_buffer, emulator.cursor[0], emulator.cursor[1], cell)
        new_cursor = move_cursor_right(emulator.cursor, emulator.width)
        
        %{emulator |
          screen_buffer: new_screen_buffer,
          cursor: new_cursor
        }
      {:ok, updated_manager} ->
        emulator = %{emulator | plugin_manager: updated_manager}
        cell = Cell.new(translated_char, emulator.text_style)
        new_screen_buffer = ScreenBuffer.set_cell(emulator.screen_buffer, emulator.cursor[0], emulator.cursor[1], cell)
        new_cursor = move_cursor_right(emulator.cursor, emulator.width)
        
        %{emulator |
          screen_buffer: new_screen_buffer,
          cursor: new_cursor
        }
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Writes a string to the terminal at the current cursor position.
  Each character is processed individually.
  
  ## Examples
  
      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.write_string(emulator, "Hello")
      iex> emulator.cursor
      {5, 0}
  """
  def write_string(%__MODULE__{} = emulator, string) when is_binary(string) do
    Enum.reduce(String.graphemes(string), emulator, fn char, acc ->
      case write_char(acc, char) do
        {:error, reason} -> {:error, reason}
        updated_emulator -> updated_emulator
      end
    end)
  end

  @doc """
  Moves the cursor to the specified position.
  
  ## Examples
  
      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.move_cursor(emulator, 10, 5)
      iex> emulator.cursor
      {10, 5}
  """
  def move_cursor(%__MODULE__{} = emulator, x, y) do
    x = max(0, min(x, emulator.width - 1))
    y = max(0, min(y, emulator.height - 1))
    
    %{emulator | cursor: {x, y}}
  end

  @doc """
  Saves the current cursor position.
  
  ## Examples
  
      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.move_cursor(emulator, 10, 5)
      iex> emulator = Emulator.save_cursor(emulator)
      iex> emulator.saved_cursor
      {10, 5}
  """
  def save_cursor(%__MODULE__{} = emulator) do
    %{emulator | saved_cursor: emulator.cursor}
  end

  @doc """
  Restores the saved cursor position.
  
  ## Examples
  
      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.move_cursor(emulator, 10, 5)
      iex> emulator = Emulator.save_cursor(emulator)
      iex> emulator = Emulator.move_cursor(emulator, 0, 0)
      iex> emulator = Emulator.restore_cursor(emulator)
      iex> emulator.cursor
      {10, 5}
  """
  def restore_cursor(%__MODULE__{} = emulator) do
    case emulator.saved_cursor do
      nil -> emulator
      {x, y} -> move_cursor(emulator, x, y)
    end
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
  Sets a text attribute in the current style.
  """
  def set_attribute(%__MODULE__{} = emulator, attribute) when is_atom(attribute) do
    %{emulator | text_style: TextFormatting.set_attribute(emulator.text_style, attribute)}
  end

  @doc """
  Removes a text attribute from the current style.
  """
  def remove_attribute(%__MODULE__{} = emulator, attribute) when is_atom(attribute) do
    %{emulator | text_style: TextFormatting.remove_attribute(emulator.text_style, attribute)}
  end

  @doc """
  Sets a text decoration in the current style.
  """
  def set_decoration(%__MODULE__{} = emulator, decoration) when is_atom(decoration) do
    %{emulator | text_style: TextFormatting.set_decoration(emulator.text_style, decoration)}
  end

  @doc """
  Removes a text decoration from the current style.
  """
  def remove_decoration(%__MODULE__{} = emulator, decoration) when is_atom(decoration) do
    %{emulator | text_style: TextFormatting.remove_decoration(emulator.text_style, decoration)}
  end

  @doc """
  Sets the foreground color.
  """
  def set_foreground(%__MODULE__{} = emulator, color) when is_tuple(color) or is_atom(color) do
    %{emulator | text_style: TextFormatting.set_foreground(emulator.text_style, color)}
  end

  @doc """
  Sets the background color.
  """
  def set_background(%__MODULE__{} = emulator, color) when is_tuple(color) or is_atom(color) do
    %{emulator | text_style: TextFormatting.set_background(emulator.text_style, color)}
  end

  @doc """
  Sets double-width mode.
  """
  def set_double_width(%__MODULE__{} = emulator, enabled) when is_boolean(enabled) do
    %{emulator | text_style: TextFormatting.set_double_width(emulator.text_style, enabled)}
  end

  @doc """
  Sets double-height mode.
  """
  def set_double_height(%__MODULE__{} = emulator, enabled) when is_boolean(enabled) do
    %{emulator | text_style: TextFormatting.set_double_height(emulator.text_style, enabled)}
  end

  @doc """
  Resets all text formatting to default values.
  """
  def reset_text_formatting(%__MODULE__{} = emulator) do
    %{emulator | text_style: TextFormatting.reset(emulator.text_style)}
  end

  @doc """
  Switches the specified character set to the given charset.
  
  ## Examples
  
      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.switch_charset(emulator, :g0, :latin1)
      iex> emulator.charset_state.g0
      :latin1
  """
  def switch_charset(%__MODULE__{} = emulator, set, charset) do
    charset_state = CharacterSets.switch_charset(emulator.charset_state, set, charset)
    %{emulator | charset_state: charset_state}
  end

  @doc """
  Sets the GL (left) character set.
  
  ## Examples
  
      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_gl_charset(emulator, :g2)
      iex> emulator.charset_state.gl
      :g2
  """
  def set_gl_charset(%__MODULE__{} = emulator, set) do
    charset_state = CharacterSets.set_gl(emulator.charset_state, set)
    %{emulator | charset_state: charset_state}
  end

  @doc """
  Sets the GR (right) character set.
  
  ## Examples
  
      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_gr_charset(emulator, :g3)
      iex> emulator.charset_state.gr
      :g3
  """
  def set_gr_charset(%__MODULE__{} = emulator, set) do
    charset_state = CharacterSets.set_gr(emulator.charset_state, set)
    %{emulator | charset_state: charset_state}
  end

  @doc """
  Sets the single shift character set.
  
  ## Examples
  
      iex> emulator = Emulator.new(80, 24)
      iex> emulator = Emulator.set_single_shift(emulator, :g2)
      iex> emulator.charset_state.single_shift
      :g2
  """
  def set_single_shift(%__MODULE__{} = emulator, set) do
    charset_state = CharacterSets.set_single_shift(emulator.charset_state, set)
    %{emulator | charset_state: charset_state}
  end

  @doc """
  Switches between normal and alternate screen buffer modes.
  """
  @spec switch_screen_mode(t(), ScreenModes.screen_mode()) :: t()
  def switch_screen_mode(%__MODULE__{} = emulator, mode) do
    current_state = %{
      cells: emulator.screen_buffer,
      cursor: emulator.cursor,
      attributes: emulator.text_style,
      scroll_region: emulator.scroll_region
    }

    {new_mode_state, new_buffer_state} = ScreenModes.switch_mode(emulator.mode_state, mode, current_state)

    %{emulator |
      mode_state: new_mode_state,
      screen_buffer: new_buffer_state.cells,
      cursor: new_buffer_state.cursor,
      text_style: new_buffer_state.attributes,
      scroll_region: new_buffer_state.scroll_region
    }
  end

  @doc """
  Sets a specific screen mode.
  """
  @spec set_screen_mode(t(), atom()) :: t()
  def set_screen_mode(%__MODULE__{} = emulator, mode) do
    %{emulator | mode_state: ScreenModes.set_mode(emulator.mode_state, mode)}
  end

  @doc """
  Resets a specific screen mode.
  """
  @spec reset_screen_mode(t(), atom()) :: t()
  def reset_screen_mode(%__MODULE__{} = emulator, mode) do
    %{emulator | mode_state: ScreenModes.reset_mode(emulator.mode_state, mode)}
  end

  @doc """
  Gets the current screen mode.
  """
  @spec get_screen_mode(t()) :: ScreenModes.screen_mode()
  def get_screen_mode(%__MODULE__{} = emulator) do
    ScreenModes.get_mode(emulator.mode_state)
  end

  @doc """
  Checks if a specific screen mode is enabled.
  """
  @spec screen_mode_enabled?(t(), atom()) :: boolean()
  def screen_mode_enabled?(%__MODULE__{} = emulator, mode) do
    ScreenModes.mode_enabled?(emulator.mode_state, mode)
  end

  @doc """
  Processes an ANSI escape sequence.
  """
  @spec process_escape(t(), ANSI.escape_sequence()) :: t()
  def process_escape(emulator, escape) do
    case escape do
      {:charset_switch, set, charset} ->
        %{emulator | charset_state: CharacterSets.switch_charset(emulator.charset_state, set, charset)}
      {:charset_gl, set} ->
        %{emulator | charset_state: CharacterSets.set_gl(emulator.charset_state, set)}
      {:charset_gr, set} ->
        %{emulator | charset_state: CharacterSets.set_gr(emulator.charset_state, set)}
      {:single_shift, set} ->
        %{emulator | charset_state: CharacterSets.set_single_shift(emulator.charset_state, set)}
      {:lock_shift, set} ->
        %{emulator | charset_state: CharacterSets.set_gl(emulator.charset_state, set) |> Map.put(:locked_shift, true)}
      {:unlock_shift} ->
        %{emulator | charset_state: Map.put(emulator.charset_state, :locked_shift, false)}
      {:screen_mode, mode} ->
        switch_screen_mode(emulator, mode)
      {:set_mode, mode} ->
        set_screen_mode(emulator, mode)
      {:reset_mode, mode} ->
        reset_screen_mode(emulator, mode)
      _ ->
        emulator
    end
  end

  @doc """
  Saves the current terminal state to the state stack.
  """
  def save_state(emulator) do
    state = %{
      cursor: emulator.cursor,
      attributes: emulator.text_style,
      charset_state: emulator.charset_state,
      mode_state: emulator.mode_state,
      scroll_region: emulator.scroll_region
    }

    %{emulator | state_stack: TerminalState.save_state(emulator.state_stack, state)}
  end

  @doc """
  Restores the most recently saved terminal state from the state stack.
  Returns {emulator, nil} if the stack is empty.
  """
  def restore_state(emulator) do
    {new_stack, state} = TerminalState.restore_state(emulator.state_stack)

    if state do
      emulator = %{emulator |
        state_stack: new_stack,
        cursor: state.cursor,
        text_style: state.attributes,
        charset_state: state.charset_state,
        mode_state: state.mode_state,
        scroll_region: state.scroll_region
      }
      {emulator, state}
    else
      {emulator, nil}
    end
  end

  @doc """
  Clears the terminal state stack.
  """
  def clear_state_stack(emulator) do
    %{emulator | state_stack: TerminalState.clear_state(emulator.state_stack)}
  end

  @doc """
  Returns the current terminal state stack.
  """
  def get_state_stack(emulator) do
    TerminalState.get_state_stack(emulator.state_stack)
  end

  @doc """
  Checks if the terminal state stack is empty.
  """
  def state_stack_empty?(emulator) do
    TerminalState.empty?(emulator.state_stack)
  end

  @doc """
  Returns the number of saved states in the terminal state stack.
  """
  def state_stack_count(emulator) do
    TerminalState.count(emulator.state_stack)
  end

  @doc """
  Loads a plugin into the terminal emulator.
  """
  def load_plugin(%__MODULE__{} = emulator, module, config \\ %{}) when is_atom(module) do
    case PluginManager.load_plugin(emulator.plugin_manager, module, config) do
      {:ok, updated_manager} ->
        %{emulator | plugin_manager: updated_manager}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Unloads a plugin from the terminal emulator.
  """
  def unload_plugin(%__MODULE__{} = emulator, name) when is_binary(name) do
    case PluginManager.unload_plugin(emulator.plugin_manager, name) do
      {:ok, updated_manager} ->
        %{emulator | plugin_manager: updated_manager}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Enables a plugin in the terminal emulator.
  """
  def enable_plugin(%__MODULE__{} = emulator, name) when is_binary(name) do
    case PluginManager.enable_plugin(emulator.plugin_manager, name) do
      {:ok, updated_manager} ->
        %{emulator | plugin_manager: updated_manager}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Disables a plugin in the terminal emulator.
  """
  def disable_plugin(%__MODULE__{} = emulator, name) when is_binary(name) do
    case PluginManager.disable_plugin(emulator.plugin_manager, name) do
      {:ok, updated_manager} ->
        %{emulator | plugin_manager: updated_manager}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets a list of all loaded plugins.
  """
  def list_plugins(%__MODULE__{} = emulator) do
    PluginManager.list_plugins(emulator.plugin_manager)
  end

  @doc """
  Gets a plugin by name.
  """
  def get_plugin(%__MODULE__{} = emulator, name) when is_binary(name) do
    PluginManager.get_plugin(emulator.plugin_manager, name)
  end

  # Private functions

  defp move_cursor_right({x, y}, width) do
    if x + 1 >= width do
      {0, y + 1}
    else
      {x + 1, y}
    end
  end
end 