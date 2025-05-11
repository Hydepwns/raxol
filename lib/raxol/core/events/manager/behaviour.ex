defmodule Raxol.Core.Events.Manager.Behaviour do
  @callback dispatch(any()) :: any()
end
