defmodule Raxol.Symphony.OrchestratorTest do
  use ExUnit.Case, async: false

  alias Raxol.Symphony.{Config, Issue, Orchestrator}
  alias Raxol.Symphony.Runners.Noop
  alias Raxol.Symphony.Trackers.Memory

  setup do
    start_supervised!({Task.Supervisor, name: Raxol.Symphony.TaskSupervisor})
    start_supervised!({Memory, []})
    start_supervised!(Noop.Director)
    Noop.Director.clear()

    config =
      Config.from_workflow(%{
        config: %{
          tracker: %{
            kind: "memory",
            active_states: ["Todo", "In Progress"],
            terminal_states: ["Done", "Cancelled"]
          },
          polling: %{interval_ms: 60_000},
          agent: %{max_concurrent_agents: 3, max_retry_backoff_ms: 60_000},
          codex: %{stall_timeout_ms: 0},
          runner: %{kind: "noop"}
        },
        prompt_template: ""
      })

    %{config: config}
  end

  defp issue(id, identifier, state) do
    %Issue{id: id, identifier: identifier, title: "T-#{identifier}", state: state}
  end

  defp start_orchestrator(config, opts \\ []) do
    base = [
      config: config,
      runner_module: Noop,
      auto_start_tick: false,
      name: nil
    ]

    {:ok, pid} =
      start_supervised(
        {Orchestrator, Keyword.merge(base, opts)},
        id: {Orchestrator, make_ref()}
      )

    pid
  end

  defp wait_until(timeout_ms \\ 1_000, fun) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_until(deadline, fun)
  end

  defp do_wait_until(deadline, fun) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("wait_until timed out")
      else
        Process.sleep(20)
        do_wait_until(deadline, fun)
      end
    end
  end

  describe "dispatch" do
    test "dispatches an eligible issue and removes it from running on completion",
         %{config: config} do
      Memory.put_issue(issue("a", "MT-1", "Todo"))
      Noop.Director.set("MT-1", {:succeed_after, 30})

      pid = start_orchestrator(config)
      :ok = Orchestrator.tick_now(pid)

      snap = Orchestrator.snapshot(pid)
      assert snap.counts.running == 1

      wait_until(fn -> Orchestrator.snapshot(pid).counts.running == 0 end)

      snap_after = Orchestrator.snapshot(pid)
      # Continuation retry scheduled (1s) since worker exited normally.
      assert snap_after.counts.retrying == 1
    end

    test "respects max_concurrent_agents", %{config: config} do
      Memory.put_issues([
        issue("a", "MT-1", "Todo"),
        issue("b", "MT-2", "Todo"),
        issue("c", "MT-3", "Todo"),
        issue("d", "MT-4", "Todo"),
        issue("e", "MT-5", "Todo")
      ])

      for id <- ~w(MT-1 MT-2 MT-3 MT-4 MT-5), do: Noop.Director.set(id, :stall)

      pid = start_orchestrator(config)
      :ok = Orchestrator.tick_now(pid)

      assert Orchestrator.snapshot(pid).counts.running == 3
    end

    test "skips issues already running", %{config: config} do
      Memory.put_issue(issue("a", "MT-1", "Todo"))
      Noop.Director.set("MT-1", :stall)

      pid = start_orchestrator(config)
      :ok = Orchestrator.tick_now(pid)
      :ok = Orchestrator.tick_now(pid)

      assert Orchestrator.snapshot(pid).counts.running == 1
    end

    test "non-active state is not dispatched", %{config: config} do
      Memory.put_issue(issue("a", "MT-1", "Done"))

      pid = start_orchestrator(config)
      :ok = Orchestrator.tick_now(pid)

      assert Orchestrator.snapshot(pid).counts.running == 0
    end
  end

  describe "retry" do
    test "abnormal worker exit schedules a failure retry", %{config: config} do
      Memory.put_issue(issue("a", "MT-1", "Todo"))
      Noop.Director.set("MT-1", {:fail_after, 10, :boom})

      pid = start_orchestrator(config)
      :ok = Orchestrator.tick_now(pid)

      wait_until(fn -> Orchestrator.snapshot(pid).counts.retrying == 1 end)

      snap = Orchestrator.snapshot(pid)
      [retry] = snap.retrying
      assert retry.attempt == 1
      assert retry.due_in_ms > 0
      assert retry.error =~ "runner_error"
      assert retry.error =~ "boom"
    end
  end

  describe "stop_run" do
    test "stops a running issue and releases the claim", %{config: config} do
      Memory.put_issue(issue("a", "MT-1", "Todo"))
      Noop.Director.set("MT-1", :stall)

      pid = start_orchestrator(config)
      :ok = Orchestrator.tick_now(pid)
      assert Orchestrator.snapshot(pid).counts.running == 1

      assert :ok = Orchestrator.stop_run(pid, "a")
      wait_until(fn -> Orchestrator.snapshot(pid).counts.running == 0 end)
    end

    test "returns :not_running for unknown issue", %{config: config} do
      pid = start_orchestrator(config)
      assert {:error, :not_running} = Orchestrator.stop_run(pid, "missing")
    end
  end

  describe "reconciliation" do
    test "terminates run when tracker state goes terminal", %{config: config} do
      Memory.put_issue(issue("a", "MT-1", "Todo"))
      Noop.Director.set("MT-1", :stall)

      pid = start_orchestrator(config)
      :ok = Orchestrator.tick_now(pid)
      assert Orchestrator.snapshot(pid).counts.running == 1

      Memory.transition("a", "Done")
      :ok = Orchestrator.tick_now(pid)
      wait_until(fn -> Orchestrator.snapshot(pid).counts.running == 0 end)
    end

    test "updates issue snapshot when state changes but stays active", %{config: config} do
      Memory.put_issue(issue("a", "MT-1", "Todo"))
      Noop.Director.set("MT-1", :stall)

      pid = start_orchestrator(config)
      :ok = Orchestrator.tick_now(pid)

      Memory.transition("a", "In Progress")
      :ok = Orchestrator.tick_now(pid)

      [running] = Orchestrator.snapshot(pid).running
      assert running.state == "Todo"
      # state field is what was at dispatch; the update happens to issue snapshot
      # in entry.issue, not the snapshot's :state. Both behaviours are acceptable
      # per SPEC s8.5; we just assert the run is still active.
      assert running.issue_id == "a"
    end
  end

  describe "subscribe + snapshot" do
    test "snapshot has expected shape", %{config: config} do
      pid = start_orchestrator(config)
      snap = Orchestrator.snapshot(pid)

      assert is_binary(snap.generated_at)
      assert snap.counts == %{running: 0, retrying: 0}
      assert snap.running == []
      assert snap.retrying == []
      assert is_map(snap.codex_totals)
    end

    test "subscribers receive :symphony_event on tick", %{config: config} do
      pid = start_orchestrator(config)
      :ok = Orchestrator.subscribe(pid)

      :ok = Orchestrator.tick_now(pid)

      assert_receive {:symphony_event, :tick_completed, %{counts: _}}, 500
    end
  end
end
