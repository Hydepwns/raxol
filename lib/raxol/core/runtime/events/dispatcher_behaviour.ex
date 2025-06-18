defmodule Raxol.Core.Runtime.Events.Dispatcher.Behaviour do
  @moduledoc '''
  Defines the behaviour for the Event Dispatcher GenServer.

  Primarily used for mocking with Mox.
  '''

  @callback start_link(runtime_pid :: pid(), initial_state :: map()) ::
              GenServer.on_start()

  @callback dispatch(event :: Raxol.Core.Runtime.Events.Event.t()) :: :ok
end
