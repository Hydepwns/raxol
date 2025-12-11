defmodule Raxol.Plugins.EventHandler do
  @moduledoc """
  Handles events for plugin system.
  """

  alias Raxol.Plugins.EventHandler.InputEvents
  alias Raxol.Plugins.EventHandler.OutputEvents

  @doc """
  Handles input events.
  """
  def handle_input(manager, input) do
    InputEvents.handle_input(manager, input)
  end

  @doc """
  Handles output events.
  """
  def handle_output(manager, output) do
    # Delegate to output events handler for proper implementation
    OutputEvents.handle_output(manager, output)
  end

  @doc """
  Handles resize events.
  """
  def handle_resize(manager, _width, _height) do
    # Stub implementation
    {:ok, manager}
  end

  @doc """
  Handles mouse events.
  """
  def handle_mouse_event(manager, _event, _rendered_cells) do
    # Stub implementation
    {:ok, manager}
  end
end
