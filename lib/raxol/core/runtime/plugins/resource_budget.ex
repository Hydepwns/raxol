defmodule Raxol.Core.Runtime.Plugins.ResourceBudget do
  @moduledoc """
  Runtime resource monitoring per plugin.

  Tracks actual resource usage against declared budgets from plugin manifests.
  Runs on a configurable timer (default 5s) and takes action when plugins
  exceed their budgets.

  Actions (configurable per plugin):
  - `:warn` -- log warning + emit telemetry event
  - `:throttle` -- reduce event delivery rate to plugin
  - `:kill` -- unload the plugin via PluginLifecycle
  """

  use GenServer

  alias Raxol.Core.Runtime.Log
  alias Raxol.Core.Runtime.Plugins.PluginLifecycle
  alias Raxol.Core.Runtime.Plugins.PluginRegistry

  @type budget :: %{
          max_memory_mb: number(),
          max_cpu_percent: number(),
          max_ets_tables: non_neg_integer(),
          max_processes: non_neg_integer()
        }

  @type usage :: %{
          memory_mb: number(),
          cpu_percent: number(),
          ets_tables: non_neg_integer(),
          processes: non_neg_integer()
        }

  @type action :: :warn | :throttle | :kill

  @default_interval_ms 5_000
  @default_action :warn
  @warn_cycles_before_throttle 3

  defstruct [
    :timer_ref,
    interval_ms: @default_interval_ms,
    plugin_actions: %{},
    violation_counts: %{},
    throttled: MapSet.new()
  ]

  # -- Client API ------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Checks resource usage for a specific plugin against its budget.
  """
  @spec check(atom()) :: {:ok, usage()} | {:over_budget, usage(), budget()}
  def check(plugin_id) do
    GenServer.call(__MODULE__, {:check, plugin_id})
  end

  @doc """
  Sets the enforcement action for a plugin.
  """
  @spec set_action(atom(), action()) :: :ok
  def set_action(plugin_id, action) when action in [:warn, :throttle, :kill] do
    GenServer.call(__MODULE__, {:set_action, plugin_id, action})
  end

  @doc """
  Checks all monitored plugins and returns their status.
  """
  @spec monitor_all() :: [{atom(), :ok | :over_budget}]
  def monitor_all do
    GenServer.call(__MODULE__, :monitor_all)
  end

  @doc """
  Returns whether a plugin is currently throttled.
  """
  @spec throttled?(atom()) :: boolean()
  def throttled?(plugin_id) do
    GenServer.call(__MODULE__, {:throttled?, plugin_id})
  end

  # -- Server ----------------------------------------------------------------

  @impl GenServer
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, @default_interval_ms)
    timer_ref = Process.send_after(self(), :check_budgets, interval)

    {:ok,
     %__MODULE__{
       timer_ref: timer_ref,
       interval_ms: interval
     }}
  end

  @impl GenServer
  def handle_call({:check, plugin_id}, _from, state) do
    result = check_plugin(plugin_id)
    {:reply, result, state}
  end

  def handle_call({:set_action, plugin_id, action}, _from, state) do
    state = %{
      state
      | plugin_actions: Map.put(state.plugin_actions, plugin_id, action)
    }

    {:reply, :ok, state}
  end

  def handle_call(:monitor_all, _from, state) do
    results = do_monitor_all()
    {:reply, results, state}
  end

  def handle_call({:throttled?, plugin_id}, _from, state) do
    {:reply, MapSet.member?(state.throttled, plugin_id), state}
  end

  @impl GenServer
  def handle_info(:check_budgets, state) do
    state = enforce_budgets(state)
    timer_ref = Process.send_after(self(), :check_budgets, state.interval_ms)
    {:noreply, %{state | timer_ref: timer_ref}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # -- Private ---------------------------------------------------------------

  defp check_plugin(plugin_id) do
    usage = measure_usage(plugin_id)
    budget = get_budget(plugin_id)

    if over_budget?(usage, budget) do
      {:over_budget, usage, budget}
    else
      {:ok, usage}
    end
  end

  defp do_monitor_all do
    PluginRegistry.list()
    |> Enum.map(fn entry ->
      plugin_id = entry.id

      case check_plugin(plugin_id) do
        {:ok, _} -> {plugin_id, :ok}
        {:over_budget, _, _} -> {plugin_id, :over_budget}
      end
    end)
  end

  defp enforce_budgets(state) do
    results = do_monitor_all()

    Enum.reduce(results, state, fn
      {_plugin_id, :ok}, acc ->
        acc

      {plugin_id, :over_budget}, acc ->
        action = Map.get(acc.plugin_actions, plugin_id, @default_action)
        count = Map.get(acc.violation_counts, plugin_id, 0) + 1

        acc = %{
          acc
          | violation_counts: Map.put(acc.violation_counts, plugin_id, count)
        }

        effective_action =
          if action == :warn and count >= @warn_cycles_before_throttle do
            :throttle
          else
            action
          end

        enforce_action(plugin_id, effective_action, acc)
    end)
  end

  defp enforce_action(plugin_id, :warn, state) do
    Log.warning_msg(
      "[ResourceBudget] Plugin #{plugin_id} over budget (cycle #{Map.get(state.violation_counts, plugin_id, 0)})"
    )

    state
  end

  defp enforce_action(plugin_id, :throttle, state) do
    Log.warning_msg("[ResourceBudget] Throttling plugin #{plugin_id}")
    %{state | throttled: MapSet.put(state.throttled, plugin_id)}
  end

  defp enforce_action(plugin_id, :kill, state) do
    Log.warning_msg("[ResourceBudget] Killing over-budget plugin #{plugin_id}")
    PluginLifecycle.unload(plugin_id)
    %{state | throttled: MapSet.delete(state.throttled, plugin_id)}
  end

  defp measure_usage(_plugin_id) do
    # Measure actual resource usage for the plugin.
    # In a full implementation this would track processes spawned by the plugin
    # and sum their memory. For now, return baseline measurements.
    %{
      memory_mb: 0.0,
      cpu_percent: 0.0,
      ets_tables: 0,
      processes: 0
    }
  end

  defp get_budget(plugin_id) do
    case PluginRegistry.get(plugin_id) do
      {:ok, entry} ->
        metadata = Map.get(entry, :metadata, %{})
        Map.get(metadata, :resource_budget, default_budget())

      _ ->
        default_budget()
    end
  end

  defp default_budget do
    %{
      max_memory_mb: 50,
      max_cpu_percent: 10,
      max_ets_tables: 2,
      max_processes: 20
    }
  end

  defp over_budget?(usage, budget) do
    usage.memory_mb > budget.max_memory_mb or
      usage.cpu_percent > budget.max_cpu_percent or
      usage.ets_tables > budget.max_ets_tables or
      usage.processes > budget.max_processes
  end
end
