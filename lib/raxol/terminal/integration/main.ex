defmodule Raxol.Terminal.Integration do
  @moduledoc """
  Coordinates terminal integration components and provides a unified interface
  for terminal operations.

  This module manages the interaction between various terminal components:
  - State management
  - Input processing
  - Buffer management
  - Rendering
  - Configuration
  """

  alias Raxol.Terminal.Integration.State
  alias Raxol.Terminal.Integration.Input
  alias Raxol.Terminal.Integration.Buffer
  alias Raxol.Terminal.Integration.Renderer, as: IntegrationRenderer
  alias Raxol.Terminal.Integration.Config
  alias Raxol.Terminal.Buffer.Manager
  alias Raxol.Terminal.Cursor.Manager
  alias Raxol.Terminal.Renderer
  alias Raxol.Terminal.Command.History

  @doc """
  Initializes a new terminal integration state.
  """
  def init(opts \\ %{}) do
    # Initialize components
    {:ok, buffer_manager} = Manager.new(opts)
    {:ok, cursor_manager} = Manager.new(opts)
    {:ok, renderer} = IntegrationRenderer.new(opts)
    {:ok, scroll_buffer} = Buffer.Scroll.new(opts)
    {:ok, command_history} = History.new(opts)

    # Create initial state
    State.new(%{
      buffer_manager: buffer_manager,
      cursor_manager: cursor_manager,
      renderer: renderer,
      scroll_buffer: scroll_buffer,
      command_history: command_history,
      config: Config.default_config()
    })
  end

  @doc """
  Processes user input and updates the terminal state.
  """
  def handle_input(%State{} = state, input) do
    # Process input
    state = Input.handle_input(state, input)

    # Render the updated state
    render(state)
  end

  @doc """
  Writes text to the terminal.
  """
  def write(%State{} = state, text) do
    # Write to buffer
    state = Buffer.write(state, text)

    # Render the updated state
    render(state)
  end

  @doc """
  Clears the terminal.
  """
  def clear(%State{} = state) do
    # Clear buffer
    state = Buffer.clear(state)

    # Clear screen
    state = IntegrationRenderer.clear_screen(state)

    # Render the updated state
    render(state)
  end

  @doc """
  Scrolls the terminal.
  """
  def scroll(%State{} = state, direction, amount \\ 1) do
    # Scroll buffer
    state = Buffer.scroll(state, direction, amount)

    # Render the updated state
    render(state)
  end

  @doc """
  Moves the cursor to a specific position.
  """
  def move_cursor(%State{} = state, x, y) do
    # Move cursor in buffer
    state = Buffer.move_cursor(state, x, y)

    # Move cursor on screen
    state = IntegrationRenderer.move_cursor(state, x, y)

    state
  end

  @doc """
  Updates the terminal configuration.
  """
  def update_config(%State{} = state, config) do
    # Update configuration
    state = Config.update_config(state, config)

    # Update renderer configuration
    state = IntegrationRenderer.update_config(state, config)

    # Render the updated state
    render(state)
  end

  @doc """
  Gets the current terminal configuration.
  """
  def get_config(%State{} = state) do
    Config.get_config(state)
  end

  @doc """
  Sets a specific configuration value.
  """
  def set_config_value(%State{} = state, key, value) do
    # Update configuration
    state = Config.set_config_value(state, key, value)

    # Update renderer configuration
    state = IntegrationRenderer.set_config_value(state, key, value)

    # Render the updated state
    render(state)
  end

  @doc """
  Resets the terminal configuration to default values.
  """
  def reset_config(%State{} = state) do
    # Reset configuration
    state = Config.reset_config(state)

    # Reset renderer configuration
    state = IntegrationRenderer.reset_config(state)

    # Render the updated state
    render(state)
  end

  @doc """
  Resizes the terminal.
  """
  def resize(%State{} = state, width, height) do
    # Resize buffer
    state = Buffer.resize(state, width, height)

    # Resize renderer
    state = IntegrationRenderer.resize(state, width, height)

    # Render the updated state
    render(state)
  end

  @doc """
  Gets the current terminal dimensions.
  """
  def get_dimensions(%State{} = state) do
    IntegrationRenderer.get_dimensions(state)
  end

  @doc """
  Gets the current cursor position.
  """
  def get_cursor_position(%State{} = state) do
    Buffer.get_cursor_position(state)
  end

  @doc """
  Gets the current visible content.
  """
  def get_visible_content(%State{} = state) do
    Buffer.get_visible_content(state)
  end

  @doc """
  Gets the current scroll position.
  """
  def get_scroll_position(%State{} = state) do
    Buffer.get_scroll_position(state)
  end

  @doc """
  Gets the total number of lines in the buffer.
  """
  def get_total_lines(%State{} = state) do
    Buffer.get_total_lines(state)
  end

  @doc """
  Gets the number of visible lines.
  """
  def get_visible_lines(%State{} = state) do
    Buffer.get_visible_lines(state)
  end

  @doc """
  Shows or hides the cursor.
  """
  def set_cursor_visibility(%State{} = state, visible) do
    IntegrationRenderer.set_cursor_visibility(state, visible)
  end

  @doc """
  Sets the terminal title.
  """
  def set_title(%State{} = state, title) do
    IntegrationRenderer.set_title(state, title)
  end

  @doc """
  Gets the current terminal title.
  """
  def get_title(%State{} = state) do
    IntegrationRenderer.get_title(state)
  end

  # Private functions

  defp render(%State{} = state) do
    IntegrationRenderer.render(state)
  end
end
