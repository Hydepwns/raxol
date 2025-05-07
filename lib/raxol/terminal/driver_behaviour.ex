defmodule Raxol.Terminal.Driver.Behaviour do
  @moduledoc "Behaviour for Terminal.Driver, used for mocking."

  @callback start_link(dispatcher_pid :: pid() | nil) :: GenServer.on_start()
  # @callback init(dispatcher_pid :: pid() | nil) :: {:ok, map()} | {:stop, term()}
  # @callback handle_cast({:register_dispatcher, pid()}, map()) :: {:noreply, map()}
  # Add other callbacks as needed for tests
end
