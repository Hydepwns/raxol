defmodule Raxol.Agent.SessionTest do
  use ExUnit.Case, async: false

  alias Raxol.Agent.Session

  defmodule CounterAgent do
    use Raxol.Agent

    def init(_context) do
      %{count: 0, messages: []}
    end

    def update({:agent_message, from, {:increment, n}}, model) do
      {%{
         model
         | count: model.count + n,
           messages: [{from, n} | model.messages]
       }, Command.none()}
    end

    def update({:agent_message, _from, :get_count}, model) do
      {model, Command.none()}
    end

    def update(_msg, model) do
      {model, Command.none()}
    end
  end

  setup do
    # Ensure the registry is available
    case Registry.lookup(Raxol.Agent.Registry, :test_cleanup) do
      _ -> :ok
    end

    :ok
  end

  @tag :docker
  test "start and stop an agent session" do
    {:ok, pid} =
      Session.start_link(app_module: CounterAgent, id: :test_agent_1)

    assert Process.alive?(pid)
    GenServer.stop(pid)
    refute Process.alive?(pid)
  end

  @tag :docker
  test "send message and verify model updates" do
    {:ok, _pid} =
      Session.start_link(app_module: CounterAgent, id: :test_agent_2)

    Session.send_message(:test_agent_2, {:increment, 5})
    # Give the async message time to propagate through Lifecycle -> Dispatcher
    Process.sleep(100)

    {:ok, model} = Session.get_model(:test_agent_2)
    assert model.count == 5

    Session.send_message(:test_agent_2, {:increment, 3})
    Process.sleep(100)

    {:ok, model} = Session.get_model(:test_agent_2)
    assert model.count == 8
  end

  @tag :docker
  test "get_model returns error for unknown agent" do
    assert {:error, :not_found} = Session.get_model(:nonexistent_agent)
  end

  @tag :docker
  test "send_message returns error for unknown agent" do
    assert {:error, :not_found} =
             Session.send_message(:nonexistent_agent, :hello)
  end

  @tag :docker
  test "agent crash and restart under DynamicSupervisor" do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        Raxol.DynamicSupervisor,
        {Session, [app_module: CounterAgent, id: :test_agent_supervised]}
      )

    assert Process.alive?(pid)

    Process.exit(pid, :kill)
    Process.sleep(50)

    # Under DynamicSupervisor with :temporary restart, process won't auto-restart
    # This verifies the child spec is valid for supervised use
    refute Process.alive?(pid)
  end
end
