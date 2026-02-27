defmodule Raxol.Terminal.ScreenBuffer.Metrics do
  @moduledoc """
  Deprecated: This module is not used in the codebase.

  Originally intended for screen buffer metrics but never integrated.
  Use `Raxol.Core.Metrics.MetricsCollector` for metrics instead.
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

  @spec get_value(t(), String.t()) :: {metric_value(), metric_tags()} | nil
  def get_value(%__MODULE__{} = state, metric) do
    Map.get(state.metrics, metric)
  end

  @spec verify(t(), list(String.t())) :: boolean()
  def verify(%__MODULE__{} = state, metrics) do
    Enum.all?(metrics, &Map.has_key?(state.metrics, &1))
  end

  @spec collect(t(), metric_type()) :: %{String.t() => metric_value()}
  def collect(%__MODULE__{} = state, :performance),
    do: state.performance_metrics

  def collect(%__MODULE__{} = state, :operation), do: state.operation_metrics
  def collect(%__MODULE__{} = state, :resource), do: state.resource_metrics

  @spec record_performance(t(), String.t(), number()) :: t()
  def record_performance(%__MODULE__{} = state, metric, value) do
    %{
      state
      | performance_metrics: Map.put(state.performance_metrics, metric, value),
        metrics: Map.put(state.metrics, metric, {value, %{type: :performance}})
    }
  end

  @spec record_operation(t(), String.t(), number()) :: t()
  def record_operation(%__MODULE__{} = state, operation, value) do
    %{
      state
      | operation_metrics: Map.put(state.operation_metrics, operation, value),
        metrics: Map.put(state.metrics, operation, {value, %{type: :operation}})
    }
  end

  @spec record_resource(t(), String.t(), number()) :: t()
  def record_resource(%__MODULE__{} = state, resource, value) do
    %{
      state
      | resource_metrics: Map.put(state.resource_metrics, resource, value),
        metrics: Map.put(state.metrics, resource, {value, %{type: :resource}})
    }
  end

  @spec get_by_type(t(), metric_type()) :: %{String.t() => metric_value()}
  def get_by_type(%__MODULE__{} = state, type) do
    state.metrics
    |> Enum.filter(fn {_, {_, tags}} -> tags.type == type end)
    |> Map.new(fn {key, {value, _}} -> {key, value} end)
  end

  @spec record(t(), String.t(), metric_value(), metric_tags()) :: t()
  def record(%__MODULE__{} = state, metric, value, tags) do
    %{state | metrics: Map.put(state.metrics, metric, {value, tags})}
  end

  @spec get(t(), String.t(), metric_tags()) :: metric_value() | nil
  def get(%__MODULE__{} = state, metric, tags) do
    case Map.get(state.metrics, metric) do
      {value, metric_tags} when metric_tags == tags -> value
      _ -> nil
    end
  end

  def init do
    %__MODULE__{}
  end
end
