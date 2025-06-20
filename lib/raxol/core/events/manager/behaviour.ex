defmodule Raxol.Core.Events.Manager.Behaviour do
  @callback dispatch(any()) :: any()
  @callback broadcast(any()) :: any()
end
