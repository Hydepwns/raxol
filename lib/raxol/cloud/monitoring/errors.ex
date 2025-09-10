# Errors implementation for monitoring
defmodule Raxol.Cloud.Monitoring.Errors do
  @moduledoc false

  def init(config) do
    errors_state = %{
      errors: [],
      config: config
    }

    Raxol.Cloud.Monitoring.MonitoringServer.init_monitoring(errors_state)
    :ok
  end

  def record(error, opts \\ []) do
    opts = normalize_opts(opts)
    errors_state = get_errors_state()

    # Create error entry
    error_entry = %{
      error: error,
      message: get_error_message(error),
      stack: get_stacktrace(opts),
      context: Keyword.get(opts, :context, %{}),
      severity: Keyword.get(opts, :severity, :error),
      tags: Keyword.get(opts, :tags, []),
      timestamp: Keyword.get(opts, :timestamp, DateTime.utc_now()),
      session_id: Keyword.get(opts, :session_id)
    }

    # Add to errors history
    _updated_errors = [error_entry | errors_state.errors] |> Enum.take(1000)

    # Record error using the existing function
    Raxol.Cloud.Monitoring.MonitoringServer.record_error(error_entry)

    # Send to backends
    send_error_to_backends(error_entry, errors_state.config)

    :ok
  end

  def get(opts \\ []) do
    opts = normalize_opts(opts)
    errors_state = get_errors_state()

    limit = Keyword.get(opts, :limit, 100)

    since =
      Keyword.get(
        opts,
        :since,
        DateTime.add(DateTime.utc_now(), -24 * 60 * 60, :second)
      )

    until = Keyword.get(opts, :until, DateTime.utc_now())
    severity = Keyword.get(opts, :severity)
    tags = Keyword.get(opts, :tags)

    errors_state.errors
    |> Enum.filter(fn error ->
      DateTime.compare(error.timestamp, since) in [:gt, :eq] &&
        DateTime.compare(error.timestamp, until) in [:lt, :eq] &&
        (severity == nil || error.severity == severity) &&
        (tags == nil || Enum.all?(tags, &(&1 in Map.get(error, :tags, []))))
    end)
    |> Enum.take(limit)
  end

  def count() do
    errors_state = get_errors_state()
    length(errors_state.errors)
  end

  # Private helpers

  defp get_errors_state() do
    Raxol.Cloud.Monitoring.MonitoringServer.get_errors() ||
      %{errors: [], config: %{}}
  end

  # Helper functions for pattern matching refactoring

  defp get_error_message(error)
       when Kernel.is_exception(error) and is_map_key(error, :message),
       do: error.message

  defp get_error_message(error) when is_binary(error),
    do: error

  defp get_error_message(error),
    do: inspect(error)

  defp get_stacktrace(opts) do
    opts = normalize_opts(opts)

    Keyword.get(
      opts,
      :stacktrace,
      Process.info(self(), :current_stacktrace) |> elem(1)
    )
  end

  defp send_error_to_backends(error, config) do
    # In a real implementation, this would send errors to monitoring backends
    Enum.each(config.backends, fn backend ->
      # This would call the appropriate backend module
      case backend do
        :sentry -> send_to_sentry(error)
        :bugsnag -> send_to_bugsnag(error)
        :honeybadger -> send_to_honeybadger(error)
        _ -> :ok
      end
    end)
  end

  defp send_to_sentry(_error) do
    # FEAT: This would use the Sentry client to send errors
    :ok
  end

  defp send_to_bugsnag(_error) do
    # FEAT: This would use the Bugsnag client to send errors
    :ok
  end

  defp send_to_honeybadger(_error) do
    # FEAT: This would use the Honeybadger client to send errors
    :ok
  end

  # Helper function to eliminate if statements
  defp normalize_opts(opts) when is_map(opts), do: Enum.into(opts, [])
  defp normalize_opts(opts), do: opts
end
