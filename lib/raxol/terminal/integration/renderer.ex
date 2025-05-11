defmodule Raxol.Terminal.Integration.Renderer do
  @moduledoc """
  Handles terminal output rendering and display management.
  """

  alias Raxol.Terminal.{
    Integration.State,
    Renderer,
    Buffer.Manager,
    Cursor.Manager
  }

  @doc """
  Renders the current terminal state to the screen.
  """
  def render(%State{} = state) do
    # Get the visible content
    content = Manager.get_visible_content(state.buffer_manager)

    # Get the cursor position
    {x, y} = Manager.get_position(state.cursor_manager)

    # Render the content
    {:ok, _} = Renderer.render(state.renderer, content, x, y)

    state
  end

  @doc """
  Updates the renderer configuration.
  """
  def update_config(%State{} = state, config) do
    # Update the renderer configuration
    {:ok, renderer} = Renderer.update_config(state.renderer, config)

    # Update the state
    State.update(state, renderer: renderer)
  end

  @doc """
  Gets the current renderer configuration.
  """
  def get_config(%State{} = state) do
    Renderer.get_config(state.renderer)
  end

  @doc """
  Sets a specific renderer configuration value.
  """
  def set_config_value(%State{} = state, key, value) do
    # Update the renderer configuration
    {:ok, renderer} = Renderer.set_config_value(state.renderer, key, value)

    # Update the state
    State.update(state, renderer: renderer)
  end

  @doc """
  Resets the renderer configuration to default values.
  """
  def reset_config(%State{} = state) do
    # Reset the renderer configuration
    {:ok, renderer} = Renderer.reset_config(state.renderer)

    # Update the state
    State.update(state, renderer: renderer)
  end

  @doc """
  Gets the current terminal dimensions.
  """
  def get_dimensions(%State{} = state) do
    Renderer.get_dimensions(state.renderer)
  end

  @doc """
  Resizes the terminal display.
  """
  def resize(%State{} = state, width, height) do
    # Resize the renderer
    {:ok, renderer} = Renderer.resize(state.renderer, width, height)

    # Update the state
    State.update(state, renderer: renderer)
  end

  @doc """
  Clears the terminal screen.
  """
  def clear_screen(%State{} = state) do
    # Clear the screen
    {:ok, _} = Renderer.clear_screen(state.renderer)

    state
  end

  @doc """
  Moves the cursor to a specific position on the screen.
  """
  def move_cursor(%State{} = state, x, y) do
    # Move the cursor
    {:ok, _} = Renderer.move_cursor(state.renderer, x, y)

    state
  end

  @doc """
  Shows or hides the cursor.
  """
  def set_cursor_visibility(%State{} = state, visible) do
    # Set cursor visibility
    {:ok, _} = Renderer.set_cursor_visibility(state.renderer, visible)

    state
  end

  @doc """
  Sets the terminal title.
  """
  def set_title(%State{} = state, title) do
    # Set the title
    {:ok, _} = Renderer.set_title(state.renderer, title)

    state
  end

  @doc """
  Gets the current terminal title.
  """
  def get_title(%State{} = state) do
    Renderer.get_title(state.renderer)
  end
end
