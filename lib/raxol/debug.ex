defmodule Raxol.Debug do
  @moduledoc """
  Debug mode utilities and detailed logging for Raxol terminal emulator.

  This module provides comprehensive debugging capabilities including:
  - Conditional debug logging based on configuration
  - Performance timing and profiling
  - Terminal state inspection
  - ANSI sequence debugging
  - Event flow tracing
  """

  require Logger

  @doc """
  Check if debug mode is enabled for a specific component.
  """
  @spec debug_enabled?(atom()) :: boolean()
  def debug_enabled?(component \\ :terminal) do
    case component do
      :terminal -> Application.get_env(:raxol, :terminal, [])[:debug_mode] || false
      :web -> Application.get_env(:raxol, :web, [])[:debug_mode] || false
      :benchmark -> System.get_env("BENCHMARK_DEBUG") == "true"
      :parser -> System.get_env("PARSER_DEBUG") == "true"
      :rendering -> System.get_env("RENDER_DEBUG") == "true"
      _ -> Application.get_env(:raxol, :debug_mode, false)
    end
  end

  @doc """
  Debug log that only outputs when debug mode is enabled.
  """
  @spec debug_log(binary() | atom(), any(), keyword()) :: :ok
  def debug_log(component, message, opts \\ []) when is_atom(component) do
    if debug_enabled?(component) do
      context = Keyword.get(opts, :context, %{})
      metadata = Keyword.get(opts, :metadata, [])

      formatted_message = format_debug_message(component, message, context)
      Logger.debug(formatted_message, metadata)
    end
    :ok
  end

  @doc """
  Time execution of a function and log the results if debug mode is enabled.
  """
  @spec time_debug(atom(), binary(), function()) :: any()
  def time_debug(component, operation, fun) when is_function(fun, 0) do
    if debug_enabled?(component) do
      {time_us, result} = :timer.tc(fun)
      debug_log(component, "#{operation} completed in #{time_us}μs",
        metadata: [operation: operation, duration_us: time_us])
      result
    else
      fun.()
    end
  end

  @doc """
  Log terminal state for debugging.
  """
  @spec log_terminal_state(map(), keyword()) :: :ok
  def log_terminal_state(state, opts \\ []) do
    if debug_enabled?(:terminal) do
      cursor_pos = get_in(state, [:cursor, :position]) || {0, 0}
      dimensions = get_in(state, [:dimensions]) || {80, 24}
      mode = get_in(state, [:mode]) || :normal

      debug_log(:terminal, "Terminal State", context: %{
        cursor_position: cursor_pos,
        dimensions: dimensions,
        mode: mode,
        buffer_lines: get_buffer_line_count(state),
        scroll_position: get_in(state, [:scroll, :position]) || 0
      }, metadata: Keyword.get(opts, :metadata, []))
    end
    :ok
  end

  @doc """
  Log ANSI sequence parsing for debugging.
  """
  @spec log_ansi_sequence(binary(), map(), keyword()) :: :ok
  def log_ansi_sequence(sequence, parsed_data, opts \\ []) do
    if debug_enabled?(:parser) do
      debug_log(:parser, "ANSI Sequence Parsed", context: %{
        raw_sequence: inspect(sequence),
        sequence_type: parsed_data[:type],
        parameters: parsed_data[:params],
        final_char: parsed_data[:final],
        length: byte_size(sequence)
      }, metadata: Keyword.get(opts, :metadata, []))
    end
    :ok
  end

  @doc """
  Log event flow for debugging event handling.
  """
  @spec log_event_flow(atom(), map(), map(), keyword()) :: :ok
  def log_event_flow(event_type, event_data, handler_result, opts \\ []) do
    if debug_enabled?(:terminal) do
      debug_log(:terminal, "Event Flow", context: %{
        event_type: event_type,
        event_data: sanitize_event_data(event_data),
        handler_result: inspect(handler_result),
        timestamp: System.monotonic_time(:millisecond)
      }, metadata: Keyword.get(opts, :metadata, []))
    end
    :ok
  end

  @doc """
  Log rendering performance metrics.
  """
  @spec log_render_metrics(map(), keyword()) :: :ok
  def log_render_metrics(metrics, opts \\ []) do
    if debug_enabled?(:rendering) do
      debug_log(:rendering, "Render Metrics", context: %{
        frame_time_us: metrics[:frame_time_us],
        dirty_regions: length(metrics[:dirty_regions] || []),
        buffer_size: metrics[:buffer_size],
        operations_count: metrics[:operations_count],
        memory_usage: metrics[:memory_usage]
      }, metadata: Keyword.get(opts, :metadata, []))
    end
    :ok
  end

  @doc """
  Conditional breakpoint that only triggers in debug mode.
  Useful for interactive debugging.
  """
  @spec debug_breakpoint(atom(), binary()) :: :ok
  def debug_breakpoint(component, reason \\ "Debug breakpoint") do
    if debug_enabled?(component) and interactive_mode?() do
      IO.puts("🔍 Debug breakpoint hit: #{reason}")
      IO.puts("Component: #{component}")
      IO.puts("Process: #{inspect(self())}")
      IO.puts("Press Enter to continue...")
      IO.read(:line)
    end
    :ok
  end

  @doc """
  Dump current process state for debugging.
  """
  @spec dump_process_state(atom()) :: :ok
  def dump_process_state(component) do
    if debug_enabled?(component) do
      process_info = Process.info(self())
      debug_log(component, "Process State Dump", context: %{
        pid: inspect(self()),
        message_queue_len: process_info[:message_queue_len],
        memory: process_info[:memory],
        heap_size: process_info[:heap_size],
        stack_size: process_info[:stack_size],
        reductions: process_info[:reductions]
      })
    end
    :ok
  end

  @doc """
  Enable debug mode for a component at runtime.
  """
  @spec enable_debug(atom()) :: :ok
  def enable_debug(component) do
    case component do
      :terminal ->
        terminal_config = Application.get_env(:raxol, :terminal, [])
        Application.put_env(:raxol, :terminal, Keyword.put(terminal_config, :debug_mode, true))
      :web ->
        web_config = Application.get_env(:raxol, :web, [])
        Application.put_env(:raxol, :web, Keyword.put(web_config, :debug_mode, true))
      _ ->
        Application.put_env(:raxol, :debug_mode, true)
    end
    Logger.info("Debug mode enabled for #{component}")
    :ok
  end

  @doc """
  Disable debug mode for a component at runtime.
  """
  @spec disable_debug(atom()) :: :ok
  def disable_debug(component) do
    case component do
      :terminal ->
        terminal_config = Application.get_env(:raxol, :terminal, [])
        Application.put_env(:raxol, :terminal, Keyword.put(terminal_config, :debug_mode, false))
      :web ->
        web_config = Application.get_env(:raxol, :web, [])
        Application.put_env(:raxol, :web, Keyword.put(web_config, :debug_mode, false))
      _ ->
        Application.put_env(:raxol, :debug_mode, false)
    end
    Logger.info("Debug mode disabled for #{component}")
    :ok
  end

  @doc """
  Get current debug configuration.
  """
  @spec debug_config() :: map()
  def debug_config do
    %{
      terminal: debug_enabled?(:terminal),
      web: debug_enabled?(:web),
      benchmark: debug_enabled?(:benchmark),
      parser: debug_enabled?(:parser),
      rendering: debug_enabled?(:rendering),
      general: debug_enabled?(:general),
      log_level: Logger.level()
    }
  end

  # Private helper functions

  @spec format_debug_message(atom(), any(), map()) :: binary()
  defp format_debug_message(component, message, context) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    context_str = if map_size(context) > 0 do
      " | Context: #{inspect(context)}"
    else
      ""
    end

    "[#{timestamp}] [#{String.upcase(to_string(component))}] #{message}#{context_str}"
  end

  @spec get_buffer_line_count(map()) :: non_neg_integer()
  defp get_buffer_line_count(state) do
    case get_in(state, [:buffer, :lines]) do
      lines when is_list(lines) -> length(lines)
      _ -> 0
    end
  end

  @spec sanitize_event_data(map()) :: map()
  defp sanitize_event_data(event_data) do
    # Remove potentially large or sensitive data from event logging
    event_data
    |> Map.drop([:raw_input, :large_payload])
    |> Enum.take(10) # Limit to first 10 keys
    |> Map.new()
  end

  @spec interactive_mode?() :: boolean()
  defp interactive_mode? do
    # Check if we're running in an interactive environment
    Code.ensure_loaded?(IEx) and IEx.started?()
  end
end