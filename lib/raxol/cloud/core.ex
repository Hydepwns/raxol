defmodule Raxol.Cloud.Core do
  @moduledoc """
  Core functionality for Raxol cloud integrations.

  This module combines edge computing and monitoring capabilities,
  providing a unified interface for cloud operations.
  """

  alias Raxol.Cloud.EdgeComputing
  alias Raxol.Cloud.Integrations
  alias Raxol.Cloud.Monitoring
  alias Raxol.Cloud.StateManager

  # Central state manager process name
  @state_name :raxol_cloud_state

  @doc """
  Initializes the cloud core components.

  ## Options

  * `:edge` - Edge computing options
  * `:monitoring` - Monitoring options
  * `:providers` - List of cloud providers to enable
  """
  def init(opts \\ []) do
    opts = case opts do
      opts when is_map(opts) -> Enum.into(opts, [])
      opts -> opts
    end
    # Extract options
    edge_opts = Keyword.get(opts, :edge, [])
    monitoring_opts = Keyword.get(opts, :monitoring, [])
    providers = Keyword.get(opts, :providers, [])

    # Initialize state manager if not already started
    start_state_manager()

    # Initialize components
    EdgeComputing.init(edge_opts)
    Monitoring.init(monitoring_opts)

    # Initialize integrations
    Integrations.init(
      edge: edge_opts,
      monitoring: monitoring_opts,
      providers: providers
    )

    {:ok, %{status: :initialized}}
  end

  @doc """
  Starts all cloud services.
  """
  def start do
    # Start monitoring
    Monitoring.start()

    # Start edge computing
    EdgeComputing.init([])

    # Record start event
    record_metric("cloud.start", 1, tags: ["service:all"])

    :ok
  end

  @doc """
  Stops all cloud services.
  """
  def stop do
    # Record stop event before stopping monitoring
    record_metric("cloud.stop", 1, tags: ["service:all"])

    # Stop edge computing
    # NOTE: EdgeComputing.cleanup/0 is undefined. Implement or call if cleanup is needed in the future.
    # EdgeComputing.cleanup()

    # Stop monitoring (last, so we can record the stop event)
    Monitoring.stop()

    :ok
  end

  @doc """
  Returns the current status of all cloud services.
  """
  def status do
    %{
      edge: EdgeComputing.status(),
      monitoring: Monitoring.status(),
      providers: get_providers_status()
    }
  end

  @doc """
  Executes a function in the optimal location (edge or cloud).

  ## Options

  * `:priority` - Priority for execution (:speed, :reliability, :cost)
  * `:location` - Preferred location (:auto, :edge, :cloud)
  * `:timeout` - Timeout in milliseconds
  """
  def execute(fun, opts \\ []) do
    opts = case opts do
      opts when is_map(opts) -> Enum.into(opts, [])
      opts -> opts
    end
    # Log execution
    operation_id = "op-#{:erlang.system_time(:microsecond)}"

    # Record execution start
    record_metric("cloud.execute.start", 1,
      tags: [
        "operation_id:#{operation_id}",
        "priority:#{Keyword.get(opts, :priority, :auto)}",
        "location:#{Keyword.get(opts, :location, :auto)}"
      ]
    )

    # Execute function
    {time, result} = :timer.tc(fn -> Integrations.execute(fun, opts) end)
    execution_time_ms = time / 1000

    # Record execution metrics
    status_tag =
      case result do
        {:ok, _} -> "status:success"
        {:error, _} -> "status:error"
      end

    record_metric("cloud.execute.end", 1,
      tags: [
        "operation_id:#{operation_id}",
        status_tag
      ]
    )

    record_metric("cloud.execute.time", execution_time_ms,
      tags: [
        "operation_id:#{operation_id}",
        status_tag
      ]
    )

    result
  end

  # ===== Monitoring functions =====

  @doc """
  Records a metric with the given name and value.
  """
  def record_metric(name, value, opts \\ []) do
    opts = case opts do
      opts when is_map(opts) -> Enum.into(opts, [])
      opts -> opts
    end
    Monitoring.record_metric(name, value, opts)
  end

  @doc """
  Records an error or exception.
  """
  def record_error(error, opts \\ []) do
    opts = case opts do
      opts when is_map(opts) -> Enum.into(opts, [])
      opts -> opts
    end
    Monitoring.record_error(error, opts)
  end

  @doc """
  Runs a health check on the system.
  """
  def run_health_check(opts \\ []) do
    opts = case opts do
      opts when is_map(opts) -> Enum.into(opts, [])
      opts -> opts
    end
    Monitoring.run_health_check(opts)
  end

  @doc """
  Triggers an alert with the given type and data.
  """
  def trigger_alert(type, data, opts \\ []) do
    opts = case opts do
      opts when is_map(opts) -> Enum.into(opts, [])
      opts -> opts
    end
    Monitoring.trigger_alert(type, data, opts)
  end

  # ===== Service management functions =====

  @doc """
  Discovers services available in the current environment.
  """
  def discover_services(opts \\ []) do
    opts = case opts do
      opts when is_map(opts) -> Enum.into(opts, [])
      opts -> opts
    end
    Integrations.discover_services(opts)
  end

  @doc """
  Registers the current application as a service.
  """
  def register_service(opts) do
    opts = case opts do
      opts when is_map(opts) -> Enum.into(opts, [])
      opts -> opts
    end
    Integrations.register_service(opts)
  end

  @doc """
  Deploys an application component.
  """
  def deploy(opts) do
    opts = case opts do
      opts when is_map(opts) -> Enum.into(opts, [])
      opts -> opts
    end
    Integrations.deploy(opts)
  end

  @doc """
  Scales a service based on current metrics and conditions.
  """
  def scale(opts) do
    opts = case opts do
      opts when is_map(opts) -> Enum.into(opts, [])
      opts -> opts
    end
    Integrations.scale(opts)
  end

  @doc """
  Gets a connection to a cloud service.
  """
  def get_service_connection(opts) do
    Integrations.get_service_connection(opts)
  end

  # ===== Private functions =====

  defp get_providers_status do
    case Integrations.status() do
      %{providers: providers} -> providers
      _ -> %{}
    end
  end

  defp start_state_manager do
    # Start the state manager if not already started
    case Process.whereis(@state_name) do
      nil ->
        # Not started, so start it
        {:ok, _pid} = StateManager.start_link(name: @state_name)
        :ok

      _pid ->
        # Already started
        :ok
    end
  end
end
