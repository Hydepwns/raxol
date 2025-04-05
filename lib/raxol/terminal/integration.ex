defmodule Raxol.Terminal.Integration do
  @moduledoc """
  Integration module for connecting the buffer manager, scroll buffer, and cursor manager
  with the terminal emulator.
  
  This module provides functions for:
  - Initializing the integrated terminal system
  - Synchronizing buffer and cursor state
  - Handling terminal operations with the integrated components
  - Managing memory and performance optimizations
  - Command history management
  """

  alias Raxol.Terminal.Buffer.{Manager, Scroll}
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.CommandHistory
  alias Raxol.Terminal.Configuration

  @type t :: %__MODULE__{
    emulator: Emulator.t(),
    buffer_manager: Manager.t(),
    scroll_buffer: Scroll.t(),
    cursor_manager: CursorManager.t(),
    command_history: CommandHistory.t(),
    config: Configuration.t(),
    memory_limit: non_neg_integer(),
    last_cleanup: integer()
  }

  defstruct [
    :emulator,
    :buffer_manager,
    :scroll_buffer,
    :cursor_manager,
    :command_history,
    :config,
    :memory_limit,
    :last_cleanup
  ]

  @default_memory_limit 50 * 1024 * 1024  # 50MB
  @cleanup_interval 60 * 1000  # 1 minute

  @doc """
  Creates a new integrated terminal system with the specified dimensions.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration.emulator.width
      80
      iex> integration.emulator.height
      24
  """
  def new(width, height, opts \\ []) do
    config = Configuration.new(opts)
    emulator = Emulator.new(width, height)
    buffer_manager = Manager.new(width, height)
    scroll_buffer = Scroll.new(config.scrollback_height)
    cursor_manager = CursorManager.new()
    command_history = CommandHistory.new(config.command_history_size)

    %__MODULE__{
      emulator: emulator,
      buffer_manager: buffer_manager,
      scroll_buffer: scroll_buffer,
      cursor_manager: cursor_manager,
      command_history: command_history,
      config: config,
      memory_limit: config.memory_limit,
      last_cleanup: System.system_time(:millisecond)
    }
  end

  @doc """
  Handles input from the user, including command history navigation.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.handle_input(integration, "ls -la")
      iex> integration = Integration.handle_input(integration, :up_arrow)
  """
  def handle_input(%__MODULE__{} = integration, input) when is_binary(input) do
    if integration.config.enable_command_history do
      integration = %{integration | command_history: CommandHistory.save_input(integration.command_history, input)}
      integration
    else
      integration
    end
  end

  def handle_input(%__MODULE__{} = integration, :up_arrow) do
    if integration.config.enable_command_history do
      {command, command_history} = CommandHistory.previous(integration.command_history)
      if command do
        integration = %{integration | command_history: command_history}
        handle_input(integration, command)
      else
        integration
      end
    else
      integration
    end
  end

  def handle_input(%__MODULE__{} = integration, :down_arrow) do
    if integration.config.enable_command_history do
      {command, command_history} = CommandHistory.next(integration.command_history)
      if command do
        integration = %{integration | command_history: command_history}
        handle_input(integration, command)
      else
        integration
      end
    else
      integration
    end
  end

  @doc """
  Executes a command and updates the command history.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.execute_command(integration, "ls -la")
  """
  def execute_command(%__MODULE__{} = integration, command) when is_binary(command) do
    integration = if integration.config.enable_command_history do
      %{integration | command_history: CommandHistory.add(integration.command_history, command)}
    else
      integration
    end

    # Execute the command and update the terminal state
    # This is a placeholder for the actual command execution logic
    integration
  end

  @doc """
  Updates the terminal configuration.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.update_config(integration, theme: "light")
  """
  def update_config(%__MODULE__{} = integration, opts) do
    config = Configuration.update(integration.config, opts)
    case Configuration.validate(config) do
      :ok ->
        %{integration | config: config}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Writes text to the terminal with integrated buffer and cursor management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.write(integration, "Hello")
      iex> Integration.get_visible_content(integration)
      "Hello"
  """
  def write(%__MODULE__{} = integration, text) do
    # Check memory usage
    integration = check_memory_usage(integration)
    
    # Write to emulator
    emulator = Emulator.write(integration.emulator, text)
    
    # Update buffer manager
    buffer_manager = Manager.mark_damaged(
      integration.buffer_manager,
      0, 0, emulator.width - 1, emulator.height - 1
    )
    
    # Update cursor manager
    cursor_manager = CursorManager.move_to(
      integration.cursor_manager,
      emulator.cursor_x,
      emulator.cursor_y
    )
    
    # Update scroll buffer if needed
    scroll_buffer = if emulator.cursor_y >= emulator.height - 1 do
      line = Enum.at(emulator.screen_buffer, emulator.height - 1)
      Scroll.add_line(integration.scroll_buffer, line)
    else
      integration.scroll_buffer
    end
    
    %{integration |
      emulator: emulator,
      buffer_manager: buffer_manager,
      scroll_buffer: scroll_buffer,
      cursor_manager: cursor_manager
    }
  end

  @doc """
  Moves the cursor to the specified position with integrated cursor management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.move_cursor(integration, 10, 5)
      iex> integration.cursor_manager.position
      {10, 5}
  """
  def move_cursor(%__MODULE__{} = integration, x, y) do
    # Move cursor in emulator
    emulator = Emulator.move_cursor(integration.emulator, x, y)
    
    # Update cursor manager
    cursor_manager = CursorManager.move_to(integration.cursor_manager, x, y)
    
    %{integration |
      emulator: emulator,
      cursor_manager: cursor_manager
    }
  end

  @doc """
  Clears the screen with integrated buffer management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.write(integration, "Hello")
      iex> integration = Integration.clear_screen(integration)
      iex> Integration.get_visible_content(integration)
      ""
  """
  def clear_screen(%__MODULE__{} = integration) do
    # Clear emulator screen
    emulator = Emulator.clear_screen(integration.emulator)
    
    # Update buffer manager
    buffer_manager = Manager.mark_damaged(
      integration.buffer_manager,
      0, 0, emulator.width - 1, emulator.height - 1
    )
    
    # Reset cursor manager
    cursor_manager = CursorManager.move_to(integration.cursor_manager, 0, 0)
    
    %{integration |
      emulator: emulator,
      buffer_manager: buffer_manager,
      cursor_manager: cursor_manager
    }
  end

  @doc """
  Scrolls the terminal content with integrated scroll buffer management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.write(integration, "Line 1\nLine 2\nLine 3")
      iex> integration = Integration.scroll(integration, 1)
      iex> Integration.get_visible_content(integration)
      "Line 2\nLine 3"
  """
  def scroll(%__MODULE__{} = integration, lines) do
    # Scroll emulator
    emulator = Emulator.scroll(integration.emulator, lines)
    
    # Update scroll buffer
    scroll_buffer = Scroll.scroll(integration.scroll_buffer, lines)
    
    %{integration |
      emulator: emulator,
      scroll_buffer: scroll_buffer
    }
  end

  @doc """
  Gets the visible content of the terminal with integrated buffer management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.write(integration, "Hello")
      iex> Integration.get_visible_content(integration)
      "Hello"
  """
  def get_visible_content(%__MODULE__{} = integration) do
    Emulator.get_visible_content(integration.emulator)
  end

  @doc """
  Saves the current cursor position with integrated cursor management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.move_cursor(integration, 10, 5)
      iex> integration = Integration.save_cursor(integration)
      iex> integration.cursor_manager.saved_position
      {10, 5}
  """
  def save_cursor(%__MODULE__{} = integration) do
    # Save cursor in emulator
    emulator = Emulator.save_cursor(integration.emulator)
    
    # Save cursor in cursor manager
    cursor_manager = CursorManager.save_position(integration.cursor_manager)
    
    %{integration |
      emulator: emulator,
      cursor_manager: cursor_manager
    }
  end

  @doc """
  Restores the previously saved cursor position with integrated cursor management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.move_cursor(integration, 10, 5)
      iex> integration = Integration.save_cursor(integration)
      iex> integration = Integration.move_cursor(integration, 0, 0)
      iex> integration = Integration.restore_cursor(integration)
      iex> integration.cursor_manager.position
      {10, 5}
  """
  def restore_cursor(%__MODULE__{} = integration) do
    # Restore cursor in emulator
    emulator = Emulator.restore_cursor(integration.emulator)
    
    # Restore cursor in cursor manager
    cursor_manager = CursorManager.restore_position(integration.cursor_manager)
    
    %{integration |
      emulator: emulator,
      cursor_manager: cursor_manager
    }
  end

  @doc """
  Shows the cursor with integrated cursor management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.hide_cursor(integration)
      iex> integration = Integration.show_cursor(integration)
      iex> integration.cursor_manager.state
      :visible
  """
  def show_cursor(%__MODULE__{} = integration) do
    # Show cursor in emulator
    emulator = Emulator.show_cursor(integration.emulator)
    
    # Show cursor in cursor manager
    cursor_manager = CursorManager.set_state(integration.cursor_manager, :visible)
    
    %{integration |
      emulator: emulator,
      cursor_manager: cursor_manager
    }
  end

  @doc """
  Hides the cursor with integrated cursor management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.hide_cursor(integration)
      iex> integration.cursor_manager.state
      :hidden
  """
  def hide_cursor(%__MODULE__{} = integration) do
    # Hide cursor in emulator
    emulator = Emulator.hide_cursor(integration.emulator)
    
    # Hide cursor in cursor manager
    cursor_manager = CursorManager.set_state(integration.cursor_manager, :hidden)
    
    %{integration |
      emulator: emulator,
      cursor_manager: cursor_manager
    }
  end

  @doc """
  Sets the cursor style with integrated cursor management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.set_cursor_style(integration, :underline)
      iex> integration.cursor_manager.style
      :underline
  """
  def set_cursor_style(%__MODULE__{} = integration, style) do
    # Set cursor style in cursor manager
    cursor_manager = CursorManager.set_style(integration.cursor_manager, style)
    
    %{integration | cursor_manager: cursor_manager}
  end

  @doc """
  Sets the cursor blink rate with integrated cursor management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.set_cursor_blink_rate(integration, 1000)
      iex> integration.cursor_manager.blink_rate
      1000
  """
  def set_cursor_blink_rate(%__MODULE__{} = integration, rate) do
    # Set cursor blink rate in cursor manager
    cursor_manager = %{integration.cursor_manager | blink_rate: rate}
    
    %{integration | cursor_manager: cursor_manager}
  end

  @doc """
  Updates the cursor blink state with integrated cursor management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.set_cursor_style(integration, :blinking)
      iex> {integration, visible} = Integration.update_cursor_blink(integration)
      iex> is_boolean(visible)
      true
  """
  def update_cursor_blink(%__MODULE__{} = integration) do
    # Update cursor blink in cursor manager
    {cursor_manager, visible} = CursorManager.update_blink(integration.cursor_manager)
    
    # Update cursor visibility in emulator
    emulator = if visible do
      Emulator.show_cursor(integration.emulator)
    else
      Emulator.hide_cursor(integration.emulator)
    end
    
    {%{integration |
      emulator: emulator,
      cursor_manager: cursor_manager
    }, visible}
  end

  @doc """
  Gets the current cursor position with integrated cursor management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.move_cursor(integration, 10, 5)
      iex> Integration.get_cursor_position(integration)
      {10, 5}
  """
  def get_cursor_position(%__MODULE__{} = integration) do
    integration.cursor_manager.position
  end

  @doc """
  Gets the current cursor style with integrated cursor management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.set_cursor_style(integration, :underline)
      iex> Integration.get_cursor_style(integration)
      :underline
  """
  def get_cursor_style(%__MODULE__{} = integration) do
    integration.cursor_manager.style
  end

  @doc """
  Gets the current cursor state with integrated cursor management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.hide_cursor(integration)
      iex> Integration.get_cursor_state(integration)
      :hidden
  """
  def get_cursor_state(%__MODULE__{} = integration) do
    integration.cursor_manager.state
  end

  @doc """
  Gets the current scroll position with integrated scroll buffer management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.scroll(integration, 5)
      iex> Integration.get_scroll_position(integration)
      5
  """
  def get_scroll_position(%__MODULE__{} = integration) do
    Scroll.get_position(integration.scroll_buffer)
  end

  @doc """
  Gets the total scroll height with integrated scroll buffer management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.write(integration, "Line 1\nLine 2\nLine 3")
      iex> Integration.get_scroll_height(integration)
      3
  """
  def get_scroll_height(%__MODULE__{} = integration) do
    Scroll.get_height(integration.scroll_buffer)
  end

  @doc """
  Gets a view of the scroll buffer with integrated scroll buffer management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.write(integration, "Line 1\nLine 2\nLine 3")
      iex> view = Integration.get_scroll_view(integration, 2)
      iex> length(view)
      2
  """
  def get_scroll_view(%__MODULE__{} = integration, view_height) do
    Scroll.get_view(integration.scroll_buffer, view_height)
  end

  @doc """
  Clears the scroll buffer with integrated scroll buffer management.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.write(integration, "Line 1\nLine 2\nLine 3")
      iex> integration = Integration.clear_scroll_buffer(integration)
      iex> Integration.get_scroll_height(integration)
      0
  """
  def clear_scroll_buffer(%__MODULE__{} = integration) do
    # Clear scroll buffer
    scroll_buffer = Scroll.clear(integration.scroll_buffer)
    
    %{integration | scroll_buffer: scroll_buffer}
  end

  @doc """
  Gets the damage regions from the buffer manager.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.write(integration, "Hello")
      iex> regions = Integration.get_damage_regions(integration)
      iex> length(regions)
      1
  """
  def get_damage_regions(%__MODULE__{} = integration) do
    Manager.get_damage_regions(integration.buffer_manager)
  end

  @doc """
  Clears the damage regions in the buffer manager.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.write(integration, "Hello")
      iex> integration = Integration.clear_damage_regions(integration)
      iex> Integration.get_damage_regions(integration)
      []
  """
  def clear_damage_regions(%__MODULE__{} = integration) do
    # Clear damage regions in buffer manager
    buffer_manager = Manager.clear_damage_regions(integration.buffer_manager)
    
    %{integration | buffer_manager: buffer_manager}
  end

  @doc """
  Switches the active and back buffers in the buffer manager.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.write(integration, "Hello")
      iex> integration = Integration.switch_buffers(integration)
      iex> integration.buffer_manager.active_buffer != integration.buffer_manager.back_buffer
      true
  """
  def switch_buffers(%__MODULE__{} = integration) do
    # Switch buffers in buffer manager
    buffer_manager = Manager.switch_buffers(integration.buffer_manager)
    
    %{integration | buffer_manager: buffer_manager}
  end

  @doc """
  Updates memory usage tracking in the buffer manager.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.update_memory_usage(integration)
      iex> integration.buffer_manager.memory_usage > 0
      true
  """
  def update_memory_usage(%__MODULE__{} = integration) do
    # Update memory usage in buffer manager
    buffer_manager = Manager.update_memory_usage(integration.buffer_manager)
    
    %{integration | buffer_manager: buffer_manager}
  end

  @doc """
  Checks if memory usage is within limits.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> Integration.within_memory_limits?(integration)
      true
  """
  def within_memory_limits?(%__MODULE__{} = integration) do
    Manager.within_memory_limits?(integration.buffer_manager)
  end

  @doc """
  Sets a character set for a G-set.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.set_character_set(integration, "0", "B")
  """
  def set_character_set(%__MODULE__{} = integration, gset, charset) do
    emulator = Emulator.set_character_set(integration.emulator, gset, charset)
    %{integration | emulator: emulator}
  end

  @doc """
  Invokes a character set.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.invoke_character_set(integration, "0")
  """
  def invoke_character_set(%__MODULE__{} = integration, gset) do
    emulator = Emulator.invoke_character_set(integration.emulator, gset)
    %{integration | emulator: emulator}
  end

  @doc """
  Sets a screen mode.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.set_screen_mode(integration, "?47")
  """
  def set_screen_mode(%__MODULE__{} = integration, mode) do
    emulator = Emulator.set_screen_mode(integration.emulator, mode)
    %{integration | emulator: emulator}
  end

  @doc """
  Resets a screen mode.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.reset_screen_mode(integration, "?47")
  """
  def reset_screen_mode(%__MODULE__{} = integration, mode) do
    emulator = Emulator.reset_screen_mode(integration.emulator, mode)
    %{integration | emulator: emulator}
  end

  @doc """
  Checks if a screen mode is enabled.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.screen_mode_enabled?(integration, :alternate_screen)
      false
  """
  def screen_mode_enabled?(%__MODULE__{} = integration, mode) do
    Emulator.screen_mode_enabled?(integration.emulator, mode)
  end

  @doc """
  Switches to the alternate screen buffer.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.switch_to_alternate_buffer(integration)
  """
  def switch_to_alternate_buffer(%__MODULE__{} = integration) do
    emulator = Emulator.switch_to_alternate_buffer(integration.emulator)
    %{integration | emulator: emulator}
  end

  @doc """
  Switches back to the main screen buffer.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.switch_to_main_buffer(integration)
  """
  def switch_to_main_buffer(%__MODULE__{} = integration) do
    emulator = Emulator.switch_to_main_buffer(integration.emulator)
    %{integration | emulator: emulator}
  end

  @doc """
  Handles a device status query.
  
  ## Examples
  
      iex> integration = Integration.new(80, 24)
      iex> response = Integration.handle_device_status_query(integration, "6")
      iex> response
      "\e[1;1R"
  """
  def handle_device_status_query(%__MODULE__{} = integration, query) do
    Emulator.handle_device_status_query(integration.emulator, query)
  end

  # Private functions

  defp check_memory_usage(%__MODULE__{} = integration) do
    current_time = System.system_time(:millisecond)
    
    # Check if cleanup is needed
    if current_time - integration.last_cleanup > @cleanup_interval do
      cleanup_memory(integration)
    else
      integration
    end
  end

  defp cleanup_memory(%__MODULE__{} = integration) do
    # Update memory usage
    integration = update_memory_usage(integration)
    
    # Check if memory usage exceeds limit
    if integration.buffer_manager.memory_usage > integration.memory_limit do
      # Clear scroll buffer
      scroll_buffer = Scroll.clear(integration.scroll_buffer)
      
      %{integration |
        scroll_buffer: scroll_buffer,
        last_cleanup: System.system_time(:millisecond)
      }
    else
      %{integration | last_cleanup: System.system_time(:millisecond)}
    end
  end
end 