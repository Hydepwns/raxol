defmodule Raxol.Agent.TeamTest do
  use ExUnit.Case, async: false

  alias Raxol.Agent.{Team, Session}

  defmodule CoordinatorAgent do
    use Raxol.Agent

    def init(_context), do: %{role: :coordinator, messages: []}

    def update({:agent_message, from, msg}, model) do
      {%{model | messages: [{from, msg} | model.messages]}, Command.none()}
    end

    def update(_msg, model), do: {model, Command.none()}
  end

  defmodule WorkerAgent do
    use Raxol.Agent

    def init(_context), do: %{role: :worker, tasks_done: 0}

    def update({:agent_message, _from, :do_task}, model) do
      {%{model | tasks_done: model.tasks_done + 1}, Command.none()}
    end

    def update(_msg, model), do: {model, Command.none()}
  end

  @tag :docker
  test "start team with coordinator and workers" do
    {:ok, team_pid} =
      Team.start_link(
        team_id: :test_team_1,
        coordinator: {CoordinatorAgent, [id: :coord_1]},
        workers: [
          {WorkerAgent, [id: :worker_1a]},
          {WorkerAgent, [id: :worker_1b]}
        ]
      )

    assert Process.alive?(team_pid)

    # Verify all agents are registered
    assert [{_, _}] = Registry.lookup(Raxol.Agent.Registry, :coord_1)
    assert [{_, _}] = Registry.lookup(Raxol.Agent.Registry, :worker_1a)
    assert [{_, _}] = Registry.lookup(Raxol.Agent.Registry, :worker_1b)

    Supervisor.stop(team_pid)
  end

  @tag :docker
  test "workers receive messages from coordinator" do
    {:ok, _team_pid} =
      Team.start_link(
        team_id: :test_team_2,
        coordinator: {CoordinatorAgent, [id: :coord_2]},
        workers: [{WorkerAgent, [id: :worker_2a]}]
      )

    Session.send_message(:worker_2a, :do_task)
    Process.sleep(100)

    {:ok, model} = Session.get_model(:worker_2a)
    assert model.tasks_done == 1
  end

  @tag :docker
  test "team shutdown stops all agents" do
    {:ok, team_pid} =
      Team.start_link(
        team_id: :test_team_3,
        coordinator: {CoordinatorAgent, [id: :coord_3]},
        workers: [{WorkerAgent, [id: :worker_3a]}]
      )

    [{coord_pid, _}] = Registry.lookup(Raxol.Agent.Registry, :coord_3)
    [{worker_pid, _}] = Registry.lookup(Raxol.Agent.Registry, :worker_3a)

    Supervisor.stop(team_pid)
    Process.sleep(50)

    refute Process.alive?(coord_pid)
    refute Process.alive?(worker_pid)
  end
end
