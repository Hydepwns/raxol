defmodule Raxol.Performance.TelemetryInstrumentation do
  @moduledoc """
  Telemetry instrumentation for Raxol hot paths.

  Provides consistent telemetry events across the codebase for:
  - Performance monitoring
  - Predictive optimization
  - Debugging and profiling

  All measurements are in microseconds unless otherwise noted.
  """

  @doc """
  Instrument a function call with telemetry.

  ## Example

      instrument(:terminal_parse, %{sequence_type: :csi}, fn ->
        # expensive operation
      end)
  """
  def instrument(event_name, metadata \\ %{}, fun)
      when is_atom(event_name) and is_function(fun, 0) do
    start_time = System.monotonic_time(:microsecond)

    case Raxol.Core.ErrorHandling.safe_call_with_info(fun) do
      {:ok, result} ->
        duration = System.monotonic_time(:microsecond) - start_time

        :telemetry.execute(
          [:raxol | event_to_path(event_name)],
          %{duration: duration, success: true},
          metadata
        )

        result

      {:error, {kind, error, stacktrace}} ->
        duration = System.monotonic_time(:microsecond) - start_time

        :telemetry.execute(
          [:raxol | event_to_path(event_name)],
          %{duration: duration, success: false, error: true},
          Map.merge(metadata, %{error_kind: kind, error: inspect(error)})
        )

        :erlang.raise(kind, error, stacktrace)
    end
  end

  @doc """
  Instrument a function with start/stop events.

  Useful for async operations or when you need more control.
  """
  def start_span(event_name, metadata \\ %{}) do
    start_time = System.monotonic_time(:microsecond)
    span_ref = make_ref()

    :telemetry.execute(
      [:raxol | event_to_path(event_name)] ++ [:start],
      %{system_time: System.system_time()},
      Map.merge(metadata, %{span_ref: span_ref})
    )

    {span_ref, start_time}
  end

  def stop_span(event_name, {span_ref, start_time}, metadata \\ %{}) do
    duration = System.monotonic_time(:microsecond) - start_time

    :telemetry.execute(
      [:raxol | event_to_path(event_name)] ++ [:stop],
      %{duration: duration, system_time: System.system_time()},
      Map.merge(metadata, %{span_ref: span_ref})
    )

    duration
  end

  @doc """
  Record a cache hit or miss.
  """
  def cache_hit(cache_name, key) do
    :telemetry.execute(
      [:raxol, :cache, :hit],
      %{count: 1},
      %{cache_name: cache_name, key: inspect(key)}
    )
  end

  def cache_miss(cache_name, key) do
    :telemetry.execute(
      [:raxol, :cache, :miss],
      %{count: 1},
      %{cache_name: cache_name, key: inspect(key)}
    )
  end

  def cache_eviction(cache_name, evicted_count) do
    :telemetry.execute(
      [:raxol, :cache, :eviction],
      %{evicted_count: evicted_count},
      %{cache_name: cache_name}
    )
  end

  @doc """
  Record buffer operations.
  """
  def buffer_write(buffer_id, bytes_written, cell_count) do
    :telemetry.execute(
      [:raxol, :terminal, :buffer, :write],
      %{bytes: bytes_written, cells: cell_count},
      %{buffer_id: buffer_id, operation: :write}
    )
  end

  def buffer_read(buffer_id, bytes_read, cell_count) do
    :telemetry.execute(
      [:raxol, :terminal, :buffer, :read],
      %{bytes: bytes_read, cells: cell_count},
      %{buffer_id: buffer_id, operation: :read}
    )
  end

  def buffer_scroll(buffer_id, lines) do
    :telemetry.execute(
      [:raxol, :terminal, :buffer, :scroll],
      %{lines: abs(lines)},
      %{buffer_id: buffer_id, direction: get_scroll_direction(lines)}
    )
  end

  defp get_scroll_direction(lines) when lines > 0, do: :down
  defp get_scroll_direction(_lines), do: :up

  @doc """
  Record rendering operations.
  """
  def render_start(component_type, props_hash) do
    start_span(:ui_component_render, %{
      component: component_type,
      props_hash: props_hash
    })
  end

  def render_stop(component_type, span, rendered_nodes) do
    stop_span(:ui_component_render, span, %{
      component: component_type,
      rendered_nodes: rendered_nodes
    })
  end

  def layout_calculation(tree_hash, constraints, fun) do
    instrument(
      :ui_layout_calculate,
      %{tree_hash: tree_hash, constraints: inspect(constraints)},
      fun
    )
  end

  def style_resolution(theme_id, component_type, fun) do
    instrument(
      :ui_style_resolve,
      %{theme_id: theme_id, component: component_type},
      fun
    )
  end

  @doc """
  Record parser operations.
  """
  def parse_ansi(sequence_type, sequence_length, fun) do
    instrument(
      :terminal_parse,
      %{
        sequence_type: sequence_type,
        sequence_length: sequence_length,
        operation: :parse_ansi
      },
      fun
    )
  end

  def parse_csi(sequence, fun) do
    instrument(
      :terminal_parse,
      %{
        # Truncate for telemetry
        sequence: String.slice(sequence, 0, 20),
        operation: :parse_csi
      },
      fun
    )
  end

  @doc """
  Setup default telemetry handlers for monitoring.
  """
  def setup_default_handlers do
    # Performance reporter
    _ =
      :telemetry.attach(
        "raxol-performance-reporter",
        [:raxol, :terminal, :parse],
        &handle_performance_event/4,
        nil
      )

    # Cache reporter
    _ =
      :telemetry.attach_many(
        "raxol-cache-reporter",
        [
          [:raxol, :cache, :hit],
          [:raxol, :cache, :miss],
          [:raxol, :cache, :eviction]
        ],
        &handle_cache_event/4,
        nil
      )

    # Slow operation detector
    :telemetry.attach_many(
      "raxol-slow-operation-detector",
      [
        [:raxol, :terminal, :buffer, :write],
        [:raxol, :ui, :component, :render],
        [:raxol, :ui, :layout, :calculate]
      ],
      &handle_slow_operation/4,
      # 1ms threshold
      %{threshold: 1000}
    )
  end

  # Private functions

  defp event_to_path(event_name) when is_atom(event_name) do
    event_name
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.to_atom/1)
  end

  defp handle_performance_event(event, measurements, metadata, _config) do
    # Log operations over 100μs
    log_performance_if_slow(
      measurements.duration,
      event,
      measurements,
      metadata
    )
  end

  defp log_performance_if_slow(duration, _event, _measurements, _metadata)
       when duration <= 100,
       do: :ok

  defp log_performance_if_slow(_duration, event, measurements, metadata) do
    require Logger

    Logger.debug("""
    Performance event: #{inspect(event)}
    Duration: #{measurements.duration}μs
    Metadata: #{inspect(metadata)}
    """)
  end

  defp handle_cache_event(
         [:raxol, :cache, type],
         measurements,
         metadata,
         _config
       ) do
    # Update cache statistics
    cache_name = metadata.cache_name

    # This could be sent to a monitoring system
    require Logger
    Logger.debug("Cache #{type} for #{cache_name}: #{inspect(measurements)}")
  end

  defp handle_slow_operation(event, measurements, metadata, %{
         threshold: threshold
       }) do
    log_slow_operation_if_needed(
      measurements[:duration],
      measurements.duration,
      threshold,
      event,
      measurements,
      metadata
    )
  end

  defp log_slow_operation_if_needed(
         nil,
         _duration,
         _threshold,
         _event,
         _measurements,
         _metadata
       ),
       do: :ok

  defp log_slow_operation_if_needed(
         _duration_key,
         duration,
         threshold,
         _event,
         _measurements,
         _metadata
       )
       when duration <= threshold,
       do: :ok

  defp log_slow_operation_if_needed(
         _duration_key,
         _duration,
         threshold,
         event,
         measurements,
         metadata
       ) do
    require Logger

    Logger.warning("""
    Slow operation detected: #{inspect(event)}
    Duration: #{measurements.duration}μs (threshold: #{threshold}μs)
    Metadata: #{inspect(metadata)}
    """)
  end
end
