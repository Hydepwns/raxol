# Errors implementation for monitoring
defmodule Raxol.Cloud.Monitoring.Errors do
  import Raxol.Guards

  @moduledoc false

  # Process dictionary key for errors
  @errors_key :raxol_monitoring_errors

  def init(config) do
    errors_state = %{
      errors: [],
      config: config
    }

    Process.put(@errors_key, errors_state)
    :ok
  end

  def record(error, opts \\ []) do
    opts = if map?(opts), do: Enum.into(opts, []), else: opts
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
    updated_errors = [error_entry | errors_state.errors] |> Enum.take(1000)

    # Update errors state
    Process.put(@errors_key, %{errors_state | errors: updated_errors})

    # Send to backends
    send_error_to_backends(error_entry, errors_state.config)

    :ok
  end

  def get(opts \\ []) do
    opts = if map?(opts), do: Enum.into(opts, []), else: opts
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
    Process.get(@errors_key) || %{errors: [], config: %{}}
  end

  defp get_error_message(error) do
    cond do
      Exception.exception?(error) && Map.has_key?(error, :message) ->
        error.message

      binary?(error) ->
        error

      true ->
        inspect(error)
    end
  end

  defp get_stacktrace(opts) do
    opts = if map?(opts), do: Enum.into(opts, []), else: opts

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
end
