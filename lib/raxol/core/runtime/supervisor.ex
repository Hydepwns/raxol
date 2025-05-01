defmodule Raxol.Core.Runtime.Supervisor do
  @moduledoc """
  Supervises the core runtime processes of a Raxol application.

  This supervisor manages:
  * Application runtime
  * Event handlers
  * Render processes
  * State management
  * Plugin system
  """

  use Supervisor
  require Logger

  def start_link(init_arg) do
    Logger.info("[#{__MODULE__}] start_link called with args: #{inspect(init_arg)}")
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(init_arg) do
    Logger.info("[#{__MODULE__}] init called with args: #{inspect(init_arg)}")
    children = [
      # Task supervisor for isolated task execution
      {Task.Supervisor, name: Raxol.Core.Runtime.TaskSupervisor},

      # Core runtime services
      # REMOVED: {Raxol.Core.Runtime.StateManager, []}, # Does not exist
      {Raxol.Core.Runtime.EventLoop, []},
      {Raxol.Core.Runtime.RenderLoop, []},

      # Plugin system
      {Raxol.Core.Runtime.Plugins.Manager, []},
      {Raxol.Core.Runtime.Plugins.Commands, []}
    ]

    Logger.debug("[#{__MODULE__}] Initializing children: #{inspect(children)}")
    Supervisor.init(children, strategy: :one_for_all)
  end
end
