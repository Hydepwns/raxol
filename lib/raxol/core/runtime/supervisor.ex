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

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Task supervisor for isolated task execution
      {Task.Supervisor, name: Raxol.Core.Runtime.TaskSupervisor},

      # Core runtime services
      {Raxol.Core.Runtime.StateManager, []},
      {Raxol.Core.Runtime.EventLoop, []},
      {Raxol.Core.Runtime.RenderLoop, []},

      # Plugin system
      {Raxol.Core.Runtime.Plugins.Manager, []},
      {Raxol.Core.Runtime.Plugins.Commands, []}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
