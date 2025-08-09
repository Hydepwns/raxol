defmodule Raxol.UI.Components.Base.LifecycleDefaults do
  @moduledoc """
  Provides default implementations for component lifecycle hooks.

  This module can be used to provide sensible defaults for lifecycle
  hooks that don't require specific implementation in a component.
  """

  @doc """
  Default mount implementation - returns state unchanged.

  Override this if your component needs to:
  - Start timers or processes
  - Subscribe to events
  - Allocate resources
  - Initialize external connections
  """
  def default_mount(state) do
    {state, []}
  end

  @doc """
  Default unmount implementation - returns state unchanged.

  Override this if your component needs to:
  - Stop timers or processes
  - Unsubscribe from events
  - Release resources
  - Close external connections
  """
  def default_unmount(state) do
    state
  end

  @doc """
  Macro to inject default lifecycle hooks.

  Usage:
    use Raxol.UI.Components.Base.LifecycleDefaults

  This will add default mount/1 and unmount/1 if not already defined.
  """
  defmacro __using__(_opts) do
    quote do
      # Import the default implementations
      import Raxol.UI.Components.Base.LifecycleDefaults

      # Define mount/1 if not already defined
      unless Module.defines?(__MODULE__, {:mount, 1}) do
        def mount(state), do: default_mount(state)
        defoverridable mount: 1
      end

      # Define unmount/1 if not already defined
      unless Module.defines?(__MODULE__, {:unmount, 1}) do
        def unmount(state), do: default_unmount(state)
        defoverridable unmount: 1
      end
    end
  end
end
