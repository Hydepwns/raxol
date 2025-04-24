defmodule Raxol.Core.Runtime.Debug do
  @moduledoc """
  Provides debugging and diagnostic facilities for the Raxol runtime system.

  This module is responsible for:
  * Capturing runtime state for debugging
  * Performance monitoring and analysis
  * Logging and diagnostics
  """

  require Logger

  @doc """
  Captures the current runtime state for debugging purposes.

  ## Parameters
  - `state`: The current runtime state
  - `options`: Options for state capture
    - `:include_buffer` - Whether to include screen buffer data (default: false)
    - `:include_model` - Whether to include application model (default: true)
    - `:sanitize` - Whether to sanitize sensitive data (default: true)

  ## Returns
  A map containing the captured state.
  """
  def capture_state(state, options \\ []) do
    include_buffer = Keyword.get(options, :include_buffer, false)
    include_model = Keyword.get(options, :include_model, true)
    sanitize = Keyword.get(options, :sanitize, true)

    # Base debug info
    debug_info = %{
      timestamp: :os.system_time(:millisecond),
      environment: state.environment,
      width: state.width,
      height: state.height,
      fps: state.fps,
      app_module: state.app_module,
      app_name: state.app_name
    }

    # Add model if requested
    debug_info =
      if include_model do
        model =
          if sanitize do
            sanitize_model(state.model)
          else
            state.model
          end

        Map.put(debug_info, :model, model)
      else
        debug_info
      end

    # Add buffer if requested
    debug_info =
      if include_buffer and state.screen_buffer do
        Map.put(debug_info, :buffer, %{
          width: state.screen_buffer.width,
          height: state.screen_buffer.height,
          cell_count: map_size(state.screen_buffer.cells)
        })
      else
        debug_info
      end

    # Add performance metrics
    Map.put(debug_info, :performance, get_performance_metrics(state))
  end

  @doc """
  Analyzes performance metrics from the runtime state.

  ## Parameters
  - `state`: The current runtime state

  ## Returns
  A map containing performance metrics.
  """
  def analyze_performance(state) do
    # Basic metrics
    metrics = get_performance_metrics(state)

    # Interpret metrics
    fps = metrics.current_fps
    target_fps = state.fps

    fps_analysis =
      cond do
        fps < target_fps * 0.7 ->
          "FPS is significantly below target. Consider optimizing rendering or reducing visual complexity."

        fps < target_fps * 0.9 ->
          "FPS is slightly below target. Performance is acceptable but could be improved."

        fps >= target_fps * 0.9 and fps <= target_fps * 1.1 ->
          "FPS is at or near target. Performance is good."

        true ->
          "FPS is above target. Performance headroom exists."
      end

    render_time = metrics.avg_render_time
    frame_budget = trunc(1000 / target_fps)

    render_analysis =
      cond do
        render_time > frame_budget * 0.8 ->
          "Render time is consuming most of the frame budget. Consider optimizing view rendering."

        render_time > frame_budget * 0.5 ->
          "Render time is reasonable but occupies a significant portion of the frame budget."

        true ->
          "Render time is well within the frame budget. Performance is good."
      end

    # Return analysis
    Map.merge(metrics, %{
      fps_analysis: fps_analysis,
      render_analysis: render_analysis,
      frame_budget: frame_budget
    })
  end

  @doc """
  Generates a status report for the runtime system.

  ## Parameters
  - `state`: The current runtime state

  ## Returns
  A formatted status report.
  """
  def report_status(state) do
    perf = analyze_performance(state)

    """
    Raxol Runtime Status Report
    ==========================

    Application: #{state.app_module} (#{state.app_name})
    Environment: #{state.environment}
    Dimensions: #{state.width}x#{state.height}

    Performance:
    - Target FPS: #{state.fps}
    - Current FPS: #{perf.current_fps}
    - Frame budget: #{perf.frame_budget}ms
    - Avg render time: #{perf.avg_render_time}ms
    - Frame timing: #{perf.frame_timing}

    Analysis:
    #{perf.fps_analysis}
    #{perf.render_analysis}

    Memory:
    - Process memory: #{format_bytes(perf.process_memory)}
    - Total system memory: #{format_bytes(perf.total_memory)}

    Runtime: #{state.uptime}s
    """
  end

  @doc """
  Logs debugging information at the specified level.

  ## Parameters
  - `state`: The current runtime state
  - `level`: Log level (:debug, :info, :warn, :error)
  - `message`: Message to log
  - `metadata`: Additional metadata to include
  """
  def log(state, level, message, metadata \\ []) do
    # Only log if debug mode is enabled, unless it's an error
    if state.debug_mode or level == :error do
      app_metadata = [
        app: state.app_name,
        module: state.app_module,
        runtime_pid: self()
      ]

      # Merge with provided metadata
      combined_metadata = Keyword.merge(app_metadata, metadata)

      case level do
        :debug -> Logger.debug(message, combined_metadata)
        :info -> Logger.info(message, combined_metadata)
        :warn -> Logger.warning(message, combined_metadata)
        :error -> Logger.error(message, combined_metadata)
        _ -> Logger.debug(message, combined_metadata)
      end
    end
  end

  @doc """
  Starts performance monitoring for a specific runtime instance.

  ## Parameters
  - `state`: The current runtime state

  ## Returns
  Updated state with monitoring started.
  """
  def start_monitoring(state) do
    # Create a new empty metrics map
    initial_metrics = %{
      render_times: [],
      start_time: :os.system_time(:millisecond),
      frame_count: 0
    }

    # Store in state
    Map.put(state, :metrics, initial_metrics)
  end

  @doc """
  Records a render event in the performance metrics.

  ## Parameters
  - `state`: The current runtime state
  - `render_time`: Time taken to render the frame (in ms)

  ## Returns
  Updated state with the render event recorded.
  """
  def record_render(state, render_time) do
    if Map.has_key?(state, :metrics) do
      # Get current metrics
      metrics = state.metrics

      # Add render time to the list, keeping only the last 60 frames
      render_times =
        [render_time | metrics.render_times]
        |> Enum.take(60)

      # Increment frame count
      frame_count = metrics.frame_count + 1

      # Update metrics
      updated_metrics = %{
        metrics |
        render_times: render_times,
        frame_count: frame_count,
        last_render_time: render_time
      }

      # Store updated metrics in state
      %{state | metrics: updated_metrics}
    else
      # No metrics tracking enabled
      state
    end
  end

  # Private helper functions

  defp get_performance_metrics(state) do
    # Default metrics if no tracking is enabled
    base_metrics = %{
      current_fps: state.fps,
      avg_render_time: 0,
      frame_timing: "N/A",
      process_memory: Process.info(self(), :memory) |> elem(1),
      total_memory: :erlang.memory(:total)
    }

    # If we have metrics in the state, enhance with that data
    if state.metrics do
      metrics = state.metrics

      # Calculate current FPS based on last 60 frames
      uptime =
        (:os.system_time(:millisecond) - metrics.start_time) / 1000

      current_fps =
        if uptime > 0 do
          metrics.frame_count / uptime
        else
          0
        end

      # Calculate average render time
      avg_render_time =
        if length(metrics.render_times) > 0 do
          Enum.sum(metrics.render_times) / length(metrics.render_times)
        else
          0
        end

      # Determine frame timing status
      frame_budget = 1000 / state.fps

      frame_timing =
        cond do
          avg_render_time > frame_budget ->
            "Over budget (#{trunc(avg_render_time)}ms/#{trunc(frame_budget)}ms)"

          avg_render_time > frame_budget * 0.8 ->
            "Near budget (#{trunc(avg_render_time)}ms/#{trunc(frame_budget)}ms)"

          true ->
            "Within budget (#{trunc(avg_render_time)}ms/#{trunc(frame_budget)}ms)"
        end

      # Update metrics
      Map.merge(base_metrics, %{
        current_fps: current_fps,
        avg_render_time: avg_render_time,
        frame_timing: frame_timing,
        uptime: uptime
      })
    else
      base_metrics
    end
  end

  defp sanitize_model(model) do
    # This is a placeholder implementation that attempts to sanitize
    # potentially sensitive data in the model
    sanitize_map(model)
  end

  defp sanitize_map(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      # Check if key suggests sensitive data
      if is_sensitive_key?(k) do
        {k, "[REDACTED]"}
      else
        {k, sanitize_value(v)}
      end
    end)
    |> Map.new()
  end

  defp sanitize_value(value) when is_map(value), do: sanitize_map(value)
  defp sanitize_value(value) when is_list(value), do: Enum.map(value, &sanitize_value/1)
  defp sanitize_value(value), do: value

  defp is_sensitive_key?(key) when is_atom(key) do
    string_key = Atom.to_string(key)
    is_sensitive_key?(string_key)
  end

  defp is_sensitive_key?(key) when is_binary(key) do
    sensitive_patterns = [
      "password", "token", "secret", "key", "auth", "credential", "private"
    ]

    Enum.any?(sensitive_patterns, fn pattern ->
      String.contains?(String.downcase(key), pattern)
    end)
  end

  defp is_sensitive_key?(_), do: false

  defp format_bytes(bytes) when is_integer(bytes) and bytes < 1024 do
    "#{bytes} B"
  end

  defp format_bytes(bytes) when is_integer(bytes) and bytes < 1024 * 1024 do
    kb = bytes / 1024
    "#{Float.round(kb, 2)} KB"
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    mb = bytes / (1024 * 1024)
    "#{Float.round(mb, 2)} MB"
  end

  defp format_bytes(_), do: "Unknown"
end
