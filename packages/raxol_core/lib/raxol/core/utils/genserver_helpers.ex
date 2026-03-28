defmodule Raxol.Core.Utils.GenServerHelpers do
  @moduledoc """
  Common GenServer patterns and utilities to reduce code duplication.
  Provides standardized handlers for common operations like state retrieval,
  metrics collection, and configuration management.
  """

  @doc """
  Standard handler for getting state information.
  """
  def handle_get_state(state) do
    {:reply, state, state}
  end

  @doc """
  Standard handler for getting specific state fields.
  """
  def handle_get_field(field, state) when is_map(state) do
    {:reply, Map.get(state, field), state}
  end

  def handle_get_field(_field, state) do
    {:reply, nil, state}
  end

  @doc """
  Standard handler for getting metrics from state.
  """
  def handle_get_metrics(state) when is_map(state) do
    metrics = Map.get(state, :metrics, %{})
    {:reply, metrics, state}
  end

  def handle_get_metrics(state) do
    {:reply, %{}, state}
  end

  @doc """
  Standard handler for getting status information.
  """
  def handle_get_status(state) when is_map(state) do
    status = %{
      status: Map.get(state, :status, :running),
      uptime: calculate_uptime(state),
      metrics: Map.get(state, :metrics, %{})
    }

    {:reply, status, state}
  end

  def handle_get_status(state) do
    {:reply, %{status: :unknown}, state}
  end

  @doc """
  Standard handler for updating configuration.
  """
  def handle_update_config(new_config, state)
      when is_map(state) and is_map(new_config) do
    updated_config = Map.merge(Map.get(state, :config, %{}), new_config)
    new_state = Map.put(state, :config, updated_config)
    {:reply, :ok, new_state}
  end

  def handle_update_config(_new_config, state) do
    {:reply, {:error, :invalid_config}, state}
  end

  @doc """
  Standard handler for resetting metrics.
  """
  def handle_reset_metrics(state) when is_map(state) do
    new_state = Map.put(state, :metrics, %{})
    {:reply, :ok, new_state}
  end

  def handle_reset_metrics(state) do
    {:reply, :ok, state}
  end

  @doc """
  Utility to increment a metric counter.
  """
  def increment_metric(state, metric_name, amount \\ 1)

  def increment_metric(state, metric_name, amount) when is_map(state) do
    metrics = Map.get(state, :metrics, %{})
    updated_metrics = Map.update(metrics, metric_name, amount, &(&1 + amount))
    Map.put(state, :metrics, updated_metrics)
  end

  def increment_metric(state, _metric_name, _amount) do
    state
  end

  @doc """
  Utility to update a metric value.
  """
  def update_metric(state, metric_name, value) when is_map(state) do
    metrics = Map.get(state, :metrics, %{})
    updated_metrics = Map.put(metrics, metric_name, value)
    Map.put(state, :metrics, updated_metrics)
  end

  def update_metric(state, _metric_name, _value) do
    state
  end

  defp calculate_uptime(state) when is_map(state) do
    start_time =
      Map.get(state, :start_time, System.monotonic_time(:millisecond))

    System.monotonic_time(:millisecond) - start_time
  end

  @doc """
  Initialize default state with common fields.
  """
  def init_default_state(custom_state \\ %{}) do
    default_state = %{
      status: :running,
      start_time: System.monotonic_time(:millisecond),
      metrics: %{},
      config: %{}
    }

    Map.merge(default_state, custom_state)
  end
end
