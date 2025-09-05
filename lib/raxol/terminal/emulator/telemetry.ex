defmodule Raxol.Terminal.Emulator.Telemetry do
  @moduledoc """
  Telemetry instrumentation for the terminal emulator.

  Provides comprehensive error tracking and performance monitoring
  for terminal emulation operations.
  """

  require Logger

  @emulator_events [
    [:raxol, :emulator, :input, :start],
    [:raxol, :emulator, :input, :stop],
    [:raxol, :emulator, :input, :exception],
    [:raxol, :emulator, :sequence, :start],
    [:raxol, :emulator, :sequence, :stop],
    [:raxol, :emulator, :sequence, :exception],
    [:raxol, :emulator, :resize, :start],
    [:raxol, :emulator, :resize, :stop],
    [:raxol, :emulator, :resize, :exception],
    [:raxol, :emulator, :error, :recorded],
    [:raxol, :emulator, :recovery, :attempted],
    [:raxol, :emulator, :recovery, :succeeded],
    [:raxol, :emulator, :recovery, :failed],
    [:raxol, :emulator, :health, :check],
    [:raxol, :emulator, :checkpoint, :created],
    [:raxol, :emulator, :checkpoint, :restored]
  ]

  @doc """
  Lists all emulator telemetry events.
  """
  def events, do: @emulator_events

  @doc """
  Attaches default telemetry handlers for logging.
  """
  def attach_default_handlers do
    handlers = [
      {[:raxol, :emulator, :input, :exception], &handle_input_exception/4},
      {[:raxol, :emulator, :sequence, :exception],
       &handle_sequence_exception/4},
      {[:raxol, :emulator, :resize, :exception], &handle_resize_exception/4},
      {[:raxol, :emulator, :error, :recorded], &handle_error_recorded/4},
      {[:raxol, :emulator, :recovery, :failed], &handle_recovery_failed/4},
      {[:raxol, :emulator, :health, :check], &handle_health_check/4}
    ]

    Enum.each(handlers, fn {event, handler} ->
      handler_id = "#{__MODULE__}-#{Enum.join(event, "-")}"

      :telemetry.attach(
        handler_id,
        event,
        handler,
        nil
      )
    end)
  end

  @doc """
  Executes a function with telemetry instrumentation.
  """
  def span(event_prefix, metadata, fun) do
    start_metadata = Map.put(metadata, :start_time, System.monotonic_time())

    :telemetry.execute(
      event_prefix ++ [:start],
      %{system_time: System.system_time()},
      start_metadata
    )

    case Raxol.Core.ErrorHandling.safe_call(fn ->
           fun.()
         end) do
      {:ok, result} ->
        stop_metadata =
          Map.merge(start_metadata, %{
            duration: System.monotonic_time() - start_metadata.start_time,
            result: :ok
          })

        :telemetry.execute(
          event_prefix ++ [:stop],
          %{duration: stop_metadata.duration},
          stop_metadata
        )

        result

      {:error, {exception, stacktrace}} ->
        exception_metadata =
          Map.merge(start_metadata, %{
            duration: System.monotonic_time() - start_metadata.start_time,
            exception: exception,
            stacktrace: stacktrace
          })

        :telemetry.execute(
          event_prefix ++ [:exception],
          %{duration: exception_metadata.duration},
          exception_metadata
        )

        reraise exception, stacktrace
    end
  end

  @doc """
  Records an error event.
  """
  def record_error(error_type, reason, metadata \\ %{}) do
    :telemetry.execute(
      [:raxol, :emulator, :error, :recorded],
      %{count: 1},
      Map.merge(metadata, %{
        error_type: error_type,
        reason: reason,
        timestamp: DateTime.utc_now()
      })
    )
  end

  @doc """
  Records a recovery attempt.
  """
  def record_recovery_attempt(metadata \\ %{}) do
    :telemetry.execute(
      [:raxol, :emulator, :recovery, :attempted],
      %{count: 1},
      Map.put(metadata, :timestamp, DateTime.utc_now())
    )
  end

  @doc """
  Records a successful recovery.
  """
  def record_recovery_success(metadata \\ %{}) do
    :telemetry.execute(
      [:raxol, :emulator, :recovery, :succeeded],
      %{count: 1},
      Map.put(metadata, :timestamp, DateTime.utc_now())
    )
  end

  @doc """
  Records a failed recovery.
  """
  def record_recovery_failure(reason, metadata \\ %{}) do
    :telemetry.execute(
      [:raxol, :emulator, :recovery, :failed],
      %{count: 1},
      Map.merge(metadata, %{
        reason: reason,
        timestamp: DateTime.utc_now()
      })
    )
  end

  @doc """
  Records a health check.
  """
  def record_health_check(status, metadata \\ %{}) do
    :telemetry.execute(
      [:raxol, :emulator, :health, :check],
      %{status: status_to_number(status)},
      Map.merge(metadata, %{
        status: status,
        timestamp: DateTime.utc_now()
      })
    )
  end

  @doc """
  Records checkpoint creation.
  """
  def record_checkpoint_created(metadata \\ %{}) do
    :telemetry.execute(
      [:raxol, :emulator, :checkpoint, :created],
      %{count: 1},
      Map.put(metadata, :timestamp, DateTime.utc_now())
    )
  end

  @doc """
  Records checkpoint restoration.
  """
  def record_checkpoint_restored(metadata \\ %{}) do
    :telemetry.execute(
      [:raxol, :emulator, :checkpoint, :restored],
      %{count: 1},
      Map.put(metadata, :timestamp, DateTime.utc_now())
    )
  end

  # Private handler functions

  defp handle_input_exception(_event, measurements, metadata, _config) do
    Logger.error("""
    Emulator input processing exception:
      Duration: #{format_duration(measurements[:duration])}
      Exception: #{inspect(metadata[:exception])}
      Metadata: #{inspect(Map.drop(metadata, [:exception, :stacktrace]))}
    """)
  end

  defp handle_sequence_exception(_event, measurements, metadata, _config) do
    Logger.error("""
    Emulator sequence handling exception:
      Duration: #{format_duration(measurements[:duration])}
      Exception: #{inspect(metadata[:exception])}
      Sequence: #{inspect(metadata[:sequence])}
    """)
  end

  defp handle_resize_exception(_event, measurements, metadata, _config) do
    Logger.error("""
    Emulator resize exception:
      Duration: #{format_duration(measurements[:duration])}
      Exception: #{inspect(metadata[:exception])}
      Dimensions: #{metadata[:width]}x#{metadata[:height]}
    """)
  end

  defp handle_error_recorded(_event, _measurements, metadata, _config) do
    Logger.warning("""
    Emulator error recorded:
      Type: #{metadata[:error_type]}
      Reason: #{inspect(metadata[:reason])}
      Timestamp: #{metadata[:timestamp]}
    """)
  end

  defp handle_recovery_failed(_event, _measurements, metadata, _config) do
    Logger.error("""
    Emulator recovery failed:
      Reason: #{inspect(metadata[:reason])}
      Timestamp: #{metadata[:timestamp]}
    """)
  end

  defp handle_health_check(_event, measurements, metadata, _config) do
    log_health_check(metadata[:status], measurements, metadata)
  end

  defp format_duration(nil), do: "N/A"

  defp format_duration(duration) when is_integer(duration) do
    "#{System.convert_time_unit(duration, :native, :microsecond)} μs"
  end

  defp status_to_number(:healthy), do: 0
  defp status_to_number(:degraded), do: 1
  defp status_to_number(:critical), do: 2
  defp status_to_number(:fallback), do: 3
  defp status_to_number(_), do: -1

  # Helper function for pattern matching instead of if statement
  defp log_health_check(:healthy, _measurements, _metadata), do: :ok
  defp log_health_check(status, measurements, metadata) do
    Logger.info("""
    Emulator health check:
      Status: #{status}
      Value: #{measurements[:status]}
    """)
  end
end
