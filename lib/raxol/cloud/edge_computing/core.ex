defmodule Raxol.Cloud.EdgeComputing.Core do
  @moduledoc """
  Core edge computing functionality and state management.
  """

  alias Raxol.Cloud.EdgeComputing.{Cache, Queue, SyncManager}

  # Edge computing state
  defmodule State do
    @moduledoc false
    defstruct [
      :mode,
      :config,
      :edge_status,
      :cloud_status,
      :sync_status,
      :resources,
      :metrics
    ]

    def new do
      %__MODULE__{
        mode: :hybrid,
        config: %{
          connection_check_interval: 5000,
          sync_interval: 30_000,
          retry_limit: 5,
          compression_enabled: true,
          # 100MB
          offline_cache_size: 100_000_000,
          priority_functions: []
        },
        edge_status: :initialized,
        cloud_status: :unknown,
        sync_status: :idle,
        resources: %{
          cpu_available: 0,
          memory_available: 0,
          storage_available: 0,
          bandwidth_available: 0
        },
        metrics: %{
          edge_requests: 0,
          cloud_requests: 0,
          sync_operations: 0,
          sync_failures: 0,
          last_successful_sync: nil
        }
      }
    end
  end

  # Process dictionary key for edge computing state
  @edge_key :raxol_edge_computing_state

  @doc """
  Initializes the edge computing system.
  """
  def init(opts \\ []) do
    opts = if is_map(opts), do: Enum.into(opts, []), else: opts
    state = State.new()

    # Override defaults with provided options
    config =
      Keyword.take(opts, [
        :mode,
        :connection_check_interval,
        :sync_interval,
        :retry_limit,
        :compression_enabled,
        :offline_cache_size,
        :priority_functions
      ])

    # Update state with provided config
    state = update_config(state, config)

    # Initialize resources information
    state = %{state | resources: get_resource_info()}

    # Store state
    Raxol.Cloud.EdgeComputing.Server.set_state(state)

    # Initialize cache, queue and sync manager
    Cache.init(state.config)
    Queue.init(state.config)
    SyncManager.init(state.config)

    # Start connection monitoring
    schedule_connection_check(state.config.connection_check_interval)

    :ok
  end

  @doc """
  Updates the edge computing configuration.
  """
  def update_config(state \\ nil, config) do
    config = if is_map(config), do: Enum.into(config, []), else: config

    with_state(state, fn s ->
      # Merge new config with existing config
      updated_config =
        s.config
        |> Map.merge(Map.new(config))

      # Update mode if specified
      updated_state =
        case Keyword.get(config, :mode) do
          nil ->
            s

          mode when mode in [:edge_only, :cloud_only, :hybrid] ->
            %{s | mode: mode}

          _ ->
            s
        end

      %{updated_state | config: updated_config}
    end)
  end

  @doc """
  Gets the current status of the edge computing system.
  """
  def status do
    state = get_state()

    %{
      mode: state.mode,
      edge_status: state.edge_status,
      cloud_status: state.cloud_status,
      sync_status: state.sync_status,
      metrics: state.metrics,
      resources: state.resources,
      queued_operations: Queue.pending_count(),
      cache_usage: Cache.usage()
    }
  end

  @doc """
  Forces the system into a specific mode.
  """
  def force_mode(mode) when mode in [:edge_only, :cloud_only, :hybrid] do
    with_state(fn state ->
      %{state | mode: mode}
    end)

    :ok
  end

  @doc """
  Gets metrics for the edge computing system.
  """
  def get_metrics do
    state = get_state()
    state.metrics
  end

  @doc """
  Clears the edge cache.
  """
  def clear_cache do
    Cache.clear()
    :ok
  end

  @doc """
  Checks if the system is currently operating in offline mode.
  """
  def offline? do
    state = get_state()
    state.cloud_status != :connected
  end

  def get_state do
    Raxol.Cloud.EdgeComputing.Server.get_state() || State.new()
  end

  def with_state(arg1, arg2 \\ nil) do
    {state, fun} =
      if is_function(arg1) do
        {get_state(), arg1}
      else
        {arg1 || get_state(), arg2}
      end

    result = fun.(state)

    if is_map(result) and Map.has_key?(result, :mode) do
      # If a state map is returned, update the state
      Raxol.Cloud.EdgeComputing.Server.set_state(result)
      result
    else
      # Otherwise just return the result
      result
    end
  end

  defp get_resource_info do
    # In a real implementation, this would check actual system resources
    %{
      # percentage
      cpu_available: 80,
      # bytes
      memory_available: 500_000_000,
      # bytes
      storage_available: 1_000_000_000,
      # bytes/s
      bandwidth_available: 1_000_000
    }
  end

  defp schedule_connection_check(interval) do
    # This would set up a timer in a real implementation
    # For demo purposes, we'll just use a simple spawn
    spawn(fn ->
      Process.sleep(interval)
      Raxol.Cloud.EdgeComputing.Connection.check_connection()
    end)
  end
end
