# Metrics implementation for monitoring
defmodule Raxol.Cloud.Monitoring.Metrics do
  # import Raxol.Guards (remove if not used)

  @moduledoc false

  def init(config) do
    metrics_state = %{
      metrics: %{},
      config: config,
      batch: [],
      last_flush: DateTime.utc_now()
    }

    Raxol.Cloud.Monitoring.Server.init_metrics(metrics_state)
    :ok
  end

  def record(name, value, opts \\ []) do
    opts = normalize_to_keyword(opts)
    metrics_state = get_metrics_state()

    # Create metric entry
    metric = %{
      name: name,
      value: value,
      timestamp: Keyword.get(opts, :timestamp, DateTime.utc_now()),
      tags: Keyword.get(opts, :tags, []),
      source: Keyword.get(opts, :source, :application)
    }

    # Add to metrics history
    updated_metrics =
      Map.update(
        metrics_state.metrics,
        name,
        [metric],
        fn metrics -> [metric | metrics] |> Enum.take(1000) end
      )

    # Add to batch for sending
    updated_batch = [metric | metrics_state.batch]

    # Check if we need to flush the batch
    {updated_batch, updated_last_flush} =
      check_and_flush_batch(
        length(updated_batch) >= metrics_state.config.metrics_batch_size,
        updated_batch,
        metrics_state
      )

    # Update metrics state
    Raxol.Cloud.Monitoring.Server.update_metrics(%{
      metrics_state
      | metrics: updated_metrics,
        batch: updated_batch,
        last_flush: updated_last_flush
    })

    :ok
  end

  def get(name, opts \\ []) do
    opts = normalize_opts(opts)
    metrics_state = get_metrics_state()

    case Map.get(metrics_state.metrics, name) do
      nil -> []
      metrics -> filter_metrics(metrics, opts)
    end
  end

  defp normalize_opts(opts) do
    opts = normalize_to_keyword(opts)

    %{
      limit: Keyword.get(opts, :limit, 100),
      since:
        Keyword.get(
          opts,
          :since,
          DateTime.add(DateTime.utc_now(), -60 * 60, :second)
        ),
      until: Keyword.get(opts, :until, DateTime.utc_now()),
      tags: Keyword.get(opts, :tags)
    }
  end

  defp filter_metrics(metrics, opts) do
    metrics
    |> Enum.filter(&metric_matches?(&1, opts))
    |> Enum.take(opts.limit)
  end

  defp metric_matches?(metric, opts) do
    time_in_range?(metric.timestamp, opts.since, opts.until) &&
      tags_match?(metric, opts.tags)
  end

  defp time_in_range?(timestamp, since, until) do
    DateTime.compare(timestamp, since) in [:gt, :eq] &&
      DateTime.compare(timestamp, until) in [:lt, :eq]
  end

  defp tags_match?(_metric, nil), do: true

  defp tags_match?(metric, tags),
    do: Enum.all?(tags, &(&1 in Map.get(metric, :tags, [])))

  def count() do
    metrics_state = get_metrics_state()

    metrics_state.metrics
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sum()
  end

  defp get_metrics_state() do
    Raxol.Cloud.Monitoring.Server.get_metrics() ||
      %{metrics: %{}, config: %{}, batch: [], last_flush: DateTime.utc_now()}
  end

  defp flush_metrics(batch, config) do
    # FEAT: In a real implementation, this would send metrics to monitoring backends
    Enum.each(config.backends, fn backend ->
      # FEAT: This would call the appropriate backend module
      case backend do
        :datadog -> send_to_datadog(batch)
        :prometheus -> send_to_prometheus(batch)
        :cloudwatch -> send_to_cloudwatch(batch)
        _ -> :ok
      end
    end)
  end

  defp send_to_datadog(_batch) do
    # FEAT: This would use the Datadog API to send metrics
    :ok
  end

  defp send_to_prometheus(_batch) do
    # FEAT: This would use Prometheus client to send metrics
    :ok
  end

  defp send_to_cloudwatch(_batch) do
    # FEAT: This would use AWS SDK to send metrics to CloudWatch
    :ok
  end

  # Helper functions to eliminate if statements

  defp normalize_to_keyword(opts) when is_map(opts), do: Enum.into(opts, [])
  defp normalize_to_keyword(opts), do: opts

  defp check_and_flush_batch(true, updated_batch, metrics_state) do
    # Flush batch to backends
    flush_metrics(updated_batch, metrics_state.config)
    {[], DateTime.utc_now()}
  end

  defp check_and_flush_batch(false, updated_batch, metrics_state) do
    {updated_batch, metrics_state.last_flush}
  end
end
