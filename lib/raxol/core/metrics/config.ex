defmodule Raxol.Core.Metrics.Config do
  import Raxol.Guards

  @moduledoc """
  Configuration management for the Raxol metrics system.

  This module handles:
  - Environment-based configuration
  - Runtime configuration updates
  - Configuration validation
  - Default settings
  """

  use GenServer

  @type metric_type :: :performance | :resource | :operation | :system | :custom
  @type config_key ::
          :retention_period | :max_samples | :flush_interval | :enabled_metrics

  @default_config %{
    # 1 hour in seconds
    retention_period: 3600,
    # Maximum samples per metric
    max_samples: 1000,
    # 1 second in milliseconds
    flush_interval: 1000,
    enabled_metrics: [:performance, :resource, :operation, :system],
    environment: :prod
  }

  @doc """
  Starts the configuration server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the current configuration value for the given key.
  """
  def get(key, default \\ nil)
      when key in [
             :retention_period,
             :max_samples,
             :flush_interval,
             :enabled_metrics
           ] do
    GenServer.call(__MODULE__, {:get, key, default})
  end

  @doc """
  Gets all current configuration values.
  """
  def get_all do
    GenServer.call(__MODULE__, :get_all)
  end

  @doc """
  Updates the configuration with the given key-value pairs.
  """
  def update(config_updates) when map?(config_updates) do
    GenServer.call(__MODULE__, {:update, config_updates})
  end

  @doc """
  Sets a specific configuration value.
  """
  def set(key, value)
      when key in [
             :retention_period,
             :max_samples,
             :flush_interval,
             :enabled_metrics
           ] do
    GenServer.call(__MODULE__, {:set, key, value})
  end

  @doc """
  Resets the configuration to default values.
  """
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @doc """
  Gets the current environment.
  """
  def environment do
    GenServer.call(__MODULE__, :environment)
  end

  @doc """
  Sets the current environment.
  """
  def set_environment(env) when env in [:dev, :test, :prod] do
    GenServer.call(__MODULE__, {:set_environment, env})
  end

  @impl GenServer
  def init(opts) do
    config = Map.merge(@default_config, Map.new(opts))
    {:ok, config}
  end

  @impl GenServer
  def handle_call({:get, key, default}, _from, state) do
    value = Map.get(state, key, default)
    {:reply, value, state}
  end

  @impl GenServer
  def handle_call(:get_all, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl GenServer
  def handle_call({:update, config_updates}, _from, state) do
    new_state = Map.merge(state, config_updates)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set, key, value}, _from, state) do
    new_state = Map.put(state, key, value)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:reset, _from, _state) do
    {:reply, :ok, @default_config}
  end

  @impl GenServer
  def handle_call(:environment, _from, state) do
    {:reply, state.environment, state}
  end

  @impl GenServer
  def handle_call({:set_environment, env}, _from, state) do
    new_state = Map.put(state, :environment, env)
    {:reply, :ok, new_state}
  end

  @doc """
  Returns the default configuration.
  """
  def default_config do
    @default_config
  end

  @doc """
  Validates the given configuration.
  Returns :ok if valid, {:error, reason} if invalid.
  """
  def validate_config(config) do
    with :ok <- validate_retention_period(config.retention_period),
         :ok <- validate_max_samples(config.max_samples),
         :ok <- validate_flush_interval(config.flush_interval),
         :ok <- validate_enabled_metrics(config.enabled_metrics) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_retention_period(period) when integer?(period) and period > 0,
    do: :ok

  defp validate_retention_period(_), do: {:error, :invalid_retention_period}

  defp validate_max_samples(samples) when integer?(samples) and samples > 0,
    do: :ok

  defp validate_max_samples(_), do: {:error, :invalid_max_samples}

  defp validate_flush_interval(interval)
       when integer?(interval) and interval > 0,
       do: :ok

  defp validate_flush_interval(_), do: {:error, :invalid_flush_interval}

  defp validate_enabled_metrics(metrics) when list?(metrics) do
    if Enum.all?(
         metrics,
         &(&1 in [:performance, :resource, :operation, :system, :custom])
       ) do
      :ok
    else
      {:error, :invalid_enabled_metrics}
    end
  end

  defp validate_enabled_metrics(_), do: {:error, :invalid_enabled_metrics}
end
