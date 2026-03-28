defmodule Raxol.Agent.Team do
  @moduledoc """
  Supervisor for agent teams.

  A team is a group of agents under a single supervisor. The coordinator
  agent is started first; if it crashes, workers restart per the chosen
  strategy (default `:rest_for_one`).

  Teams are started as dynamic children of `Raxol.DynamicSupervisor`.
  """

  use Supervisor

  @doc """
  Start a team supervisor.

  ## Options

    * `:team_id` - Required identifier for the team.
    * `:coordinator` - `{module, opts}` for the coordinator agent.
    * `:workers` - List of `{module, opts}` for worker agents.
    * `:strategy` - Supervisor strategy (default `:rest_for_one`).
  """
  def start_link(opts) do
    team_id = Keyword.fetch!(opts, :team_id)
    Supervisor.start_link(__MODULE__, opts, name: :"agent_team_#{team_id}")
  end

  @impl true
  def init(opts) do
    team_id = Keyword.fetch!(opts, :team_id)
    {coord_mod, coord_opts} = Keyword.fetch!(opts, :coordinator)
    workers = Keyword.get(opts, :workers, [])
    strategy = Keyword.get(opts, :strategy, :rest_for_one)

    coord_id = Keyword.get(coord_opts, :id, :"#{team_id}_coordinator")

    coordinator_spec =
      {Raxol.Agent.Session,
       [app_module: coord_mod, id: coord_id, team_id: team_id] ++
         Keyword.delete(coord_opts, :id)}

    worker_specs =
      workers
      |> Enum.with_index()
      |> Enum.map(fn {{mod, wopts}, idx} ->
        worker_id = Keyword.get(wopts, :id, :"#{team_id}_worker_#{idx}")

        {Raxol.Agent.Session,
         [app_module: mod, id: worker_id, team_id: team_id] ++
           Keyword.delete(wopts, :id)}
      end)

    children = [coordinator_spec | worker_specs]

    Supervisor.init(children, strategy: strategy)
  end
end
