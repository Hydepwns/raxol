defmodule Raxol.Plugins.EventHandler do
  @moduledoc """
  Handles events for plugin system.
  """

  alias Raxol.Plugins.EventHandler.InputEvents
  alias Raxol.Plugins.EventHandler.OutputEvents

  @doc """
  Handles input events.
  """
  @spec handle_input(term(), term()) :: {:ok, term()}
  def handle_input(manager, input) do
    InputEvents.handle_input(manager, input)
  end

  @doc """
  Handles output events.
  """
  @spec handle_output(term(), term()) :: {:ok, term()}
  def handle_output(manager, output) do
    # Delegate to output events handler for proper implementation
    OutputEvents.handle_output(manager, output)
  end

  @doc """
  Handles resize events.
  """
  @spec handle_resize(term(), non_neg_integer(), non_neg_integer()) ::
          {:ok, term()}
  def handle_resize(manager, _width, _height) do
    # Stub implementation
    {:ok, manager}
  end

  @doc """
  Handles mouse events.
  """
  @spec handle_mouse_event(term(), term(), term()) ::
          {:ok, term()}
  def handle_mouse_event(manager, _event, _rendered_cells) do
    # Stub implementation
    {:ok, manager}
  end
end
