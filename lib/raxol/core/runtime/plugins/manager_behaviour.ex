defmodule Raxol.Core.Runtime.Plugins.Manager.Behaviour do
  @moduledoc "Behaviour for Plugins.Manager, used for mocking."

  @callback start_link(opts :: Keyword.t()) :: GenServer.on_start()
  # @callback initialize() :: :ok | {:error, term()}
  # @callback handle_cast({:handle_command, atom(), any()}, map()) :: {:noreply, map()}
  # Add other callbacks as needed for tests
end
