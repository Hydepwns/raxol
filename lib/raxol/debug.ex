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
  use Raxol.Core.Behaviours.BaseManager

  alias Raxol.Core.Utils.TimerManager
  alias Raxol.Core.Runtime.Log

  @debug_levels [:off, :basic, :detailed, :verbose]
  # Sample every 100ms in debug mode
  @performance_sample_rate 100

  # Type specifications
  @type debug_level :: :off | :basic | :detailed | :verbose
  @type debug_context :: %{
          module: module(),
          function: atom(),
          line: integer(),
          metadata: map()
        }

  ## Client API

  # BaseManager provides start_link/1
  # Usage: Raxol.Debug.start_link(name: __MODULE__, level: :basic)

  @doc """
  Enables debug mode at the specified level.
  """
  @spec enable(debug_level()) :: :ok
  def enable(level \\ :basic) when level in @debug_levels do
    GenServer.call(__MODULE__, {:set_level, level})
    configure_logger(level)
    :ok
  end

  @doc """
  Disables debug mode.
  """
  @spec disable() :: :ok
  def disable do
    enable(:off)
  end

  @doc """
  Check if debug mode is enabled for a specific component.
  """
  @spec debug_enabled?(atom()) :: boolean()
  def debug_enabled?(component \\ :terminal) do
    case get_debug_level() do
      :off -> false
      :basic -> component in [:terminal, :web]
      :detailed -> component in [:terminal, :web, :benchmark, :parser]
      :verbose -> true
    end
  end

  @doc """
  Gets current debug level.
  """
  @spec get_debug_level() :: debug_level()
  def get_debug_level do
    try do
      GenServer.call(__MODULE__, :get_level)
    catch
      :exit, _ -> :off
    end
  end

  @doc """
  Debug log that only outputs when debug mode is enabled.
  """
  @spec debug_log(binary() | atom(), any(), keyword()) :: :ok
  def debug_log(component, message, opts \\ []) when is_atom(component) do
    with true <- debug_enabled?(component),
         context <- Keyword.get(opts, :context, %{}),
         metadata <- Keyword.get(opts, :metadata, []),
         formatted_message <- format_debug_message(component, message, context) do
      Log.debug(formatted_message, metadata)
    end

    :ok
  end

  @doc """
  Time execution of a function and log the results if debug mode is enabled.
  """
  @spec time_debug(atom(), binary(), function()) :: any()
  def time_debug(component, operation, fun) when is_function(fun, 0) do
    case debug_enabled?(component) do
      true ->
        {time_us, result} = :timer.tc(fun)

        debug_log(component, "#{operation} completed in #{time_us}μs",
          metadata: [operation: operation, duration_us: time_us]
        )

        result

      false ->
        fun.()
    end
  end

  @doc """
  Log terminal state for debugging.
  """
  @spec log_terminal_state(map(), keyword()) :: :ok
  def log_terminal_state(state, opts \\ []) do
    with true <- debug_enabled?(:terminal),
         cursor_pos <- get_in(state, [:cursor, :position]) || {0, 0},
         dimensions <- get_in(state, [:dimensions]) || {80, 24},
         mode <- get_in(state, [:mode]) || :normal do
      debug_log(:terminal, "Terminal State",
        context: %{
          cursor_position: cursor_pos,
          dimensions: dimensions,
          mode: mode,
          buffer_lines: get_buffer_line_count(state),
          scroll_position: get_in(state, [:scroll, :position]) || 0
        },
        metadata: Keyword.get(opts, :metadata, [])
      )
    end

    :ok
  end

  @doc """
  Log ANSI sequence parsing for debugging.
  """
  @spec log_ansi_sequence(binary(), map(), keyword()) :: :ok
  def log_ansi_sequence(sequence, parsed_data, opts \\ []) do
    with true <- debug_enabled?(:parser) do
      debug_log(:parser, "ANSI Sequence Parsed",
        context: %{
          raw_sequence: inspect(sequence),
          sequence_type: parsed_data[:type],
          parameters: parsed_data[:params],
          final_char: parsed_data[:final],
          length: byte_size(sequence)
        },
        metadata: Keyword.get(opts, :metadata, [])
      )
    end

    :ok
  end

  @doc """
  Log event flow for debugging event handling.
  """
  @spec log_event_flow(atom(), map(), map(), keyword()) :: :ok
  def log_event_flow(event_type, event_data, handler_result, opts \\ []) do
    with true <- debug_enabled?(:terminal) do
      debug_log(:terminal, "Event Flow",
        context: %{
          event_type: event_type,
          event_data: sanitize_event_data(event_data),
          handler_result: inspect(handler_result),
          timestamp: System.monotonic_time(:millisecond)
        },
        metadata: Keyword.get(opts, :metadata, [])
      )
    end

    :ok
  end

  @doc """
  Log rendering performance metrics.
  """
  @spec log_render_metrics(map(), keyword()) :: :ok
  def log_render_metrics(metrics, opts \\ []) do
    with true <- debug_enabled?(:rendering) do
      debug_log(:rendering, "Render Metrics",
        context: %{
          frame_time_us: metrics[:frame_time_us],
          dirty_regions: length(metrics[:dirty_regions] || []),
          buffer_size: metrics[:buffer_size],
          operations_count: metrics[:operations_count],
          memory_usage: metrics[:memory_usage]
        },
        metadata: Keyword.get(opts, :metadata, [])
      )
    end

    :ok
  end

  @doc """
  Conditional breakpoint that only triggers in debug mode.
  Useful for interactive debugging.
  """
  @spec debug_breakpoint(atom(), binary()) :: :ok
  def debug_breakpoint(component, reason \\ "Debug breakpoint") do
    with true <- debug_enabled?(component),
         true <- interactive_mode?() do
      Log.console("Debug breakpoint hit: #{reason}")
      Log.console("Component: #{component}")
      Log.console("Process: #{inspect(self())}")
      Log.console("Press Enter to continue...")
      IO.read(:line)
    end

    :ok
  end

  @doc """
  Dump current process state for debugging.
  """
  @spec dump_process_state(atom()) :: :ok
  def dump_process_state(component) do
    with true <- debug_enabled?(component),
         process_info <- Process.info(self()) do
      debug_log(component, "Process State Dump",
        context: %{
          pid: inspect(self()),
          message_queue_len: process_info[:message_queue_len],
          memory: process_info[:memory],
          heap_size: process_info[:heap_size],
          stack_size: process_info[:stack_size],
          reductions: process_info[:reductions]
        }
      )
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

        Application.put_env(
          :raxol,
          :terminal,
          Keyword.put(terminal_config, :debug_mode, true)
        )

      :web ->
        web_config = Application.get_env(:raxol, :web, [])

        Application.put_env(
          :raxol,
          :web,
          Keyword.put(web_config, :debug_mode, true)
        )

      _ ->
        Application.put_env(:raxol, :debug_mode, true)
    end

    Log.info("Debug mode enabled for #{component}")
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

        Application.put_env(
          :raxol,
          :terminal,
          Keyword.put(terminal_config, :debug_mode, false)
        )

      :web ->
        web_config = Application.get_env(:raxol, :web, [])

        Application.put_env(
          :raxol,
          :web,
          Keyword.put(web_config, :debug_mode, false)
        )

      _ ->
        Application.put_env(:raxol, :debug_mode, false)
    end

    Log.info("Debug mode disabled for #{component}")
    :ok
  end

  @doc """
  Get current debug configuration.
  """
  @spec debug_config() :: %{
          terminal: boolean(),
          web: boolean(),
          benchmark: boolean(),
          parser: boolean(),
          rendering: boolean(),
          general: boolean(),
          log_level: Logger.level()
        }
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

  @spec format_debug_message(atom(), any(), map()) :: String.t()
  defp format_debug_message(component, message, context) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    context_str =
      case map_size(context) do
        0 -> ""
        _ -> " | Context: #{inspect(context)}"
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
    # Limit to first 10 keys
    |> Enum.take(10)
    |> Map.new()
  end

  @spec interactive_mode?() :: boolean()
  defp interactive_mode? do
    # Check if we're running in an interactive environment
    Code.ensure_loaded?(IEx) and Process.get(:iex_history) != nil
  end

  ## BaseManager Implementation

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    level = opts[:level] || :off

    state = %{
      level: level,
      logs: [],
      traces: [],
      profiles: %{},
      stats: %{
        log_count: 0,
        trace_count: 0,
        profile_count: 0,
        start_time: DateTime.utc_now()
      },
      max_logs: opts[:max_logs] || 10_000,
      max_traces: opts[:max_traces] || 5000
    }

    # Start performance monitoring if in debug mode
    _ =
      case level do
        :off -> nil
        _ -> schedule_performance_monitoring()
      end

    {:ok, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:set_level, level}, _from, state) do
    # Cancel existing monitoring if going to :off
    _ =
      case {level, state.level, state[:monitor_ref]} do
        {:off, old_level, ref} when old_level != :off and ref != nil ->
          TimerManager.cancel_timer(ref)

        _ ->
          nil
      end

    # Start monitoring if enabling debug
    _ =
      case {level, state.level} do
        {new_level, :off} when new_level != :off ->
          schedule_performance_monitoring()

        _ ->
          nil
      end

    {:reply, :ok, %{state | level: level}}
  end

  def handle_manager_call(:get_level, _from, state) do
    {:reply, state.level, state}
  end

  def handle_manager_call(:stats, _from, state) do
    stats = Map.put(state.stats, :current_level, state.level)
    {:reply, stats, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast({:log, level, message, context}, state) do
    log_entry = %{
      level: level,
      message: message,
      context: context,
      timestamp: DateTime.utc_now()
    }

    new_logs = [log_entry | state.logs] |> Enum.take(state.max_logs)
    new_stats = Map.update(state.stats, :log_count, 1, &(&1 + 1))

    {:noreply, %{state | logs: new_logs, stats: new_stats}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info(:monitor_performance, state) do
    case state.level do
      :off ->
        {:noreply, state}

      _ ->
        collect_performance_metrics(state)
        ref = schedule_performance_monitoring()
        {:noreply, Map.put(state, :monitor_ref, ref)}
    end
  end

  ## Private Helper Functions

  @spec schedule_performance_monitoring() :: reference()
  defp schedule_performance_monitoring do
    TimerManager.send_after(:monitor_performance, @performance_sample_rate)
  end

  @spec collect_performance_metrics(map()) :: :ok
  defp collect_performance_metrics(state) do
    case state.level do
      level when level in [:detailed, :verbose] ->
        memory = :erlang.memory()
        stats = :erlang.statistics(:run_queue)

        Log.debug(
          "Performance: memory=#{inspect(memory)}, run_queue=#{inspect(stats)}"
        )

      _ ->
        :ok
    end

    :ok
  end

  @spec configure_logger(debug_level()) :: :ok
  defp configure_logger(:off) do
    Logger.configure(level: :info)
  end

  defp configure_logger(:basic) do
    Logger.configure(level: :debug)
  end

  defp configure_logger(:detailed) do
    Logger.configure(level: :debug)
    # Note: Logger.configure_backend/2 is deprecated, use config files instead
    # This is for runtime configuration only
    :ok
  end

  defp configure_logger(:verbose) do
    Logger.configure(level: :debug)
    # Enable all metadata in verbose mode
    :ok
  end
end
