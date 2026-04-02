defmodule Raxol.Agent.ProcessBehaviourTest do
  use ExUnit.Case, async: true

  defmodule DefaultAgent do
    use Raxol.Agent.UseProcess
  end

  defmodule CustomAgent do
    use Raxol.Agent.UseProcess

    @impl true
    def init(_opts), do: {:ok, %{initialized: true}}

    @impl true
    def observe(events, state) do
      {:ok, %{count: length(events)}, state}
    end

    @impl true
    def think(%{count: n}, state) when n > 0, do: {:act, :process, state}
    def think(_, state), do: {:wait, state}

    @impl true
    def act(:process, state), do: {:ok, %{state | initialized: false}}

    @impl true
    def receive_directive(:pause, state), do: {:defer, state}
    def receive_directive(_, state), do: {:ok, state}
  end

  describe "DefaultAgent (all defaults)" do
    test "init returns empty map" do
      assert {:ok, %{}} = DefaultAgent.init([])
    end

    test "observe returns empty observation" do
      assert {:ok, %{}, %{a: 1}} = DefaultAgent.observe([:event], %{a: 1})
    end

    test "think returns wait" do
      assert {:wait, %{}} = DefaultAgent.think(%{}, %{})
    end

    test "act returns ok" do
      assert {:ok, %{}} = DefaultAgent.act(:anything, %{})
    end

    test "receive_directive returns ok" do
      assert {:ok, %{}} = DefaultAgent.receive_directive(:whatever, %{})
    end

    test "context_snapshot returns state" do
      assert %{a: 1} = DefaultAgent.context_snapshot(%{a: 1})
    end

    test "restore_context returns ok with snapshot" do
      assert {:ok, %{a: 1}} = DefaultAgent.restore_context(%{a: 1})
    end

    test "on_takeover returns ok" do
      assert {:ok, %{}} = DefaultAgent.on_takeover(%{})
    end

    test "on_resume returns ok" do
      assert {:ok, %{}} = DefaultAgent.on_resume(%{})
    end
  end

  describe "CustomAgent (overridden callbacks)" do
    test "init returns custom state" do
      assert {:ok, %{initialized: true}} = CustomAgent.init([])
    end

    test "observe returns event count" do
      assert {:ok, %{count: 2}, %{}} = CustomAgent.observe([:a, :b], %{})
    end

    test "think acts when events present" do
      assert {:act, :process, %{}} = CustomAgent.think(%{count: 3}, %{})
    end

    test "think waits when no events" do
      assert {:wait, %{}} = CustomAgent.think(%{count: 0}, %{})
    end

    test "act processes action" do
      assert {:ok, %{initialized: false}} = CustomAgent.act(:process, %{initialized: true})
    end

    test "receive_directive defers on :pause" do
      assert {:defer, %{}} = CustomAgent.receive_directive(:pause, %{})
    end

    test "receive_directive accepts other directives" do
      assert {:ok, %{}} = CustomAgent.receive_directive(:go, %{})
    end
  end

  describe "behaviour annotation" do
    test "DefaultAgent implements ProcessBehaviour" do
      behaviours =
        DefaultAgent.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Raxol.Agent.ProcessBehaviour in behaviours
    end

    test "CustomAgent implements ProcessBehaviour" do
      behaviours =
        CustomAgent.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Raxol.Agent.ProcessBehaviour in behaviours
    end
  end
end
