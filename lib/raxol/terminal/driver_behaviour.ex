defmodule Raxol.Terminal.Driver.Behaviour do
  @moduledoc 'Behaviour for Terminal.Driver, used for mocking.'

  @callback start_link(dispatcher_pid :: pid() | nil) :: GenServer.on_start()
end
