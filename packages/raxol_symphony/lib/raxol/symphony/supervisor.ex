defmodule Raxol.Symphony.Supervisor do
  @moduledoc """
  Top-level supervisor for the Symphony orchestrator.

  Phase 0: skeleton only. Children added in subsequent phases:

  - Phase 7: `Raxol.Symphony.WorkflowStore` (file watcher + last-known-good)
  - Phase 3: `Raxol.Symphony.Orchestrator` (poll/dispatch GenServer)
  - Phase 10: HTTP server endpoint (gated on `:server` config)
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    config = Keyword.fetch!(opts, :config)

    children = [
      {Task.Supervisor, name: Raxol.Symphony.TaskSupervisor},
      {Raxol.Symphony.Orchestrator, [config: config] ++ orchestrator_opts(opts)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp orchestrator_opts(opts) do
    Keyword.take(opts, [:runner_module, :tracker_module, :auto_start_tick])
  end
end
