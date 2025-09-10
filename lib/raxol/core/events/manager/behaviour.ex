defmodule Raxol.Core.Events.EventManager.Behaviour do
  @moduledoc """
  Behaviour definition for event managers.

  Defines the interface for dispatching and broadcasting events
  within the Raxol event system.
  """
  @callback dispatch(any()) :: any()
  @callback broadcast(any()) :: any()
end
