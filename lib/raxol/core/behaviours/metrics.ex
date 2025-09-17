defmodule Raxol.Core.Behaviours.Metrics do
  @moduledoc """
  Common behavior for metrics collection and reporting.

  This behavior defines a consistent interface for components that
  collect, track, and report metrics about their operation.
  """

  @type metric_name :: atom() | String.t()
  @type metric_value :: number()
  @type metric_tags :: keyword()
  @type metrics :: map()

  @doc """
  Increments a counter metric.
  """
  @callback increment(metric_name, metric_value, metric_tags) :: :ok

  @doc """
  Decrements a counter metric.
  """
  @callback decrement(metric_name, metric_value, metric_tags) :: :ok

  @doc """
  Records a gauge metric value.
  """
  @callback gauge(metric_name, metric_value, metric_tags) :: :ok

  @doc """
  Records a histogram/timing metric.
  """
  @callback histogram(metric_name, metric_value, metric_tags) :: :ok

  @doc """
  Gets all current metric values.
  """
  @callback get_metrics() :: metrics

  @doc """
  Gets a specific metric value.
  """
  @callback get_metric(metric_name) :: metric_value | nil

  @doc """
  Resets all metrics to initial values.
  """
  @callback reset_metrics() :: :ok

  @doc """
  Resets a specific metric to its initial value.
  """
  @callback reset_metric(metric_name) :: :ok

  @optional_callbacks [reset_metrics: 0, reset_metric: 1]

  @doc """
  Convenience functions with default implementations.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.Core.Behaviours.Metrics

      @impl true
      def reset_metrics do
        # Default implementation - override if needed
        :ok
      end

      @impl true
      def reset_metric(_metric_name) do
        # Default implementation - override if needed
        :ok
      end

      defoverridable reset_metrics: 0, reset_metric: 1

      # Convenience functions
      def increment(metric_name), do: increment(metric_name, 1, [])
      def increment(metric_name, value), do: increment(metric_name, value, [])

      def decrement(metric_name), do: decrement(metric_name, 1, [])
      def decrement(metric_name, value), do: decrement(metric_name, value, [])

      def gauge(metric_name, value), do: gauge(metric_name, value, [])
      def histogram(metric_name, value), do: histogram(metric_name, value, [])
    end
  end
end
