defmodule Raxol.Core.ErrorRecovery.RecoveryWrapper do
  @moduledoc """
  Wrapper module that adds recovery capabilities to any GenServer process.

  This module wraps existing GenServers to provide enhanced error recovery
  features without requiring modifications to the original modules.

  ## Features

  - Automatic context preservation before termination
  - State restoration after restart
  - Error pattern recording
  - Performance impact monitoring
  - Graceful shutdown handling

  ## Usage

      # Start a wrapped process
      RecoveryWrapper.start_link(MyWorker, [
        worker_args: [arg1, arg2],
        context_key: :my_worker,
        recovery_supervisor: RecoverySupervisor
      ])
  """

  use GenServer
  alias Raxol.Core.Runtime.Log
  alias Raxol.Core.ErrorRecovery.ContextManager
  alias Raxol.Core.ErrorPatternLearner

  defstruct [
    :wrapped_module,
    :wrapped_pid,
    :context_key,
    :recovery_supervisor,
    :context_manager,
    :dependency_graph,
    :last_state_snapshot,
    :performance_baseline,
    :error_count,
    :start_time
  ]

  @type wrapper_opts :: [
    worker_args: term(),
    context_key: term(),
    recovery_supervisor: pid() | atom(),
    context_manager: pid() | atom(),
    dependency_graph: term(),
    snapshot_interval: pos_integer()
  ]

  # Public API

  def start_link(wrapped_module, opts \\ []) do
    GenServer.start_link(__MODULE__, {wrapped_module, opts})
  end

  @doc """
  Get the current state of the wrapped process.
  """
  def get_wrapped_state(wrapper_pid) do
    GenServer.call(wrapper_pid, :get_wrapped_state)
  end

  @doc """
  Manually trigger a state snapshot.
  """
  def snapshot_state(wrapper_pid) do
    GenServer.cast(wrapper_pid, :snapshot_state)
  end

  @doc """
  Get recovery statistics for the wrapped process.
  """
  def get_recovery_stats(wrapper_pid) do
    GenServer.call(wrapper_pid, :get_recovery_stats)
  end

  # GenServer implementation

  @impl true
  def init({wrapped_module, opts}) do
    worker_args = Keyword.get(opts, :worker_args, [])
    context_key = Keyword.get(opts, :context_key, wrapped_module)
    recovery_supervisor = Keyword.get(opts, :recovery_supervisor)
    context_manager = Keyword.get(opts, :context_manager)
    dependency_graph = Keyword.get(opts, :dependency_graph)
    snapshot_interval = Keyword.get(opts, :snapshot_interval, 30_000)

    # Start the wrapped process
    case start_wrapped_process(wrapped_module, worker_args) do
      {:ok, wrapped_pid} ->
        # Set up monitoring
        Process.monitor(wrapped_pid)

        # Schedule periodic state snapshots
        schedule_snapshot(snapshot_interval)

        # Try to restore previous context
        restore_context_if_available(context_key, wrapped_pid, context_manager)

        state = %__MODULE__{
          wrapped_module: wrapped_module,
          wrapped_pid: wrapped_pid,
          context_key: context_key,
          recovery_supervisor: recovery_supervisor,
          context_manager: context_manager,
          dependency_graph: dependency_graph,
          last_state_snapshot: nil,
          performance_baseline: capture_performance_baseline(),
          error_count: 0,
          start_time: DateTime.utc_now()
        }

        Log.module_info("RecoveryWrapper started for #{wrapped_module}")

        {:ok, state}

      {:error, reason} ->
        Log.module_error("Failed to start wrapped process #{wrapped_module}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:get_wrapped_state, _from, state) do
    wrapped_state = get_state_from_wrapped_process(state.wrapped_pid)
    {:reply, wrapped_state, state}
  end

  @impl true
  def handle_call(:get_recovery_stats, _from, state) do
    uptime_seconds = DateTime.diff(DateTime.utc_now(), state.start_time)

    stats = %{
      wrapped_module: state.wrapped_module,
      wrapped_pid: state.wrapped_pid,
      uptime_seconds: uptime_seconds,
      error_count: state.error_count,
      last_snapshot: state.last_state_snapshot,
      performance_baseline: state.performance_baseline,
      context_key: state.context_key
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(request, from, state) do
    # Forward calls to wrapped process
    case forward_call_to_wrapped(state.wrapped_pid, request, from) do
      :ok ->
        {:noreply, state}

      {:error, reason} ->
        # Handle forwarding error
        handle_wrapped_error(reason, state)
    end
  end

  @impl true
  def handle_cast(:snapshot_state, state) do
    new_state = capture_state_snapshot(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:restore_context, context}, state) do
    restore_context_to_wrapped(state.wrapped_pid, context)
    {:noreply, state}
  end

  @impl true
  def handle_cast(msg, state) do
    # Forward casts to wrapped process
    case forward_cast_to_wrapped(state.wrapped_pid, msg) do
      :ok ->
        {:noreply, state}

      {:error, reason} ->
        handle_wrapped_error(reason, state)
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{wrapped_pid: pid} = state) do
    Log.module_warning("Wrapped process #{state.wrapped_module} terminated: #{inspect(reason)}")

    # Preserve context before notifying supervisor
    preserve_final_context(state)

    # Record error pattern
    ErrorPatternLearner.record_error(reason, %{
      module: state.wrapped_module,
      wrapper: self(),
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.start_time),
      error_count: state.error_count
    })

    # Notify recovery supervisor about the failure
    notify_recovery_supervisor(state, reason)

    # Stop this wrapper - supervisor will restart us
    {:stop, reason, state}
  end

  @impl true
  def handle_info(:snapshot_state, state) do
    new_state = capture_state_snapshot(state)

    # Schedule next snapshot
    schedule_snapshot(30_000)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    # Forward other messages to wrapped process
    case forward_info_to_wrapped(state.wrapped_pid, msg) do
      :ok ->
        {:noreply, state}

      {:error, reason} ->
        handle_wrapped_error(reason, state)
    end
  end

  @impl true
  def terminate(reason, state) do
    Log.module_info("RecoveryWrapper terminating: #{inspect(reason)}")

    # Preserve final context
    preserve_final_context(state)

    # Gracefully shutdown wrapped process if still alive
    if Process.alive?(state.wrapped_pid) do
      graceful_shutdown(state.wrapped_pid)
    end

    :ok
  end

  # Private implementation

  defp start_wrapped_process(module, args) do
    case module.start_link(args) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
      other -> {:error, {:unexpected_response, other}}
    end
  end

  defp restore_context_if_available(context_key, wrapped_pid, context_manager) do
    case ContextManager.get_context(context_manager, context_key) do
      nil ->
        Log.module_debug("No previous context found for #{context_key}")

      context ->
        Log.module_info("Restoring context for #{context_key}")
        restore_context_to_wrapped(wrapped_pid, context)
    end
  end

  defp restore_context_to_wrapped(wrapped_pid, context) do
    # Try to restore context by sending a message
    # The wrapped process should handle {:restore_context, context}
    send(wrapped_pid, {:restore_context, context})
  end

  defp capture_performance_baseline do
    %{
      memory_usage: :erlang.memory(:total),
      message_queue_len: Process.info(self(), :message_queue_len),
      timestamp: DateTime.utc_now()
    }
  end

  defp get_state_from_wrapped_process(wrapped_pid) do
    # Try to get state from wrapped process
    # This assumes the wrapped process responds to :get_state
    try do
      GenServer.call(wrapped_pid, :get_state, 1000)
    catch
      :exit, {:timeout, _} ->
        {:error, :timeout}

      :exit, reason ->
        {:error, reason}
    end
  end

  defp capture_state_snapshot(state) do
    case get_state_from_wrapped_process(state.wrapped_pid) do
      {:error, _reason} ->
        # Can't get state, keep previous snapshot
        state

      wrapped_state ->
        # Store context in context manager
        ContextManager.store_context(
          state.context_manager,
          state.context_key,
          wrapped_state
        )

        %{state | last_state_snapshot: DateTime.utc_now()}
    end
  end

  defp preserve_final_context(state) do
    # Capture final state before termination
    case get_state_from_wrapped_process(state.wrapped_pid) do
      {:error, _reason} ->
        Log.module_debug("Could not capture final state for #{state.context_key}")

      final_state ->
        ContextManager.store_context(
          state.context_manager,
          state.context_key,
          final_state,
          ttl_ms: 600_000 # Keep final context for 10 minutes
        )

        Log.module_info("Final context preserved for #{state.context_key}")
    end
  end

  defp notify_recovery_supervisor(state, reason) do
    if state.recovery_supervisor do
      # Notify the recovery supervisor about the failure
      send(state.recovery_supervisor, {
        :child_failure,
        state.context_key,
        reason,
        %{
          error_count: state.error_count,
          uptime: DateTime.diff(DateTime.utc_now(), state.start_time),
          performance_baseline: state.performance_baseline
        }
      })
    end
  end

  defp graceful_shutdown(wrapped_pid) do
    # Try graceful shutdown first
    try do
      GenServer.stop(wrapped_pid, :normal, 5000)
    catch
      :exit, _reason ->
        # Force kill if graceful shutdown fails
        Process.exit(wrapped_pid, :kill)
    end
  end

  defp forward_call_to_wrapped(wrapped_pid, request, from) do
    try do
      # Forward the call and let GenServer handle the response
      result = GenServer.call(wrapped_pid, request)
      GenServer.reply(from, result)
      :ok
    catch
      :exit, reason ->
        {:error, reason}
    end
  end

  defp forward_cast_to_wrapped(wrapped_pid, msg) do
    try do
      GenServer.cast(wrapped_pid, msg)
      :ok
    catch
      :exit, reason ->
        {:error, reason}
    end
  end

  defp forward_info_to_wrapped(wrapped_pid, msg) do
    try do
      send(wrapped_pid, msg)
      :ok
    catch
      :exit, reason ->
        {:error, reason}
    end
  end

  defp handle_wrapped_error(reason, state) do
    Log.module_warning("Error communicating with wrapped process: #{inspect(reason)}")

    updated_state = %{state | error_count: state.error_count + 1}

    # Check if we should terminate due to too many errors
    if updated_state.error_count >= 5 do
      {:stop, :too_many_errors, updated_state}
    else
      {:noreply, updated_state}
    end
  end

  defp schedule_snapshot(interval) do
    Process.send_after(self(), :snapshot_state, interval)
  end
end