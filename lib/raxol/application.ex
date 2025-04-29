defmodule Raxol.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Dynamic Supervisor for Raxol applications
      Raxol.DynamicSupervisor,
      # Start the UserPreferences GenServer
      Raxol.Core.UserPreferences,
      # Start the Terminal Driver
      # TODO: Pass the actual Dispatcher PID later
      {Raxol.Terminal.Driver, nil}
      # Add other core persistent processes here if needed (e.g., PluginManager, TerminalDriver? Check ARCHITECTURE)
    ]

    opts = [strategy: :one_for_one, name: Raxol.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
