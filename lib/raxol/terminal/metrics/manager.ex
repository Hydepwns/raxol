defmodule Raxol.Terminal.Metrics.Manager do
  @moduledoc '''
  Manages terminal metrics and statistics collection, including performance
  metrics, usage statistics, and error tracking.
  '''

  defstruct [
    :start_time,
    :last_update,
    :characters_processed,
    :commands_processed,
    :errors_encountered,
    :performance_metrics,
    :usage_stats,
    :error_log,
    :custom_metrics
  ]

  @type performance_metrics :: %{
    processing_time: non_neg_integer(),
    average_latency: float(),
    peak_memory: non_neg_integer(),
    buffer_usage: float()
  }

  @type usage_stats :: %{
    active_time: non_neg_integer(),
    idle_time: non_neg_integer(),
    command_frequency: %{String.t() => non_neg_integer()},
    feature_usage: %{String.t() => non_neg_integer()}
  }

  @type error_log :: %{
    timestamp: DateTime.t(),
    error_type: String.t(),
    message: String.t(),
    context: map()
  }

  @type custom_metrics :: %{String.t() => any()}

  @type t :: %__MODULE__{
    start_time: DateTime.t(),
    last_update: DateTime.t(),
    characters_processed: non_neg_integer(),
    commands_processed: non_neg_integer(),
    errors_encountered: non_neg_integer(),
    performance_metrics: performance_metrics(),
    usage_stats: usage_stats(),
    error_log: [error_log()],
    custom_metrics: custom_metrics()
  }

  @doc '''
  Creates a new metrics manager instance.
  '''
  def new do
    now = DateTime.utc_now()
    %__MODULE__{
      start_time: now,
      last_update: now,
      characters_processed: 0,
      commands_processed: 0,
      errors_encountered: 0,
      performance_metrics: %{
        processing_time: 0,
        average_latency: 0.0,
        peak_memory: 0,
        buffer_usage: 0.0
      },
      usage_stats: %{
        active_time: 0,
        idle_time: 0,
        command_frequency: %{},
        feature_usage: %{}
      },
      error_log: [],
      custom_metrics: %{}
    }
  end

  @doc '''
  Records the processing of characters.
  '''
  def record_characters(%__MODULE__{} = manager, count) when is_integer(count) and count >= 0 do
    %{manager |
      characters_processed: manager.characters_processed + count,
      last_update: DateTime.utc_now()
    }
  end

  @doc '''
  Records the processing of a command.
  '''
  def record_command(%__MODULE__{} = manager, command) when is_binary(command) do
    command_frequency = Map.update(
      manager.usage_stats.command_frequency,
      command,
      1,
      &(&1 + 1)
    )

    usage_stats = Map.put(manager.usage_stats, :command_frequency, command_frequency)

    %{manager |
      commands_processed: manager.commands_processed + 1,
      usage_stats: usage_stats,
      last_update: DateTime.utc_now()
    }
  end

  @doc '''
  Records an error occurrence.
  '''
  def record_error(%__MODULE__{} = manager, error_type, message, context \\ %{}) do
    error_entry = %{
      timestamp: DateTime.utc_now(),
      error_type: error_type,
      message: message,
      context: context
    }

    %{manager |
      errors_encountered: manager.errors_encountered + 1,
      error_log: [error_entry | manager.error_log],
      last_update: DateTime.utc_now()
    }
  end

  @doc '''
  Updates performance metrics.
  '''
  def update_performance_metrics(%__MODULE__{} = manager, metrics) when is_map(metrics) do
    performance_metrics = Map.merge(manager.performance_metrics, metrics)
    %{manager |
      performance_metrics: performance_metrics,
      last_update: DateTime.utc_now()
    }
  end

  @doc '''
  Updates usage statistics.
  '''
  def update_usage_stats(%__MODULE__{} = manager, stats) when is_map(stats) do
    usage_stats = Map.merge(manager.usage_stats, stats)
    %{manager |
      usage_stats: usage_stats,
      last_update: DateTime.utc_now()
    }
  end

  @doc '''
  Records feature usage.
  '''
  def record_feature_usage(%__MODULE__{} = manager, feature) when is_binary(feature) do
    feature_usage = Map.update(
      manager.usage_stats.feature_usage,
      feature,
      1,
      &(&1 + 1)
    )

    usage_stats = Map.put(manager.usage_stats, :feature_usage, feature_usage)

    %{manager |
      usage_stats: usage_stats,
      last_update: DateTime.utc_now()
    }
  end

  @doc '''
  Adds or updates a custom metric.
  '''
  def set_custom_metric(%__MODULE__{} = manager, key, value) when is_binary(key) do
    custom_metrics = Map.put(manager.custom_metrics, key, value)
    %{manager |
      custom_metrics: custom_metrics,
      last_update: DateTime.utc_now()
    }
  end

  @doc '''
  Gets a custom metric value.
  '''
  def get_custom_metric(%__MODULE__{} = manager, key) when is_binary(key) do
    Map.get(manager.custom_metrics, key)
  end

  @doc '''
  Gets the current performance metrics.
  '''
  def get_performance_metrics(%__MODULE__{} = manager) do
    manager.performance_metrics
  end

  @doc '''
  Gets the current usage statistics.
  '''
  def get_usage_stats(%__MODULE__{} = manager) do
    manager.usage_stats
  end

  @doc '''
  Gets the error log.
  '''
  def get_error_log(%__MODULE__{} = manager) do
    manager.error_log
  end

  @doc '''
  Gets the uptime in milliseconds.
  '''
  def get_uptime(%__MODULE__{} = manager) do
    DateTime.diff(DateTime.utc_now(), manager.start_time, :millisecond)
  end

  @doc '''
  Gets the average characters processed per second.
  '''
  def get_characters_per_second(%__MODULE__{} = manager) do
    uptime = get_uptime(manager)
    if uptime > 0 do
      manager.characters_processed / (uptime / 1000)
    else
      0.0
    end
  end

  @doc '''
  Gets the average commands processed per second.
  '''
  def get_commands_per_second(%__MODULE__{} = manager) do
    uptime = get_uptime(manager)
    if uptime > 0 do
      manager.commands_processed / (uptime / 1000)
    else
      0.0
    end
  end

  @doc '''
  Gets the error rate (errors per second).
  '''
  def get_error_rate(%__MODULE__{} = manager) do
    uptime = get_uptime(manager)
    if uptime > 0 do
      manager.errors_encountered / (uptime / 1000)
    else
      0.0
    end
  end

  @doc '''
  Resets all metrics to their initial state.
  '''
  def reset(%__MODULE__{} = _manager) do
    new()
  end
end
