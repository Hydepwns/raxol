defmodule Raxol.Terminal.ScreenBuffer.Metrics do
  @moduledoc """
  Handles metrics collection and management for the terminal screen buffer.
  This module provides functions for recording and retrieving various metrics
  related to screen buffer performance, operations, and resource usage.
  """

  @type metric_type :: :performance | :operation | :resource
  @type metric_value :: number() | String.t() | boolean()
  @type metric_tags :: map()

  @type t :: %__MODULE__{
          metrics: %{String.t() => {metric_value(), metric_tags()}},
          performance_metrics: %{String.t() => number()},
          operation_metrics: %{String.t() => number()},
          resource_metrics: %{String.t() => number()}
        }

  defstruct metrics: %{},
            performance_metrics: %{},
            operation_metrics: %{},
            resource_metrics: %{}

  @doc """
  Gets the value of a specific metric.
  Returns the metric value and its associated tags.
  """
  @spec get_value(t(), String.t()) :: {metric_value(), metric_tags()} | nil
  def get_value(%__MODULE__{} = state, metric) do
    Map.get(state.metrics, metric)
  end

  @doc """
  Verifies if the given metrics exist in the state.
  Returns true if all metrics exist, false otherwise.
  """
  @spec verify(t(), list(String.t())) :: boolean()
  def verify(%__MODULE__{} = state, metrics) do
    Enum.all?(metrics, &Map.has_key?(state.metrics, &1))
  end

  @doc """
  Collects metrics of a specific type.
  Returns a map of metric names to their values.
  """
  @spec collect(t(), metric_type()) :: %{String.t() => metric_value()}
  def collect(%__MODULE__{} = state, :performance),
    do: state.performance_metrics

  def collect(%__MODULE__{} = state, :operation), do: state.operation_metrics
  def collect(%__MODULE__{} = state, :resource), do: state.resource_metrics

  @doc """
  Records a performance metric.
  Returns a new metrics state with the performance metric updated.
  """
  @spec record_performance(t(), String.t(), number()) :: t()
  def record_performance(%__MODULE__{} = state, metric, value) do
    %{
      state
      | performance_metrics: Map.put(state.performance_metrics, metric, value),
        metrics: Map.put(state.metrics, metric, {value, %{type: :performance}})
    }
  end

  @doc """
  Records an operation metric.
  Returns a new metrics state with the operation metric updated.
  """
  @spec record_operation(t(), String.t(), number()) :: t()
  def record_operation(%__MODULE__{} = state, operation, value) do
    %{
      state
      | operation_metrics: Map.put(state.operation_metrics, operation, value),
        metrics: Map.put(state.metrics, operation, {value, %{type: :operation}})
    }
  end

  @doc """
  Records a resource metric.
  Returns a new metrics state with the resource metric updated.
  """
  @spec record_resource(t(), String.t(), number()) :: t()
  def record_resource(%__MODULE__{} = state, resource, value) do
    %{
      state
      | resource_metrics: Map.put(state.resource_metrics, resource, value),
        metrics: Map.put(state.metrics, resource, {value, %{type: :resource}})
    }
  end

  @doc """
  Gets metrics by type.
  Returns a map of metric names to their values for the specified type.
  """
  @spec get_by_type(t(), metric_type()) :: %{String.t() => metric_value()}
  def get_by_type(%__MODULE__{} = state, type) do
    state.metrics
    |> Enum.filter(fn {_, {_, tags}} -> tags.type == type end)
    |> Map.new(fn {key, {value, _}} -> {key, value} end)
  end

  @doc """
  Records a metric with optional tags.
  Returns a new metrics state with the metric recorded.
  """
  @spec record(t(), String.t(), metric_value(), metric_tags()) :: t()
  def record(%__MODULE__{} = state, metric, value, tags) do
    %{state | metrics: Map.put(state.metrics, metric, {value, tags})}
  end

  @doc """
  Gets a metric value with optional tags.
  Returns the metric value if found, nil otherwise.
  """
  @spec get(t(), String.t(), metric_tags()) :: metric_value() | nil
  def get(%__MODULE__{} = state, metric, tags) do
    case Map.get(state.metrics, metric) do
      {value, metric_tags} when metric_tags == tags -> value
      _ -> nil
    end
  end
end
