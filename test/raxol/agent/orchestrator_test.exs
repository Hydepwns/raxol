defmodule Raxol.Agent.OrchestratorTest do
  use ExUnit.Case, async: false

  alias Raxol.Agent.Orchestrator
  # Minimal agent for orchestrator tests
  defmodule SimpleAgent do
    def init(_opts), do: {:ok, %{status: :idle}}
    def observe(_events, state), do: {:ok, %{}, state}
    def think(_observation, state), do: {:wait, state}
    def act(_action, state), do: {:ok, state}
    def receive_directive(_directive, state), do: {:ok, state}
    def on_takeover(state), do: {:ok, Map.put(state, :taken_over, true)}
    def on_resume(state), do: {:ok, Map.put(state, :resumed, true)}
    def context_snapshot(state), do: state
    def restore_context(snapshot), do: {:ok, snapshot}
  end

  setup do
    Raxol.Agent.ContextStore.init()

    case Registry.start_link(keys: :unique, name: Raxol.Agent.Registry) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    start_supervised!({DynamicSupervisor, name: Raxol.Agent.DynSup, strategy: :one_for_one})

    orch = start_supervised!(Orchestrator)
    %{orch: orch}
  end

  describe "spawn_agent/4" do
    test "spawns an agent and assigns a pane", %{orch: orch} do
      assert {:ok, :scout} =
               Orchestrator.spawn_agent(orch, :scout, SimpleAgent, tick_ms: 50_000)

      layout = Orchestrator.get_layout(orch)
      assert layout.agent_count == 1
      assert Map.has_key?(layout.panes, :scout)
    end

    test "auto-focuses the first agent", %{orch: orch} do
      Orchestrator.spawn_agent(orch, :first, SimpleAgent, tick_ms: 50_000)

      layout = Orchestrator.get_layout(orch)
      assert layout.focused == :first
    end

    test "rejects duplicate agent ids", %{orch: orch} do
      {:ok, _} = Orchestrator.spawn_agent(orch, :dup, SimpleAgent, tick_ms: 50_000)

      assert {:error, :already_exists} =
               Orchestrator.spawn_agent(orch, :dup, SimpleAgent, tick_ms: 50_000)
    end
  end

  describe "kill_agent/2" do
    test "removes the agent and its pane", %{orch: orch} do
      {:ok, _} = Orchestrator.spawn_agent(orch, :doomed, SimpleAgent, tick_ms: 50_000)

      :ok = Orchestrator.kill_agent(orch, :doomed)

      layout = Orchestrator.get_layout(orch)
      assert layout.agent_count == 0
      refute Map.has_key?(layout.panes, :doomed)
    end

    test "shifts focus when focused agent is killed", %{orch: orch} do
      {:ok, _} = Orchestrator.spawn_agent(orch, :a1, SimpleAgent, tick_ms: 50_000)
      {:ok, _} = Orchestrator.spawn_agent(orch, :a2, SimpleAgent, tick_ms: 50_000)

      Orchestrator.focus_pane(orch, :a1)
      Orchestrator.kill_agent(orch, :a1)

      layout = Orchestrator.get_layout(orch)
      # Focus should shift to remaining agent
      assert layout.focused == :a2
    end
  end

  describe "focus_pane/2" do
    test "switches focused pane", %{orch: orch} do
      {:ok, _} = Orchestrator.spawn_agent(orch, :p1, SimpleAgent, tick_ms: 50_000)
      {:ok, _} = Orchestrator.spawn_agent(orch, :p2, SimpleAgent, tick_ms: 50_000)

      :ok = Orchestrator.focus_pane(orch, :p2)

      layout = Orchestrator.get_layout(orch)
      assert layout.focused == :p2
    end

    test "rejects invalid pane", %{orch: orch} do
      assert {:error, :pane_not_found} = Orchestrator.focus_pane(orch, :nonexistent)
    end
  end

  describe "pilot_takeover/1 and pilot_release/1" do
    test "takeover puts orchestrator in takeover mode", %{orch: orch} do
      {:ok, _} = Orchestrator.spawn_agent(orch, :target, SimpleAgent, tick_ms: 50_000)

      :ok = Orchestrator.pilot_takeover(orch)

      layout = Orchestrator.get_layout(orch)
      assert layout.pilot_mode == :takeover
    end

    test "release returns to observe mode", %{orch: orch} do
      {:ok, _} = Orchestrator.spawn_agent(orch, :target, SimpleAgent, tick_ms: 50_000)

      :ok = Orchestrator.pilot_takeover(orch)
      :ok = Orchestrator.pilot_release(orch)

      layout = Orchestrator.get_layout(orch)
      assert layout.pilot_mode == :observe
    end

    test "takeover fails without focused pane", %{orch: orch} do
      assert {:error, :no_focused_pane} = Orchestrator.pilot_takeover(orch)
    end
  end

  describe "send_directive/3" do
    test "sends directive to a specific agent", %{orch: orch} do
      {:ok, _} = Orchestrator.spawn_agent(orch, :worker, SimpleAgent, tick_ms: 50_000)

      assert :ok = Orchestrator.send_directive(orch, :worker, {:task, "analyze"})
    end

    test "returns error for unknown agent", %{orch: orch} do
      assert {:error, :not_found} =
               Orchestrator.send_directive(orch, :ghost, {:task, "analyze"})
    end
  end

  describe "broadcast_directive/2" do
    test "sends directive to all agents", %{orch: orch} do
      {:ok, _} = Orchestrator.spawn_agent(orch, :w1, SimpleAgent, tick_ms: 50_000)
      {:ok, _} = Orchestrator.spawn_agent(orch, :w2, SimpleAgent, tick_ms: 50_000)

      # Should not raise
      :ok = Orchestrator.broadcast_directive(orch, {:priority, :high})
    end
  end

  describe "send_input/2" do
    test "routes input to focused agent during takeover", %{orch: orch} do
      fake_terminal = spawn(fn -> Process.sleep(:infinity) end)

      {:ok, _} =
        Orchestrator.spawn_agent(orch, :input_target, SimpleAgent,
          tick_ms: 50_000,
          terminal_pid: fake_terminal
        )

      :ok = Orchestrator.pilot_takeover(orch)
      assert :ok = Orchestrator.send_input(orch, "hello")
    end

    test "rejects input when not in takeover mode", %{orch: orch} do
      {:ok, _} =
        Orchestrator.spawn_agent(orch, :no_takeover, SimpleAgent, tick_ms: 50_000)

      assert {:error, :not_in_takeover} = Orchestrator.send_input(orch, "hello")
    end

    test "rejects input with no focused pane", %{orch: orch} do
      assert {:error, :not_in_takeover} = Orchestrator.send_input(orch, "hello")
    end

    test "returns error when pane has no terminal", %{orch: orch} do
      {:ok, _} =
        Orchestrator.spawn_agent(orch, :no_term, SimpleAgent, tick_ms: 50_000)

      :ok = Orchestrator.pilot_takeover(orch)
      assert {:error, :no_terminal} = Orchestrator.send_input(orch, "hello")
    end
  end

  describe "get_statuses/1" do
    test "returns status for all agents", %{orch: orch} do
      {:ok, _} = Orchestrator.spawn_agent(orch, :s1, SimpleAgent, tick_ms: 50_000)
      {:ok, _} = Orchestrator.spawn_agent(orch, :s2, SimpleAgent, tick_ms: 50_000)

      statuses = Orchestrator.get_statuses(orch)

      assert Map.has_key?(statuses, :s1)
      assert Map.has_key?(statuses, :s2)
      assert statuses[:s1].agent_id == :s1
    end
  end
end
