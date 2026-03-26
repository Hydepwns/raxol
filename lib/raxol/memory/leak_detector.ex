defmodule Raxol.Memory.LeakDetector do
  @moduledoc """
  Memory leak detection and trend analysis.

  Monitors memory growth over a configured duration and identifies
  potential leaks in memory, processes, ETS tables, and ports.
  """

  alias Raxol.Memory.Collector

  @doc "Monitors memory for `duration` seconds and returns measurements."
  def monitor_memory_growth(duration, initial_state) do
    monitor_loop(
      duration,
      initial_state,
      [],
      System.monotonic_time(:millisecond)
    )
  end

  @doc "Analyzes measurements for potential leaks."
  def analyze_potential_leaks(_initial_state, measurements, config) do
    if length(measurements) < 2 do
      %{
        status: :insufficient_data,
        message: "Not enough data for leak analysis"
      }
    else
      final_measurement = List.last(measurements)
      total_growth = final_measurement.growth

      leak_indicators =
        []
        |> check_memory_growth(total_growth, config)
        |> check_process_growth(total_growth)
        |> check_ets_growth(total_growth)

      trend_analysis = analyze_growth_trend(measurements)

      %{
        status: if(leak_indicators != [], do: :leaks_detected, else: :no_leaks),
        monitoring_duration: config.monitoring_duration,
        total_growth: total_growth,
        leak_indicators: leak_indicators,
        trend_analysis: trend_analysis,
        recommendations: generate_leak_recommendations(leak_indicators)
      }
    end
  end

  # --- Private ---

  defp monitor_loop(duration, initial_state, measurements, start_time) do
    current_time = System.monotonic_time(:millisecond)
    elapsed = (current_time - start_time) / 1000

    if elapsed < duration do
      state = Collector.capture_memory_state()

      measurement = %{
        elapsed: elapsed,
        state: state,
        growth: calculate_growth(initial_state, state)
      }

      updated_measurements = [measurement | measurements]

      if rem(trunc(elapsed), 30) == 0 and elapsed > 0 do
        Mix.shell().info(
          "Monitoring... #{trunc(elapsed)}s elapsed, Memory: #{format_memory(state.memory[:total])}"
        )
      end

      Process.sleep(5000)
      monitor_loop(duration, initial_state, updated_measurements, start_time)
    else
      Enum.reverse(measurements)
    end
  end

  defp calculate_growth(initial, current) do
    %{
      memory_growth: current.memory[:total] - initial.memory[:total],
      process_growth: current.process_count - initial.process_count,
      ets_growth: current.ets_count - initial.ets_count,
      port_growth: current.port_count - initial.port_count
    }
  end

  defp check_memory_growth(indicators, total_growth, config) do
    memory_growth_mb = total_growth.memory_growth / 1_000_000

    if memory_growth_mb > config.threshold * 2 do
      [
        %{
          type: :memory_leak,
          severity: :high,
          growth: memory_growth_mb,
          unit: "MB"
        }
        | indicators
      ]
    else
      indicators
    end
  end

  defp check_process_growth(indicators, total_growth) do
    if total_growth.process_growth > 10 do
      [
        %{
          type: :process_leak,
          severity: :medium,
          growth: total_growth.process_growth,
          unit: "processes"
        }
        | indicators
      ]
    else
      indicators
    end
  end

  defp check_ets_growth(indicators, total_growth) do
    if total_growth.ets_growth > 5 do
      [
        %{
          type: :ets_leak,
          severity: :medium,
          growth: total_growth.ets_growth,
          unit: "tables"
        }
        | indicators
      ]
    else
      indicators
    end
  end

  defp analyze_growth_trend(measurements) do
    growth_rates =
      measurements
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev, curr] ->
        curr.growth.memory_growth - prev.growth.memory_growth
      end)

    avg_growth_rate =
      if growth_rates != [] do
        Enum.sum(growth_rates) / length(growth_rates)
      else
        0
      end

    %{
      trend: determine_trend(growth_rates),
      average_growth_rate: avg_growth_rate,
      stability: calculate_stability(growth_rates)
    }
  end

  defp determine_trend(growth_rates) do
    if length(growth_rates) < 3 do
      :unknown
    else
      recent = Enum.take(growth_rates, -3)
      if Enum.all?(recent, &(&1 > 0)), do: :increasing, else: :stable
    end
  end

  defp calculate_stability(growth_rates) do
    if length(growth_rates) < 2 do
      :unknown
    else
      variance = calculate_variance(growth_rates)
      if variance < 1000, do: :stable, else: :unstable
    end
  end

  defp calculate_variance(values) do
    mean = Enum.sum(values) / length(values)
    sum_squares = Enum.sum(Enum.map(values, &:math.pow(&1 - mean, 2)))
    sum_squares / length(values)
  end

  defp generate_leak_recommendations(leak_indicators) do
    leak_indicators
    |> Enum.flat_map(&get_recommendations_for_leak_type/1)
    |> Enum.uniq()
  end

  defp get_recommendations_for_leak_type(%{type: :memory_leak}) do
    [
      "Monitor process memory growth over time",
      "Check for large binary accumulation",
      "Review ETS table usage patterns",
      "Ensure proper cleanup of resources"
    ]
  end

  defp get_recommendations_for_leak_type(%{type: :process_leak}) do
    [
      "Review process spawning patterns",
      "Ensure processes are properly terminated",
      "Check for supervisor restart loops",
      "Monitor GenServer lifecycle"
    ]
  end

  defp get_recommendations_for_leak_type(%{type: :ets_leak}) do
    [
      "Review ETS table creation and deletion",
      "Ensure tables are properly cleaned up",
      "Check for orphaned ETS tables",
      "Monitor table ownership transfers"
    ]
  end

  defp format_memory(bytes) do
    Raxol.Utils.MemoryFormatter.format_memory(bytes)
  end
end
