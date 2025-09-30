defmodule Raxol.Core.ErrorRecovery.RecoverySupervisorTest do
  use ExUnit.Case, async: false
  use Raxol.Test.ErrorRecoveryTestHelper

  alias Raxol.Core.ErrorRecovery.{RecoverySupervisor, ContextManager}

  describe "adaptive restart strategies" do
    setup do
      setup_error_recovery_test()
    end

    test "uses immediate restart for first failure" do
      children = [
        {TestWorker, [id: :immediate_test, context_data: %{test: "immediate"}]}
      ]

      supervisor_pid = create_test_recovery_supervisor(children)

      worker_pid = get_worker_pid(supervisor_pid, :immediate_test)

      # First failure should trigger immediate restart
      TestWorker.inject_failure(worker_pid, :runtime_error)

      # Verify worker is restarted quickly
      Process.sleep(100)
      new_worker_pid = get_worker_pid(supervisor_pid, :immediate_test)

      assert worker_pid != new_worker_pid
      assert Process.alive?(new_worker_pid)

      cleanup_test_process(supervisor_pid)
    end

    test "uses delayed restart after multiple failures" do
      children = [
        {TestWorker, [id: :delayed_test, context_data: %{test: "delayed"}]}
      ]

      supervisor_pid = create_test_recovery_supervisor(children)

      worker_pid = get_worker_pid(supervisor_pid, :delayed_test)

      # Inject multiple failures to trigger delayed restart
      for _ <- 1..3 do
        TestWorker.inject_failure(worker_pid, :runtime_error)
        Process.sleep(50)
        worker_pid = get_worker_pid(supervisor_pid, :delayed_test)
      end

      # Should now use delayed restart strategy
      start_time = :erlang.monotonic_time(:millisecond)
      TestWorker.inject_failure(worker_pid, :runtime_error)

      # Wait for restart
      Process.sleep(2000)
      recovery_time = :erlang.monotonic_time(:millisecond) - start_time

      # Delayed restart should take longer than immediate
      assert recovery_time > 1000

      cleanup_test_process(supervisor_pid)
    end

    test "activates circuit breaker after excessive failures" do
      children = [
        {TestWorker, [id: :circuit_test, context_data: %{test: "circuit"}]}
      ]

      supervisor_pid = create_test_recovery_supervisor(children)

      worker_pid = get_worker_pid(supervisor_pid, :circuit_test)

      # Inject many failures to trigger circuit breaker
      for _ <- 1..5 do
        TestWorker.inject_failure(worker_pid, :runtime_error)
        Process.sleep(100)
        worker_pid = get_worker_pid(supervisor_pid, :circuit_test)
      end

      # Circuit breaker should be active
      # Worker should not restart immediately
      TestWorker.inject_failure(worker_pid, :runtime_error)
      Process.sleep(500)

      # Should receive circuit breaker notification
      assert_circuit_breaker_active(worker_pid)

      cleanup_test_process(supervisor_pid)
    end
  end

  describe "context preservation" do
    setup do
      setup_error_recovery_test()
    end

    test "preserves context across restarts" do
      test_context = %{user_sessions: ["session1", "session2"], cache_data: "important"}

      children = [
        {TestWorker, [id: :context_test, context_data: test_context]}
      ]

      supervisor_pid = create_test_recovery_supervisor(children)
      context_manager = create_test_context_manager()

      worker_pid = get_worker_pid(supervisor_pid, :context_test)

      # Store additional context
      TestWorker.update_context(worker_pid, %{runtime_data: "preserved"})

      # Trigger restart
      TestWorker.inject_failure(worker_pid, :runtime_error)

      # Wait for restart and context restoration
      Process.sleep(1000)

      new_worker_pid = get_worker_pid(supervisor_pid, :context_test)
      new_state = TestWorker.get_state(new_worker_pid)

      # Context should be preserved
      assert Map.has_key?(new_state.context_data, :user_sessions)
      assert Map.has_key?(new_state.context_data, :cache_data)

      cleanup_test_process(supervisor_pid)
      cleanup_test_process(context_manager)
    end

    test "context has appropriate TTL" do
      context_manager = create_test_context_manager()

      # Store context with short TTL
      ContextManager.store_context(context_manager, :ttl_test, %{data: "expires"}, ttl_ms: 100)

      # Should exist immediately
      assert ContextManager.has_context?(context_manager, :ttl_test)

      # Should expire after TTL
      Process.sleep(200)
      refute ContextManager.has_context?(context_manager, :ttl_test)

      cleanup_test_process(context_manager)
    end
  end

  describe "dependency-aware recovery" do
    setup do
      setup_error_recovery_test()
    end

    test "respects dependency order during recovery" do
      children = create_dependency_chain(3)

      supervisor_pid = create_test_recovery_supervisor(children)

      # Get all worker PIDs
      worker1_pid = get_worker_pid(supervisor_pid, :worker1)
      worker2_pid = get_worker_pid(supervisor_pid, :worker2)
      worker3_pid = get_worker_pid(supervisor_pid, :worker3)

      # Fail the first worker in the chain
      TestWorker.inject_failure(worker1_pid, :dependency_failure)

      # Should restart in dependency order
      assert_dependency_order_preserved([:worker1, :worker2, :worker3])

      cleanup_test_process(supervisor_pid)
    end

    test "handles circular dependencies gracefully" do
      # Create circular dependency (should be detected and handled)
      children = [
        {TestWorker, [id: :circular1, depends_on: [:circular2]]},
        {TestWorker, [id: :circular2, depends_on: [:circular1]]}
      ]

      # Should not crash despite circular dependency
      assert {:ok, supervisor_pid} = RecoverySupervisor.start_link(
        children: children,
        strategy: :adaptive_one_for_one
      )

      cleanup_test_process(supervisor_pid)
    end
  end

  describe "performance-aware recovery" do
    setup do
      setup_error_recovery_test()
    end

    test "uses graceful degradation under high load" do
      children = [
        {TestWorker, [id: :performance_test, performance_impact: :high]}
      ]

      supervisor_pid = create_test_recovery_supervisor(children)

      # Simulate high system load
      _load_processes = simulate_system_load(80, 2000)

      worker_pid = get_worker_pid(supervisor_pid, :performance_test)

      # Inject performance degradation
      FaultInjector.inject_performance_degradation(worker_pid, :high)

      # Should trigger graceful degradation
      TestWorker.inject_failure(worker_pid, :runtime_error)

      assert_graceful_degradation_activated(:performance_test)

      cleanup_test_process(supervisor_pid)
    end

    test "recovery time stays within acceptable bounds" do
      children = [
        {TestWorker, [id: :timing_test]}
      ]

      supervisor_pid = create_test_recovery_supervisor(children)

      worker_pid = get_worker_pid(supervisor_pid, :timing_test)

      {_result, recovery_time} = measure_recovery_time(fn ->
        TestWorker.inject_failure(worker_pid, :runtime_error)
        wait_for_recovery(5000)
      end)

      # Recovery should complete within reasonable time
      assert recovery_time < 3000

      cleanup_test_process(supervisor_pid)
    end
  end

  describe "cascade failure prevention" do
    setup do
      setup_error_recovery_test()
    end

    test "prevents cascade failures in dependency chain" do
      children = create_dependency_chain(5)

      supervisor_pid = create_test_recovery_supervisor(children)

      # Inject cascade failure
      worker_pids = for i <- 1..5, do: get_worker_pid(supervisor_pid, :"worker#{i}")

      FaultInjector.inject_cascade_failure(worker_pids, 100)

      # System should stabilize and not cascade indefinitely
      wait_for_stabilization(2000)

      # Verify at least some workers are running
      running_workers = Enum.count(worker_pids, &Process.alive?/1)
      assert running_workers >= 2

      cleanup_test_process(supervisor_pid)
    end
  end

  # Helper functions

  defp get_worker_pid(supervisor_pid, worker_id) do
    case Supervisor.which_children(supervisor_pid) do
      children when is_list(children) ->
        case Enum.find(children, fn {id, _, _, _} -> id == worker_id end) do
          {_, pid, _, _} when is_pid(pid) -> pid
          _ -> nil
        end

      _ ->
        nil
    end
  end
end