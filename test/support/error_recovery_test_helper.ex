defmodule Raxol.Test.ErrorRecoveryTestHelper do
  @moduledoc """
  Test helper module for error recovery testing.

  Provides utilities for testing error recovery mechanisms, including
  fault injection, recovery scenario simulation, and assertion helpers.

  ## Features

  - Fault injection utilities
  - Recovery scenario builders
  - Performance impact simulation
  - Context preservation testing
  - Dependency failure simulation

  ## Usage

      use Raxol.Test.ErrorRecoveryTestHelper

      test "circuit breaker activates after multiple failures" do
        worker_pid = start_test_worker()

        inject_failures(worker_pid, count: 5, delay: 100)

        assert_circuit_breaker_active(worker_pid)
        assert_recovery_strategy_used(:circuit_break)
      end
  """

  import ExUnit.Assertions
  import ExUnit.Callbacks

  alias Raxol.Core.ErrorRecovery.{
    RecoverySupervisor,
    ContextManager
  }

  alias Raxol.Core.ErrorRecovery.EnhancedPatternLearner

  defmacro __using__(_opts) do
    quote do
      import Raxol.Test.ErrorRecoveryTestHelper
      alias Raxol.Test.ErrorRecoveryTestHelper.{TestWorker, FaultInjector}
    end
  end

  # Test Worker Implementation

  defmodule TestWorker do
    @moduledoc """
    A test worker that can simulate various failure scenarios.
    """

    use GenServer
    alias Raxol.Core.Runtime.Log

    defstruct [
      :id,
      :state,
      :failure_mode,
      :failure_count,
      :max_failures,
      :failure_delay,
      :context_data,
      :dependencies,
      :performance_impact
    ]

    def start_link(opts \\ []) do
      id = Keyword.get(opts, :id, make_ref())
      GenServer.start_link(__MODULE__, opts, name: {:global, id})
    end

    def get_state(pid) do
      GenServer.call(pid, :get_state)
    end

    def inject_failure(pid, failure_type \\ :runtime_error) do
      GenServer.cast(pid, {:inject_failure, failure_type})
    end

    def set_failure_mode(pid, mode, opts \\ []) do
      GenServer.cast(pid, {:set_failure_mode, mode, opts})
    end

    def update_context(pid, context) do
      GenServer.cast(pid, {:update_context, context})
    end

    def simulate_load(pid, duration_ms) do
      GenServer.cast(pid, {:simulate_load, duration_ms})
    end

    @impl true
    def init(opts) do
      state = %__MODULE__{
        id: Keyword.get(opts, :id, make_ref()),
        state: :running,
        failure_mode: Keyword.get(opts, :failure_mode, :none),
        failure_count: 0,
        max_failures: Keyword.get(opts, :max_failures, 0),
        failure_delay: Keyword.get(opts, :failure_delay, 0),
        context_data: Keyword.get(opts, :context_data, %{}),
        dependencies: Keyword.get(opts, :dependencies, []),
        performance_impact: Keyword.get(opts, :performance_impact, :low)
      }

      Log.debug("TestWorker started: #{inspect(state.id)}")

      {:ok, state}
    end

    @impl true
    def handle_call(:get_state, _from, state) do
      {:reply, state, state}
    end

    @impl true
    def handle_call({:restore_context, context}, _from, state) do
      Log.info("Restoring context for TestWorker: #{inspect(state.id)}")

      updated_state = %{
        state
        | context_data: Map.merge(state.context_data, context)
      }

      {:reply, :ok, updated_state}
    end

    @impl true
    def handle_cast({:inject_failure, failure_type}, state) do
      case failure_type do
        :runtime_error ->
          raise "Injected runtime error"

        :timeout ->
          # Simulate timeout
          Process.sleep(10_000)

        :memory_leak ->
          # Simulate memory allocation
          _large_data = for _ <- 1..100_000, do: :crypto.strong_rand_bytes(1024)
          {:noreply, state}

        :deadlock ->
          # Simulate deadlock by waiting indefinitely
          receive do
            :never_sent -> :ok
          end

        :dependency_failure ->
          # Simulate dependency failure
          exit(:dependency_unavailable)

        _ ->
          {:noreply, state}
      end
    end

    @impl true
    def handle_cast({:set_failure_mode, mode, opts}, state) do
      updated_state = %{
        state
        | failure_mode: mode,
          max_failures: Keyword.get(opts, :max_failures, state.max_failures),
          failure_delay: Keyword.get(opts, :failure_delay, state.failure_delay)
      }

      {:noreply, updated_state}
    end

    @impl true
    def handle_cast({:update_context, context}, state) do
      updated_context = Map.merge(state.context_data, context)
      updated_state = %{state | context_data: updated_context}

      {:noreply, updated_state}
    end

    @impl true
    def handle_cast({:simulate_load, duration_ms}, state) do
      # Simulate CPU load
      start_time = :erlang.monotonic_time(:millisecond)

      busy_wait(start_time, duration_ms)

      {:noreply, state}
    end

    @impl true
    def handle_info({:restore_context, context}, state) do
      Log.info("Restoring context for TestWorker: #{inspect(state.id)}")

      updated_state = %{
        state
        | context_data: Map.merge(state.context_data, context)
      }

      {:noreply, updated_state}
    end

    @impl true
    def handle_info(_msg, state) do
      # Check if we should fail based on failure mode
      maybe_fail(state)
    end

    defp maybe_fail(state) do
      case state.failure_mode do
        :periodic when state.failure_count < state.max_failures ->
          if state.failure_delay > 0, do: Process.sleep(state.failure_delay)

          updated_state = %{state | failure_count: state.failure_count + 1}

          case rem(state.failure_count, 3) do
            0 -> raise "Periodic failure #{state.failure_count}"
            _ -> {:noreply, updated_state}
          end

        :gradual_degradation ->
          # Gradually slow down responses
          delay = state.failure_count * 100
          Process.sleep(delay)

          updated_state = %{state | failure_count: state.failure_count + 1}
          {:noreply, updated_state}

        _ ->
          {:noreply, state}
      end
    end

    defp busy_wait(start_time, duration_ms) do
      if :erlang.monotonic_time(:millisecond) - start_time < duration_ms do
        # Busy work to simulate CPU load
        _ = :math.sin(:rand.uniform() * 1000)
        busy_wait(start_time, duration_ms)
      end
    end
  end

  # Fault Injection Utilities

  defmodule FaultInjector do
    @moduledoc """
    Utilities for injecting various types of faults into test scenarios.
    """

    def inject_failures(pid, opts \\ []) do
      count = Keyword.get(opts, :count, 1)
      delay = Keyword.get(opts, :delay, 100)
      failure_type = Keyword.get(opts, :type, :runtime_error)

      for _ <- 1..count do
        TestWorker.inject_failure(pid, failure_type)
        if delay > 0, do: Process.sleep(delay)
      end
    end

    def inject_cascade_failure(pids, delay \\ 50) do
      Enum.with_index(pids)
      |> Enum.each(fn {pid, index} ->
        Process.sleep(index * delay)
        TestWorker.inject_failure(pid, :dependency_failure)
      end)
    end

    def inject_performance_degradation(pid, severity \\ :medium) do
      duration =
        case severity do
          :low -> 100
          :medium -> 500
          :high -> 2000
        end

      TestWorker.simulate_load(pid, duration)
    end

    def inject_memory_pressure(_pid, size_mb \\ 10) do
      # Simulate memory pressure
      spawn(fn ->
        data = for _ <- 1..(size_mb * 1024), do: :crypto.strong_rand_bytes(1024)
        # Hold memory for 5 seconds
        Process.sleep(5000)
        # Keep reference to prevent GC
        data
      end)
    end
  end

  # Test Scenario Builders

  def create_test_recovery_supervisor(children \\ []) do
    default_children = [
      Supervisor.child_spec(
        {TestWorker, [id: :worker1, context_data: %{role: :primary}]},
        id: :worker1
      ),
      Supervisor.child_spec(
        {TestWorker,
         [
           id: :worker2,
           context_data: %{role: :secondary},
           depends_on: [:worker1]
         ]},
        id: :worker2
      )
    ]

    # Transform children to use Supervisor.child_spec for unique IDs
    transformed_children =
      Enum.map(children, fn
        {TestWorker, opts} ->
          id = Keyword.get(opts, :id, make_ref())
          Supervisor.child_spec({TestWorker, opts}, id: id)

        other ->
          other
      end)

    all_children = transformed_children ++ default_children

    {:ok, supervisor_pid} =
      RecoverySupervisor.start_link(
        children: all_children,
        strategy: :adaptive_one_for_one
      )

    supervisor_pid
  end

  def create_dependency_chain(count \\ 3) do
    Enum.map(1..count, fn i ->
      dependencies = if i == 1, do: [], else: [:"worker#{i - 1}"]

      {TestWorker,
       [
         id: :"worker#{i}",
         depends_on: dependencies,
         context_data: %{chain_position: i}
       ]}
    end)
  end

  def create_test_context_manager do
    {:ok, pid} = ContextManager.start_link()
    pid
  end

  # Assertion Helpers

  def assert_circuit_breaker_active(worker_pid, timeout \\ 5000) do
    # Check if the worker is in circuit breaker mode
    # This would depend on how circuit breaking is implemented
    assert_receive {:circuit_breaker_activated, ^worker_pid}, timeout
  end

  def assert_recovery_strategy_used(strategy, timeout \\ 5000) do
    assert_receive {:recovery_strategy, ^strategy}, timeout
  end

  def assert_context_preserved(
        _context_manager,
        key,
        expected_context,
        _timeout \\ 5000
      ) do
    context = ContextManager.get_context(key)
    assert context == expected_context
  end

  def assert_performance_impact_below(threshold_ms, timeout \\ 5000) do
    start_time = :erlang.monotonic_time(:millisecond)

    receive do
      :recovery_completed ->
        recovery_time = :erlang.monotonic_time(:millisecond) - start_time

        assert recovery_time < threshold_ms,
               "Recovery took #{recovery_time}ms, expected < #{threshold_ms}ms"
    after
      timeout ->
        flunk("Recovery did not complete within #{timeout}ms")
    end
  end

  def assert_dependency_order_preserved(expected_order) do
    receive do
      {:restart_order, actual_order} ->
        assert actual_order == expected_order
    after
      5000 ->
        flunk("Did not receive restart order within timeout")
    end
  end

  def assert_graceful_degradation_activated(component) do
    receive do
      {:graceful_degradation, ^component} ->
        :ok
    after
      5000 ->
        flunk("Graceful degradation was not activated for #{component}")
    end
  end

  # Performance Testing Helpers

  def measure_recovery_time(fun) do
    start_time = :erlang.monotonic_time(:millisecond)
    result = fun.()
    end_time = :erlang.monotonic_time(:millisecond)

    {result, end_time - start_time}
  end

  def simulate_system_load(cpu_percent \\ 50, duration_ms \\ 1000) do
    # Simulate system load by spawning processes that consume CPU
    num_processes = trunc(cpu_percent / 10)

    processes =
      for _ <- 1..num_processes do
        spawn(fn ->
          end_time = :erlang.monotonic_time(:millisecond) + duration_ms

          while(fn -> :erlang.monotonic_time(:millisecond) < end_time end)
        end)
      end

    # Clean up processes after duration
    spawn(fn ->
      Process.sleep(duration_ms + 100)
      Enum.each(processes, &Process.exit(&1, :kill))
    end)

    processes
  end

  def wait_for_recovery(timeout \\ 10_000) do
    receive do
      :recovery_completed ->
        :ok
    after
      timeout ->
        flunk("Recovery did not complete within #{timeout}ms")
    end
  end

  def wait_for_stabilization(min_duration \\ 1000) do
    # Wait for system to stabilize after recovery
    Process.sleep(min_duration)

    # Check that no more failures occur
    receive do
      {:failure, _} ->
        flunk("System not stable - additional failure occurred")
    after
      500 ->
        # System appears stable
        :ok
    end
  end

  # Test Data Generators

  def generate_error_contexts(count \\ 10) do
    for i <- 1..count do
      %{
        restart_count: :rand.uniform(5),
        performance_impact: Enum.random([:low, :medium, :high]),
        error_count: :rand.uniform(10),
        dependency_failure: :rand.uniform() < 0.3,
        system_load: :rand.uniform(),
        time_of_day: DateTime.utc_now(),
        scenario: "test_scenario_#{i}"
      }
    end
  end

  def generate_recovery_patterns(count \\ 20) do
    strategies = [
      :immediate_restart,
      :delayed_restart,
      :circuit_break,
      :graceful_degradation
    ]

    outcomes = [:success, :failure, :partial_success]

    for i <- 1..count do
      %{
        error_signature: "test_error_#{rem(i, 5)}",
        strategy: Enum.random(strategies),
        outcome: Enum.random(outcomes),
        context: Enum.random(generate_error_contexts(1)),
        recovery_time_ms: :rand.uniform(5000)
      }
    end
  end

  # Cleanup Helpers

  def cleanup_test_processes(pids) when is_list(pids) do
    Enum.each(pids, &cleanup_test_process/1)
  end

  def cleanup_test_process(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      Process.exit(pid, :kill)
    end
  end

  def cleanup_test_process({:global, name}) do
    case :global.whereis_name(name) do
      :undefined -> :ok
      pid -> cleanup_test_process(pid)
    end
  end

  def cleanup_test_process(_), do: :ok

  # Integration with ExUnit

  def setup_error_recovery_test do
    # Start necessary services for error recovery testing
    {:ok, _} = ContextManager.start_link(name: :test_context_manager)
    {:ok, _} = EnhancedPatternLearner.start_link(name: :test_pattern_learner)

    on_exit(fn ->
      cleanup_test_services()
    end)

    :ok
  end

  defp cleanup_test_services do
    services = [:test_context_manager, :test_pattern_learner]

    Enum.each(services, fn service ->
      case GenServer.whereis(service) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end
    end)
  end

  # Helper function for while loops
  defp while(condition) do
    if condition.() do
      while(condition)
    end
  end
end
