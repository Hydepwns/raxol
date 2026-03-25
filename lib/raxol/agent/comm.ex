defmodule Raxol.Agent.Comm do
  @moduledoc """
  Agent communication primitives.

  Agents discover each other via `Raxol.Agent.Registry` and communicate
  through their Session GenServers. Messages arrive in the target agent's
  `update/2` as `{:agent_message, from_id, payload}`.
  """

  alias Raxol.Agent.Session

  @doc "Send an async message to another agent by id."
  def send(target_id, message) do
    Session.send_message(target_id, message)
  end

  @doc "Synchronous request-reply with another agent."
  def call(target_id, message, timeout \\ 5_000) do
    case Registry.lookup(Raxol.Agent.Registry, target_id) do
      [{pid, _}] ->
        ref = make_ref()
        GenServer.cast(pid, {:send_message, {:call, self(), ref, message}})

        receive do
          {:agent_reply, ^ref, reply} -> {:ok, reply}
        after
          timeout -> {:error, :timeout}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @doc "Broadcast a message to all agents in a team."
  def broadcast_team(team_id, message) do
    Registry.select(Raxol.Agent.Registry, [
      {{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}
    ])
    |> Enum.each(fn {_id, pid} ->
      GenServer.cast(pid, {:send_message, {:team_broadcast, team_id, message}})
    end)

    :ok
  end
end
