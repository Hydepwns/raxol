defmodule Raxol.Core.Runtime.Events.Dispatcher.Behaviour do
  @moduledoc """
  Defines the behaviour for the Event Dispatcher GenServer.

  Primarily used for mocking with Mox.
  """

  @callback start_link(runtime_pid :: pid(), initial_state :: map()) ::
              GenServer.on_start()
  # Add other relevant callbacks if needed for different tests, e.g.:
  # @callback init(init_args :: term()) :: {:ok, map()} | {:stop, term()}
  # @callback handle_cast(message :: term(), state :: map()) :: {:noreply, map()} | {:stop, term(), map()}
  # ... etc
end
