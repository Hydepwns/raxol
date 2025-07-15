defmodule Raxol.Terminal.Buffer.MetricsTracker do
  @moduledoc """
  Tracks performance metrics and memory usage for buffer operations.

  This module is responsible for:
  - Tracking operation counts (reads, writes, scrolls, resizes)
  - Monitoring response times
  - Calculating memory usage
  - Providing performance insights
  """

  @type metrics :: %{
          operations: %{
            reads: non_neg_integer(),
            writes: non_neg_integer(),
            scrolls: non_neg_integer(),
            resizes: non_neg_integer()
          },
          performance: %{
            total_operations: non_neg_integer(),
            average_response_time: float()
          }
        }

  @doc """
  Creates a new metrics tracker with initial state.
  """
  @spec new() :: metrics()
  def new do
    %{
      operations: %{
        reads: 0,
        writes: 0,
        scrolls: 0,
        resizes: 0
      },
      performance: %{
        total_operations: 0,
        average_response_time: 0.0
      }
    }
  end

  @doc """
  Updates metrics for a specific operation type.
  """
  @spec update_metrics(metrics(), atom(), integer()) :: metrics()
  def update_metrics(metrics, operation, start_time) do
    end_time = System.monotonic_time()

    response_time =
      System.convert_time_unit(end_time - start_time, :native, :microsecond)

    # Update operation counts
    new_operations = Map.update(metrics.operations, operation, 1, &(&1 + 1))

    # Update performance metrics
    total_ops = metrics.performance.total_operations + 1
    current_avg = metrics.performance.average_response_time
    new_avg = (current_avg * (total_ops - 1) + response_time) / total_ops

    new_performance = %{
      metrics.performance
      | total_operations: total_ops,
        average_response_time: new_avg
    }

    %{metrics | operations: new_operations, performance: new_performance}
  end

  @doc """
  Calculates memory usage for a buffer.
  """
  @spec calculate_memory_usage(term()) :: non_neg_integer()
  def calculate_memory_usage(buffer) do
    # Rough estimate: each cell is about 64 bytes
    buffer.width * buffer.height * 64
  end

  @doc """
  Gets a summary of current metrics.
  """
  @spec get_summary(metrics()) :: map()
  def get_summary(metrics) do
    %{
      total_operations: metrics.performance.total_operations,
      average_response_time_us: metrics.performance.average_response_time,
      operation_counts: metrics.operations,
      throughput_ops_per_sec: calculate_throughput(metrics)
    }
  end

  @doc """
  Resets all metrics to initial state.
  """
  @spec reset(metrics()) :: metrics()
  def reset(_metrics) do
    new()
  end

  # Private helper functions

  defp calculate_throughput(metrics) do
    if metrics.performance.average_response_time > 0 do
      1_000_000 / metrics.performance.average_response_time
    else
      0.0
    end
  end
end
