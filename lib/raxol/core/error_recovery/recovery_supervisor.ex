defmodule Raxol.Core.ErrorRecovery.RecoverySupervisor do
  @moduledoc """
  Enhanced supervisor with intelligent error recovery strategies.

  This supervisor extends the standard OTP supervisor with:
  - Adaptive restart strategies based on error patterns
  - Context preservation across restarts
  - Dependency-aware restart ordering
  - Performance impact awareness
  - Self-healing mechanisms

  ## Features

  - Smart restart strategies that adapt to error frequency
  - Graceful degradation when components repeatedly fail
  - Context preservation to maintain state across restarts
  - Integration with error pattern learning
  - Performance monitoring integration

  ## Usage

      children = [
        {MyWorker, [context_key: :worker1]},
        {AnotherWorker, [depends_on: [:worker1]]}
      ]

      RecoverySupervisor.start_link(
        children: children,
        strategy: :adaptive_one_for_one,
        max_restarts: 5,
        max_seconds: 60
      )
  """

  use Supervisor
  alias Raxol.Core.ErrorPatternLearner
  alias Raxol.Core.ErrorRecovery.{ContextManager, DependencyGraph}
  alias Raxol.Core.Runtime.Log
  alias Raxol.Performance.AutomatedMonitor

  defstruct [
    :strategy,
    :max_restarts,
    :max_seconds,
    :children_specs,
    :restart_history,
    :context_manager,
    :dependency_graph,
    :performance_threshold,
    :degradation_mode
  ]

  @type recovery_strategy ::
          :adaptive_one_for_one
          | :adaptive_one_for_all
          | :adaptive_rest_for_one
          | :circuit_breaker

  @type restart_info :: %{
          child_id: term(),
          timestamp: DateTime.t(),
          error: term(),
          restart_count: non_neg_integer(),
          recovery_time_ms: non_neg_integer()
        }

  def start_link(opts) do
    children = Keyword.get(opts, :children, [])
    supervisor_opts = Keyword.drop(opts, [:children])

    Supervisor.start_link(__MODULE__, {children, supervisor_opts},
      name: __MODULE__
    )
  end

  @impl true
  def init({children, opts}) do
    strategy = Keyword.get(opts, :strategy, :adaptive_one_for_one)
    max_restarts = Keyword.get(opts, :max_restarts, 5)
    max_seconds = Keyword.get(opts, :max_seconds, 60)
    performance_threshold = Keyword.get(opts, :performance_threshold, 0.8)

    # Initialize context manager
    {:ok, context_manager} = ContextManager.start_link([])

    # Build dependency graph
    dependency_graph = DependencyGraph.build(children)

    # Initialize state
    state = %__MODULE__{
      strategy: strategy,
      max_restarts: max_restarts,
      max_seconds: max_seconds,
      children_specs: children,
      restart_history: [],
      context_manager: context_manager,
      dependency_graph: dependency_graph,
      performance_threshold: performance_threshold,
      degradation_mode: false
    }

    # Start children with enhanced supervision
    enhanced_children = enhance_children_specs(children, state)

    supervisor_strategy =
      adapt_supervisor_strategy(strategy, max_restarts, max_seconds)

    Log.info("Starting RecoverySupervisor with strategy: #{strategy}")

    Supervisor.init(enhanced_children, supervisor_strategy)
  end

  # Public API

  @doc """
  Manually trigger recovery for a specific child.
  """
  def recover_child(supervisor \\ __MODULE__, child_id) do
    GenServer.call(supervisor, {:recover_child, child_id})
  end

  @doc """
  Get recovery statistics for monitoring.
  """
  def get_recovery_stats(supervisor \\ __MODULE__) do
    GenServer.call(supervisor, :get_recovery_stats)
  end

  @doc """
  Enable or disable degradation mode.
  """
  def set_degradation_mode(supervisor \\ __MODULE__, enabled) do
    GenServer.cast(supervisor, {:set_degradation_mode, enabled})
  end

  @doc """
  Preserve context for a child before restart.
  """
  def preserve_context(supervisor \\ __MODULE__, child_id, context) do
    GenServer.cast(supervisor, {:preserve_context, child_id, context})
  end

  # Enhanced supervision callbacks

  def handle_child_exit(child_id, reason, state) do
    restart_info = %{
      child_id: child_id,
      timestamp: DateTime.utc_now(),
      error: reason,
      restart_count: count_recent_restarts(child_id, state),
      recovery_time_ms: 0
    }

    # Record error pattern
    ErrorPatternLearner.record_error(reason, %{
      child_id: child_id,
      supervisor: __MODULE__,
      restart_count: restart_info.restart_count
    })

    # Determine recovery strategy
    recovery_action = determine_recovery_action(restart_info, state)

    _ =
      case recovery_action do
        {:restart, strategy} ->
          execute_enhanced_restart(child_id, strategy, state)

        {:circuit_break, duration} ->
          execute_circuit_break(child_id, duration, state)

        {:graceful_degradation, fallback} ->
          execute_graceful_degradation(child_id, fallback, state)

        :escalate ->
          escalate_to_parent(child_id, reason, state)
      end

    # Update restart history
    updated_history =
      [restart_info | state.restart_history]
      # Keep last 100 restarts
      |> Enum.take(100)

    %{state | restart_history: updated_history}
  end

  # Private implementation

  defp enhance_children_specs(children, state) do
    Enum.map(children, fn child_spec ->
      enhance_child_spec(child_spec, state)
    end)
  end

  defp enhance_child_spec({module, args} = spec, state) do
    child_id = extract_child_id(spec)

    # Add recovery enhancement
    enhanced_args =
      [
        recovery_supervisor: self(),
        context_manager: state.context_manager,
        dependency_graph: state.dependency_graph
      ] ++ args

    %{
      id: child_id,
      start: {RecoveryWrapper, :start_link, [module, enhanced_args]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  defp enhance_child_spec(spec, _state) when is_map(spec) do
    # Already a proper child spec
    spec
  end

  defp extract_child_id({module, _args}), do: module

  defp adapt_supervisor_strategy(
         :adaptive_one_for_one,
         max_restarts,
         max_seconds
       ) do
    [
      strategy: :one_for_one,
      max_restarts: max_restarts,
      max_seconds: max_seconds
    ]
  end

  defp adapt_supervisor_strategy(
         :adaptive_one_for_all,
         max_restarts,
         max_seconds
       ) do
    [
      strategy: :one_for_all,
      max_restarts: max_restarts,
      max_seconds: max_seconds
    ]
  end

  defp adapt_supervisor_strategy(
         :adaptive_rest_for_one,
         max_restarts,
         max_seconds
       ) do
    [
      strategy: :rest_for_one,
      max_restarts: max_restarts,
      max_seconds: max_seconds
    ]
  end

  defp adapt_supervisor_strategy(:circuit_breaker, max_restarts, max_seconds) do
    [
      strategy: :one_for_one,
      max_restarts: max_restarts,
      max_seconds: max_seconds
    ]
  end

  defp count_recent_restarts(child_id, state) do
    cutoff = DateTime.add(DateTime.utc_now(), -60, :second)

    state.restart_history
    |> Enum.filter(fn restart ->
      restart.child_id == child_id and
        DateTime.compare(restart.timestamp, cutoff) == :gt
    end)
    |> length()
  end

  defp determine_recovery_action(restart_info, state) do
    cond do
      # Too many recent restarts - circuit break
      restart_info.restart_count >= 3 ->
        {:circuit_break, calculate_circuit_break_duration(restart_info)}

      # Performance impact detected - graceful degradation
      performance_impact_detected?(restart_info, state) ->
        {:graceful_degradation,
         determine_fallback(restart_info.child_id, state)}

      # Dependencies failed - check dependency strategy
      has_failed_dependencies?(restart_info.child_id, state) ->
        determine_dependency_action(restart_info.child_id, state)

      # Normal restart with adaptive strategy
      true ->
        {:restart, determine_restart_strategy(restart_info, state)}
    end
  end

  defp calculate_circuit_break_duration(restart_info) do
    # Exponential backoff based on restart count
    # 5 seconds
    base_duration = 5000
    backoff_factor = :math.pow(2, min(restart_info.restart_count, 6))
    round(base_duration * backoff_factor)
  end

  defp performance_impact_detected?(_restart_info, _state) do
    case AutomatedMonitor.get_status() do
      %{current_metrics: metrics} when not is_nil(metrics) ->
        # Check if current performance is below threshold
        render_performance = metrics.render_performance.avg_ms > 20.0
        memory_usage = metrics.memory_usage.total_mb > 50.0
        error_rate = metrics.error_rates.error_rate_percent > 2.0

        render_performance or memory_usage or error_rate

      _ ->
        false
    end
  end

  defp determine_fallback(child_id, state) do
    # Get fallback strategy from dependency graph
    DependencyGraph.get_fallback_strategy(state.dependency_graph, child_id)
  end

  defp has_failed_dependencies?(child_id, state) do
    dependencies =
      DependencyGraph.get_dependencies(state.dependency_graph, child_id)

    Enum.any?(dependencies, fn dep_id ->
      not child_running?(dep_id)
    end)
  end

  defp determine_dependency_action(child_id, state) do
    case DependencyGraph.get_restart_strategy(state.dependency_graph, child_id) do
      :wait_for_dependencies ->
        # Wait 10 seconds for dependencies
        {:circuit_break, 10_000}

      :restart_with_dependencies ->
        {:restart, :with_dependencies}

      :graceful_degradation ->
        {:graceful_degradation, determine_fallback(child_id, state)}

      :escalate ->
        :escalate

      _unknown ->
        # Unknown strategy - escalate to parent supervisor
        :escalate
    end
  end

  defp determine_restart_strategy(restart_info, state) do
    case state.strategy do
      :adaptive_one_for_one ->
        determine_adaptive_strategy(restart_info)

      strategy ->
        strategy
    end
  end

  defp determine_adaptive_strategy(restart_info) do
    cond do
      restart_info.restart_count == 0 ->
        :immediate

      restart_info.restart_count <= 2 ->
        :delayed

      true ->
        :careful
    end
  end

  defp execute_enhanced_restart(child_id, strategy, state) do
    start_time = System.monotonic_time(:millisecond)

    # Preserve context before restart
    context = ContextManager.get_context(child_id)

    case strategy do
      :immediate ->
        restart_child_immediately(child_id, context)

      :delayed ->
        schedule_delayed_restart(child_id, context, 1000)

      :careful ->
        execute_careful_restart(child_id, context, state)

      :with_dependencies ->
        restart_with_dependencies(child_id, context, state)
    end

    # Record recovery time
    recovery_time = System.monotonic_time(:millisecond) - start_time
    record_recovery_metrics(child_id, recovery_time)
  end

  defp restart_child_immediately(child_id, context) do
    Log.info("Immediately restarting child: #{child_id}")

    # Standard supervisor restart
    _ = Supervisor.restart_child(__MODULE__, child_id)

    # Restore context
    if context do
      send(child_id, {:restore_context, context})
    end
  end

  defp schedule_delayed_restart(child_id, context, delay) do
    Log.info("Scheduling delayed restart for #{child_id} in #{delay}ms")

    Process.send_after(self(), {:delayed_restart, child_id, context}, delay)
  end

  defp execute_careful_restart(child_id, context, state) do
    Log.info("Executing careful restart for #{child_id}")

    # Check system health before restart
    case check_system_health(state) do
      :healthy ->
        restart_child_immediately(child_id, context)

      :degraded ->
        # Wait for system to recover
        schedule_delayed_restart(child_id, context, 5000)

      :critical ->
        # Switch to graceful degradation
        execute_graceful_degradation(
          child_id,
          determine_fallback(child_id, state),
          state
        )
    end
  end

  defp restart_with_dependencies(child_id, context, state) do
    dependencies =
      DependencyGraph.get_dependencies(state.dependency_graph, child_id)

    # Restart dependencies first
    Enum.each(dependencies, fn dep_id ->
      if not child_running?(dep_id) do
        Supervisor.restart_child(__MODULE__, dep_id)
      end
    end)

    # Wait a bit for dependencies to stabilize
    Process.sleep(500)

    # Then restart the child
    restart_child_immediately(child_id, context)
  end

  defp execute_circuit_break(child_id, duration, _state) do
    Log.warning("Circuit breaking #{child_id} for #{duration}ms")

    # Store circuit break info
    _circuit_break_until =
      DateTime.add(DateTime.utc_now(), duration, :millisecond)

    # Schedule recovery attempt
    Process.send_after(self(), {:attempt_recovery, child_id}, duration)

    # Emit telemetry
    :telemetry.execute(
      [:raxol, :error_recovery, :circuit_break],
      %{duration: duration},
      %{child_id: child_id}
    )
  end

  defp execute_graceful_degradation(child_id, fallback, _state) do
    Log.info("Executing graceful degradation for #{child_id}")

    case fallback do
      :disable ->
        # Simply don't restart - system continues without this component
        :ok

      {:fallback_module, module} ->
        # Start a simpler fallback version
        start_fallback_child(child_id, module)

      {:notification, message} ->
        # Notify about degraded functionality
        broadcast_degradation_notice(child_id, message)
    end
  end

  defp escalate_to_parent(child_id, reason, _state) do
    Log.error("Escalating failure of #{child_id} to parent supervisor")

    # Let the parent supervisor handle this
    exit(reason)
  end

  defp check_system_health(_state) do
    case AutomatedMonitor.get_status() do
      %{current_metrics: metrics} when not is_nil(metrics) ->
        cond do
          metrics.error_rates.error_rate_percent > 5.0 ->
            :critical

          metrics.render_performance.avg_ms > 25.0 ->
            :degraded

          metrics.memory_usage.total_mb > 60.0 ->
            :degraded

          true ->
            :healthy
        end

      _ ->
        :healthy
    end
  end

  defp child_running?(child_id) do
    # Supervisor.which_children always returns a list
    children = Supervisor.which_children(__MODULE__)

    Enum.any?(children, fn
      {^child_id, _pid, _type, _modules} -> true
      _ -> false
    end)
  end

  defp start_fallback_child(child_id, fallback_module) do
    fallback_spec = %{
      id: :"#{child_id}_fallback",
      start: {fallback_module, :start_link, []},
      restart: :temporary,
      shutdown: 5000,
      type: :worker
    }

    Supervisor.start_child(__MODULE__, fallback_spec)
  end

  defp broadcast_degradation_notice(child_id, message) do
    :telemetry.execute(
      [:raxol, :error_recovery, :degradation],
      %{count: 1},
      %{child_id: child_id, message: message}
    )
  end

  defp record_recovery_metrics(child_id, recovery_time) do
    :telemetry.execute(
      [:raxol, :error_recovery, :restart],
      %{recovery_time_ms: recovery_time},
      %{child_id: child_id}
    )
  end
end
