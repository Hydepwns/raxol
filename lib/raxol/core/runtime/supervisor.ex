defmodule Raxol.Core.Runtime.Supervisor do
  @moduledoc """
  Supervises the core runtime processes of a Raxol application.

  This supervisor manages:
  * Application runtime
  * Event handlers
  * Render processes
  * State management
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Raxol.Core.Runtime.StateManager, []},
      {Raxol.Core.Runtime.EventLoop, []},
      {Raxol.Core.Runtime.RenderLoop, []}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
