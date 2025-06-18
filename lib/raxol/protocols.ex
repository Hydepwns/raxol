defmodule Raxol.Protocols do
  @moduledoc '''
  Protocols module for managing protocols.
  '''

  alias Raxol.Protocols.Protocol
  alias UUID

  @agent_name __MODULE__.Agent

  # Ensure the Agent is started
  defp ensure_started do
    case Process.whereis(@agent_name) do
      nil ->
        Agent.start_link(fn -> %{} end, name: @agent_name)

      _pid ->
        :ok
    end
  end

  def list_protocols do
    ensure_started()
    Agent.get(@agent_name, &Map.values(&1))
  end

  def get_protocol(id) do
    ensure_started()
    Agent.get(@agent_name, &Map.get(&1, id))
  end

  def create_protocol(attrs) do
    ensure_started()

    protocol =
      attrs
      |> Map.put_new(:id, UUID.uuid4())
      |> Map.put_new(:created_at, DateTime.utc_now())
      |> Map.put_new(:updated_at, DateTime.utc_now())
      |> Protocol.new()

    Agent.update(@agent_name, &Map.put(&1, protocol.id, protocol))
    protocol
  end

  def update_protocol(id, attrs) do
    ensure_started()

    Agent.get_and_update(@agent_name, fn protocols ->
      case Map.get(protocols, id) do
        nil ->
          {nil, protocols}

        protocol ->
          updated =
            protocol
            |> Map.merge(attrs)
            |> Map.put(:updated_at, DateTime.utc_now())

          {updated, Map.put(protocols, id, updated)}
      end
    end)
  end

  def delete_protocol(id) do
    ensure_started()

    Agent.get_and_update(@agent_name, fn protocols ->
      {Map.get(protocols, id), Map.delete(protocols, id)}
    end)

    :ok
  end
end
