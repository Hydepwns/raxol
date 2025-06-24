defmodule Raxol.Core.Metrics do
  @moduledoc """
  Core metrics module for Raxol framework.

  This module provides basic metrics collection and recording functionality.
  It serves as the main entry point for metrics operations.
  """

  @doc """
  Initializes the metrics system.

  ## Parameters

  * `options` - Configuration options for metrics (optional)

  ## Returns

  * `:ok` - Metrics system initialized successfully
  * `{:error, reason}` - Failed to initialize metrics system
  """
  @spec init(keyword()) :: :ok | {:error, term()}
  def init(options \\ []) do
    # Initialize metrics subsystems
    try do
      # Start unified collector
      Raxol.Core.Metrics.UnifiedCollector.start_link(options)

      # Initialize aggregator
      Raxol.Core.Metrics.Aggregator.init(options)

      # Initialize alert manager
      Raxol.Core.Metrics.AlertManager.init(options)

      :ok
    rescue
      e ->
        {:error, {:metrics_init_failed, e}}
    end
  end

  @doc """
  Records a metric with the given name, value, and optional tags.

  ## Parameters

  * `name` - Metric name
  * `value` - Metric value (number, string, or map)
  * `tags` - Optional tags as keyword list

  ## Returns

  * `:ok` - Metric recorded successfully
  * `{:error, reason}` - Failed to record metric

  ## Example

  ```elixir
  Raxol.Core.Metrics.record("render_time", 150, [component: "table"])
  Raxol.Core.Metrics.record("user_action", "button_click", [screen: "main"])
  ```
  """
  @spec record(String.t(), any(), keyword()) :: :ok | {:error, term()}
  def record(name, value, tags \\ []) do
    try do
      # Record in unified collector
      Raxol.Core.Metrics.UnifiedCollector.record_metric(name, :custom, value,
        tags: tags
      )

      # Record in aggregator for statistics
      Raxol.Core.Metrics.Aggregator.record(name, value, tags)

      :ok
    rescue
      e ->
        {:error, {:metrics_record_failed, e}}
    end
  end

  @doc """
  Gets all recorded metrics.

  ## Returns

  * `{:ok, metrics}` - Map of recorded metrics
  * `{:error, reason}` - Failed to get metrics
  """
  @spec get_metrics() :: {:ok, map()} | {:error, term()}
  def get_metrics do
    try do
      metrics = Raxol.Core.Metrics.UnifiedCollector.get_all_metrics()
      {:ok, metrics}
    rescue
      e ->
        {:error, {:metrics_get_failed, e}}
    end
  end

  @doc """
  Clears all recorded metrics.

  ## Returns

  * `:ok` - Metrics cleared successfully
  * `{:error, reason}` - Failed to clear metrics
  """
  @spec clear_metrics() :: :ok | {:error, term()}
  def clear_metrics do
    try do
      Raxol.Core.Metrics.UnifiedCollector.clear_metrics()
      Raxol.Core.Metrics.Aggregator.clear()
      :ok
    rescue
      e ->
        {:error, {:metrics_clear_failed, e}}
    end
  end
end
