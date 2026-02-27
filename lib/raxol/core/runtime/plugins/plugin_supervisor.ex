defmodule Raxol.Core.Runtime.Plugins.PluginSupervisor do
  @moduledoc """
  Supervisor for plugin tasks and processes.

  This module provides isolation for plugin operations, ensuring that a plugin crash
  doesn't destabilize the core application. All plugin operations that could fail
  (initialization, event handling, cleanup) should run through this supervisor.

  ## Design

  Uses `Task.Supervisor` for fire-and-forget and async plugin operations:
  - Plugin initialization
  - Event handling
  - Scheduled tasks
  - Cleanup operations

  ## Benefits

  - **Crash Isolation**: Plugin crashes don't bring down the main application
  - **Timeout Control**: Operations have configurable timeouts
  - **Logging**: All crashes are logged with plugin context
  - **Metrics**: Crash counts tracked for monitoring

  ## Usage

      # Start plugin initialization in isolation
      {:ok, result} = PluginSupervisor.run_plugin_task(:my_plugin, fn ->
        MyPlugin.init(%{})
      end)

      # Fire and forget (for side-effect operations)
      PluginSupervisor.async_plugin_task(:my_plugin, fn ->
        MyPlugin.on_event(event)
      end)

      # With custom timeout
      PluginSupervisor.run_plugin_task(:my_plugin, fn -> slow_op() end, timeout: 10_000)

  """

  use Supervisor

  alias Raxol.Core.Runtime.Log

  @task_supervisor_name Raxol.Core.Runtime.Plugins.TaskSupervisor
  @default_timeout 5_000

  # ============================================================================
  # Supervisor API
  # ============================================================================

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      {Task.Supervisor,
       name: @task_supervisor_name, max_restarts: 100, max_seconds: 60}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Runs a plugin task synchronously with crash isolation.

  Returns `{:ok, result}` on success, or `{:error, reason}` on failure.
  The task runs under the Task.Supervisor, so crashes are isolated.

  ## Options

    * `:timeout` - Maximum time in milliseconds (default: 5000)

  ## Examples

      {:ok, state} = PluginSupervisor.run_plugin_task(:my_plugin, fn ->
        MyPlugin.init(%{config: "value"})
      end)

      {:error, {:crashed, %RuntimeError{}}} = PluginSupervisor.run_plugin_task(:bad_plugin, fn ->
        raise "oops"
      end)

  """
  @spec run_plugin_task(atom(), (-> term()), keyword()) ::
          {:ok, term()} | {:error, term()}
  def run_plugin_task(plugin_id, func, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    task =
      Task.Supervisor.async_nolink(@task_supervisor_name, fn ->
        func.()
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        {:ok, result}

      {:exit, reason} ->
        log_plugin_crash(plugin_id, reason)
        {:error, {:crashed, reason}}

      nil ->
        log_plugin_timeout(plugin_id, timeout)
        {:error, {:timeout, timeout}}
    end
  end

  @doc """
  Runs a plugin task asynchronously (fire and forget).

  The task runs under the Task.Supervisor, so crashes are isolated.
  Crashes are logged but don't return errors to the caller.

  ## Examples

      PluginSupervisor.async_plugin_task(:my_plugin, fn ->
        MyPlugin.handle_event(event)
      end)

  """
  @spec async_plugin_task(atom(), (-> term())) :: :ok
  def async_plugin_task(plugin_id, func) do
    Task.Supervisor.start_child(@task_supervisor_name, fn ->
      try do
        func.()
      rescue
        error ->
          log_plugin_crash(plugin_id, error)
          {:error, {:crashed, error}}
      catch
        kind, value ->
          log_plugin_crash(plugin_id, {kind, value})
          {:error, {:crashed, {kind, value}}}
      end
    end)

    :ok
  end

  @doc """
  Runs multiple plugin tasks concurrently with isolation.

  Returns results in the same order as input functions.
  Failed tasks return `{:error, reason}` in their position.

  ## Options

    * `:timeout` - Maximum time for all tasks (default: 5000)

  ## Examples

      results = PluginSupervisor.run_plugin_tasks_concurrent(:my_plugin, [
        fn -> fetch_data() end,
        fn -> process_config() end
      ])
      # => [{:ok, data}, {:ok, config}]

  """
  @spec run_plugin_tasks_concurrent(atom(), [(-> term())], keyword()) ::
          [{:ok, term()} | {:error, term()}]
  def run_plugin_tasks_concurrent(plugin_id, funcs, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    tasks =
      Enum.map(funcs, fn func ->
        Task.Supervisor.async_nolink(@task_supervisor_name, fn ->
          func.()
        end)
      end)

    Task.yield_many(tasks, timeout)
    |> Enum.map(fn
      {_task, {:ok, result}} ->
        {:ok, result}

      {task, {:exit, reason}} ->
        log_plugin_crash(plugin_id, reason)
        Task.shutdown(task, :brutal_kill)
        {:error, {:crashed, reason}}

      {task, nil} ->
        log_plugin_timeout(plugin_id, timeout)
        Task.shutdown(task, :brutal_kill)
        {:error, {:timeout, timeout}}
    end)
  end

  @doc """
  Safely invokes a plugin callback with isolation.

  Handles the common pattern of calling a module function if it exists.

  ## Examples

      # Calls MyPlugin.on_load() if exported, returns {:ok, result} or {:error, reason}
      PluginSupervisor.call_plugin_callback(:my_plugin, MyPlugin, :on_load, [])

      # Calls MyPlugin.handle_event(event) with timeout
      PluginSupervisor.call_plugin_callback(:my_plugin, MyPlugin, :handle_event, [event], timeout: 1000)

  """
  @spec call_plugin_callback(atom(), module(), atom(), list(), keyword()) ::
          {:ok, term()} | {:error, term()} | :not_exported
  def call_plugin_callback(plugin_id, module, function, args, opts \\ []) do
    arity = length(args)

    case function_exported?(module, function, arity) do
      true ->
        run_plugin_task(
          plugin_id,
          fn ->
            apply(module, function, args)
          end,
          opts
        )

      false ->
        :not_exported
    end
  end

  @doc """
  Gets statistics about plugin task execution.
  """
  @spec stats() :: map()
  def stats do
    %{
      active_tasks: Task.Supervisor.children(@task_supervisor_name) |> length(),
      supervisor_info: Process.info(Process.whereis(@task_supervisor_name))
    }
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp log_plugin_crash(plugin_id, reason) do
    Log.error(
      "[PluginSupervisor] Plugin #{inspect(plugin_id)} crashed: #{inspect(reason)}"
    )
  end

  defp log_plugin_timeout(plugin_id, timeout) do
    Log.warning(
      "[PluginSupervisor] Plugin #{inspect(plugin_id)} timed out after #{timeout}ms"
    )
  end
end
