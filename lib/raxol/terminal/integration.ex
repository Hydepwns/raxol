defmodule Raxol.Terminal.Integration do
  @moduledoc """
  Integrates various terminal components like Emulator, Buffer Manager, Cursor Manager, etc.

  This module acts as a central orchestrator, managing interactions between:
  - Terminal Emulator state (`Raxol.Terminal.Emulator`)
  - Screen buffer management (`Raxol.Terminal.Buffer.Manager`)
  - Cursor state and rendering (`Raxol.Terminal.Cursor.Manager`)
  - Scrollback buffer (`Raxol.Terminal.Buffer.Scroll`)
  - Input handling and command history (`Raxol.Terminal.Commands.History`)
  - Terminal configuration (`Raxol.Terminal.Config`)
  - Managing memory and performance optimizations
  - Command history management
  """

  require Logger

  alias Raxol.Terminal.Buffer.Manager, as: BufferManager
  alias Raxol.Terminal.Buffer.Scroll
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.Cursor.Style
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.History
  alias Raxol.Terminal.Config
  alias Raxol.Terminal.Renderer
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.MemoryManager
  alias Raxol.Terminal.Config.Utils
  alias Raxol.Terminal.Config.Defaults

  @type t :: %__MODULE__{
          emulator: Emulator.t(),
          renderer: Renderer.t(),
          buffer_manager: BufferManager.t(),
          scroll_buffer: Scroll.t(),
          cursor_manager: CursorManager.t(),
          command_history: History.t(),
          config: map(),
          last_cleanup: integer()
        }

  defstruct [
    :emulator,
    :renderer,
    :buffer_manager,
    :scroll_buffer,
    :cursor_manager,
    :command_history,
    :config,
    :last_cleanup
  ]

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
    default_config = Defaults.generate_default_config()
    config = Utils.deep_merge(default_config, opts)

    emulator = Emulator.new(width, height)

    {:ok, buffer_manager} =
      BufferManager.new(
        width,
        height,
        config.behavior.scrollback_lines,
        config.memory_limit || 50 * 1024 * 1024
      )

    renderer =
      Renderer.new(Emulator.get_active_buffer(emulator), config.ansi.colors)

    scroll_buffer = Scroll.new(config.behavior.scrollback_lines)
    cursor_manager = CursorManager.new()
    command_history = History.new((config.behavior.save_history && 1000) || 0)

    %__MODULE__{
      emulator: emulator,
      renderer: renderer,
      buffer_manager: buffer_manager,
      scroll_buffer: scroll_buffer,
      cursor_manager: cursor_manager,
      command_history: command_history,
      config: config,
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
    integration =
      if integration.config.enable_command_history do
        %{
          integration
          | command_history:
              History.save_input(integration.command_history, input)
        }
      else
        integration
      end

    MemoryManager.check_and_cleanup(integration)
  end

  def handle_input(%__MODULE__{} = integration, :up_arrow) do
    integration =
      if integration.config.enable_command_history do
        {command, command_history} =
          History.previous(integration.command_history)

        if command do
          %{integration | command_history: command_history}
          |> handle_input(command)
        else
          integration
        end
      else
        integration
      end

    MemoryManager.check_and_cleanup(integration)
  end

  def handle_input(%__MODULE__{} = integration, :down_arrow) do
    integration =
      if integration.config.enable_command_history do
        {command, command_history} =
          History.next(integration.command_history)

        if command do
          %{integration | command_history: command_history}
          |> handle_input(command)
        else
          integration
        end
      else
        integration
      end

    MemoryManager.check_and_cleanup(integration)
  end

  @doc """
  Executes a command and updates the command history.

  ## Examples

      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.execute_command(integration, "ls -la")
  """
  def execute_command(%__MODULE__{} = integration, command)
      when is_binary(command) do
    integration =
      if integration.config.enable_command_history do
        %{
          integration
          | command_history: History.add(integration.command_history, command)
        }
      else
        integration
      end

    # Execute the command and update the terminal state
    # This is a placeholder for the actual command execution logic
    integration
  end

  @doc """
  Updates the terminal configuration.

  Merges the provided `opts` into the current configuration and validates
  the result before applying.

  ## Examples

      iex> integration = Integration.new(80, 24)
      iex> {:ok, integration} = Integration.update_config(integration, theme: "light", behavior: [scrollback_lines: 2000])
      iex> integration.config.theme
      "light"
      iex> integration.config.behavior.scrollback_lines
      2000

      iex> {:error, _reason} = Integration.update_config(integration, invalid_opt: :bad)
  """
  def update_config(%__MODULE__{} = integration, opts) do
    # Merge the new options into the current config
    updated_config = Config.merge_opts(integration.config, opts)

    # Validate the *entire* updated configuration
    case Config.validate_config(updated_config) do
      {:ok, validated_config} ->
        # Apply the validated, merged config
        # TODO: Consider if other parts of the integration state need updating
        #       based on config changes (e.g., BufferManager limits, Renderer colors).
        #       This might require more granular updates or a dedicated apply_config function.
        {:ok, %{integration | config: validated_config}}

      {:error, reason} ->
        # Log the validation error
        Logger.error(
          "Terminal configuration update failed validation: #{inspect(reason)}"
        )

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
    # Use process_input for writing text
    {emulator, _output} = Emulator.process_input(integration.emulator, text)
    # Update the renderer with the new screen buffer from the emulator
    # Use getter for active buffer
    new_renderer =
      Renderer.new(
        Emulator.get_active_buffer(emulator),
        integration.config.ansi.colors
      )

    %{integration | emulator: emulator, renderer: new_renderer}
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
    # Assuming Emulator provides a way to move cursor, e.g., via Cursor.Movement
    # TODO: Verify the correct function to call for moving the cursor in Emulator
    new_cursor =
      Raxol.Terminal.Cursor.Movement.move_to_position(
        integration.emulator.cursor,
        x,
        y
      )

    emulator = %{integration.emulator | cursor: new_cursor}

    # Update cursor manager
    cursor_manager = CursorManager.move_to(integration.cursor_manager, x, y)

    %{integration | emulator: emulator, cursor_manager: cursor_manager}
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
    # Use process_input with CSI 2J (Erase Screen)
    {emulator, _output} = Emulator.process_input(integration.emulator, "\e[2J")
    # Update the renderer with the new screen buffer from the emulator
    # Use getter for active buffer
    new_renderer =
      Renderer.new(
        Emulator.get_active_buffer(emulator),
        integration.config.ansi.colors
      )

    %{integration | emulator: emulator, renderer: new_renderer}
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
    # Scroll emulator using CSI S (Scroll Up) - Assuming scroll up based on example
    # TODO: Verify if scroll down (CSI T) might also be needed.
    {emulator, _output} =
      Emulator.process_input(integration.emulator, "\e[#{lines}S")

    # Update scroll buffer
    scroll_buffer = Scroll.scroll(integration.scroll_buffer, lines)

    %{integration | emulator: emulator, scroll_buffer: scroll_buffer}
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
    # Assuming ScreenBuffer has a function to get string content
    # Use getter for active buffer
    ScreenBuffer.get_content(Emulator.get_active_buffer(integration.emulator))
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
    cursor = CursorManager.save_position(integration.cursor_manager)
    %{integration | cursor_manager: cursor}
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
    cursor = CursorManager.restore_position(integration.cursor_manager)
    %{integration | cursor_manager: cursor}
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
    cursor = Style.show(integration.emulator.cursor)
    emulator = %{integration.emulator | cursor: cursor}
    %{integration | emulator: emulator}
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
    cursor = Style.hide(integration.emulator.cursor)
    emulator = %{integration.emulator | cursor: cursor}
    %{integration | emulator: emulator}
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
    {cursor_manager, visible} =
      CursorManager.update_blink(integration.cursor_manager)

    # Update cursor visibility state using Style.show/hide
    cursor_manager =
      if visible do
        Style.show(cursor_manager)
      else
        Style.hide(cursor_manager)
      end

    {%{integration | cursor_manager: cursor_manager}, visible}
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
    BufferManager.get_damage_regions(integration.buffer_manager)
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
    buffer_manager =
      BufferManager.clear_damage_regions(integration.buffer_manager)

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
    buffer_manager = BufferManager.switch_buffers(integration.buffer_manager)
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
    buffer_manager =
      BufferManager.update_memory_usage(integration.buffer_manager)

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
    BufferManager.within_memory_limits?(integration.buffer_manager)
  end

  @doc """
  Sets a character set for a G-set.

  ## Examples

      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.set_character_set(integration, "0", "B")
  """
  def set_character_set(%__MODULE__{} = integration, gset, charset) do
    # Use process_input with ESC sequence e.g., ESC ( B for G0/ASCII
    designator =
      case gset do
        "0" -> "("
        "1" -> ")"
        "2" -> "*"
        "3" -> "+"
        # Default to G0
        _ -> "("
      end

    sequence = "\e" <> designator <> charset
    {emulator, _output} = Emulator.process_input(integration.emulator, sequence)
    %{integration | emulator: emulator}
  end

  @doc """
  Invokes a character set.

  ## Examples

      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.invoke_character_set(integration, "0")
  """
  def invoke_character_set(%__MODULE__{} = integration, gset) do
    # Use process_input with Shift In/Out etc.
    # LS0 = SI = ^O = \x0F (G0)
    # LS1 = SO = ^N = \x0E (G1)
    # LS2 = ESC n (G2)
    # LS3 = ESC o (G3)
    # LS1R = ESC ~ (G1)
    # LS2R = ESC } (G2)
    # LS3R = ESC | (G3)
    sequence =
      case gset do
        # SI
        "0" -> "\x0F"
        # SO
        "1" -> "\x0E"
        # LS2
        "2" -> "\en"
        # LS3
        "3" -> "\eo"
        # Default to G0
        _ -> "\x0F"
      end

    {emulator, _output} = Emulator.process_input(integration.emulator, sequence)
    %{integration | emulator: emulator}
  end

  @doc """
  Sets a specific screen mode in the emulator.
  """
  def set_screen_mode(%__MODULE__{} = integration, mode) do
    # Assuming mode is the numeric code (e.g., 4 for IRM, ?6 for DECOM)
    # Need to distinguish between standard and DEC private modes based on the atom.
    # For now, assume DEC private mode format CSI ? mode h
    # TODO: Refine this based on actual mode atoms used
    sequence = "\e[?#{mode}h"
    {emulator, _output} = Emulator.process_input(integration.emulator, sequence)

    %{integration | emulator: emulator}
  end

  @doc """
  Resets a specific screen mode in the emulator.
  """
  def reset_screen_mode(%__MODULE__{} = integration, mode) do
    # Assuming mode is the numeric code (e.g., 4 for IRM, ?6 for DECOM)
    # Assuming DEC private mode format CSI ? mode l
    # TODO: Refine this based on actual mode atoms used
    sequence = "\e[?#{mode}l"
    {emulator, _output} = Emulator.process_input(integration.emulator, sequence)

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
    # Check the mode_state map directly
    Map.get(integration.emulator.mode_state, mode, false)
  end

  @doc """
  Switches to the alternate screen buffer.

  ## Examples

      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.switch_to_alternate_buffer(integration)
  """
  def switch_to_alternate_buffer(%__MODULE__{} = integration) do
    # Use process_input with CSI ?1047h (or ?1049h if clearing is desired)
    {emulator, _output} =
      Emulator.process_input(integration.emulator, "\e[?1047h")

    %{integration | emulator: emulator}
  end

  @doc """
  Switches back to the main screen buffer.

  ## Examples

      iex> integration = Integration.new(80, 24)
      iex> integration = Integration.switch_to_main_buffer(integration)
  """
  def switch_to_main_buffer(%__MODULE__{} = integration) do
    # Use process_input with CSI ?1047l (or ?1049l)
    {emulator, _output} =
      Emulator.process_input(integration.emulator, "\e[?1047l")

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
  def handle_device_status_query(%__MODULE__{} = _integration, _query) do
    # Emulator.process_input does not return application-level responses.
    # This function likely needs to be handled differently, perhaps by peeking
    # into the emulator state or requiring a different interaction model.
    # TODO: Re-implement or remove handle_device_status_query
    Logger.warning(
      "handle_device_status_query is not implemented after refactor",
      []
    )

    # Return nil as a placeholder
    nil
  end

  # Private functions

  def handle_event(%__MODULE__{} = integration, {:cursor_style, style}) do
    cursor_manager = CursorManager.set_style(integration.cursor_manager, style)
    %{integration | cursor_manager: cursor_manager}
  end

  def handle_event(%__MODULE__{} = integration, {:cursor_visible, true}) do
    cursor_manager = Style.show(integration.cursor_manager)
    %{integration | cursor_manager: cursor_manager}
  end

  def handle_event(%__MODULE__{} = integration, {:cursor_visible, false}) do
    cursor_manager = Style.hide(integration.cursor_manager)
    %{integration | cursor_manager: cursor_manager}
  end
end
