defmodule Raxol.Memory.Formatter do
  @moduledoc """
  Text, JSON, and Markdown output formatting for memory debug reports.
  """

  alias Raxol.Core.Runtime.Log
  alias Raxol.Utils.MemoryFormatter

  @doc "Formats and outputs a memory analysis report."
  def format_and_output_analysis(analysis, config) do
    case config.format do
      "json" -> output_json(analysis, config)
      "markdown" -> output_markdown_analysis(analysis, config)
      _ -> output_text_analysis(analysis, config)
    end
  end

  @doc "Formats and outputs a hotspot report."
  def format_and_output_hotspots(hotspots, config) do
    case config.format do
      "json" -> output_json(hotspots, config)
      "markdown" -> output_markdown_hotspots(hotspots, config)
      _ -> output_text_hotspots(hotspots, config)
    end
  end

  @doc "Formats and outputs a leak analysis report."
  def format_and_output_leaks(leak_analysis, config) do
    case config.format do
      "json" -> output_json(leak_analysis, config)
      "markdown" -> output_markdown_leaks(leak_analysis, config)
      _ -> output_text_leaks(leak_analysis, config)
    end
  end

  @doc "Formats and outputs an optimization report."
  def format_and_output_optimizations(optimizations, config) do
    case config.format do
      "json" -> output_json(optimizations, config)
      "markdown" -> output_markdown_optimizations(optimizations, config)
      _ -> output_text_optimizations(optimizations, config)
    end
  end

  # --- Private output functions ---

  defp output_text_analysis(analysis, config) do
    Mix.shell().info("\nMemory Analysis Report")
    Mix.shell().info(String.duplicate("=", 50))

    memory = analysis.memory_overview
    Mix.shell().info("\nMemory Overview:")
    Mix.shell().info("  Total: #{fmt(memory.total)}")

    Mix.shell().info(
      "  Processes: #{fmt(memory.processes)} (#{memory.breakdown.processes.percentage}%)"
    )

    Mix.shell().info(
      "  System: #{fmt(memory.system)} (#{memory.breakdown.system.percentage}%)"
    )

    Mix.shell().info(
      "  Binary: #{fmt(memory.binary)} (#{memory.breakdown.binary.percentage}%)"
    )

    Mix.shell().info("\nTop Memory Consuming Processes:")

    analysis.process_analysis.top_consumers
    |> Enum.take(5)
    |> Enum.each(fn proc ->
      Mix.shell().info("  #{proc.name}: #{fmt(proc.memory)}")
    end)

    if analysis.ets_analysis.top_consumers != [] do
      Mix.shell().info("\nLargest ETS Tables:")

      analysis.ets_analysis.top_consumers
      |> Enum.take(3)
      |> Enum.each(fn table ->
        Mix.shell().info(
          "  #{table.name}: #{fmt(table.memory)} (#{table.size} entries)"
        )
      end)
    end

    save_output_if_requested(analysis, config)
  end

  defp output_text_hotspots(hotspots, config) do
    Mix.shell().info("\nMemory Hotspots Report")
    Mix.shell().info(String.duplicate("=", 50))

    Mix.shell().info("\nTop Memory Consuming Processes:")

    hotspots.top_processes
    |> Enum.take(10)
    |> Enum.each(fn proc ->
      Mix.shell().info("  #{proc.name}: #{fmt(proc.memory)}")
    end)

    Mix.shell().info("\nBinary Memory Hotspots:")

    Enum.each(hotspots.binary_hotspots, fn hotspot ->
      Mix.shell().info(
        "  #{hotspot.process}: #{fmt(hotspot.binary_memory)} - #{hotspot.recommendation}"
      )
    end)

    save_output_if_requested(hotspots, config)
  end

  defp output_text_leaks(leak_analysis, config) do
    Mix.shell().info("\nMemory Leak Detection Report")
    Mix.shell().info(String.duplicate("=", 50))

    case leak_analysis.status do
      :insufficient_data ->
        Mix.shell().info("Insufficient data for leak analysis")

      :no_leaks ->
        Mix.shell().info("No memory leaks detected")

        Mix.shell().info(
          "Memory growth: #{fmt(leak_analysis.total_growth.memory_growth)}"
        )

      :leaks_detected ->
        Mix.shell().info("MEMORY LEAKS DETECTED!")

        Mix.shell().info(
          "Total memory growth: #{fmt(leak_analysis.total_growth.memory_growth)}"
        )

        Enum.each(leak_analysis.leak_indicators, fn indicator ->
          Mix.shell().info(
            "  #{indicator.type}: +#{indicator.growth} #{indicator.unit} (#{indicator.severity})"
          )
        end)

        Mix.shell().info("\nRecommendations:")

        Enum.each(leak_analysis.recommendations, fn rec ->
          Mix.shell().info("  - #{rec}")
        end)
    end

    save_output_if_requested(leak_analysis, config)
  end

  defp output_text_optimizations(optimizations, config) do
    Mix.shell().info("\nMemory Optimization Report")
    Mix.shell().info(String.duplicate("=", 50))

    Mix.shell().info("\nGeneral Recommendations:")

    Enum.each(optimizations.general_recommendations, fn rec ->
      Mix.shell().info("  - #{rec}")
    end)

    Mix.shell().info("\nBinary Optimizations:")

    Enum.each(optimizations.binary_optimizations.recommendations, fn rec ->
      Mix.shell().info("  - #{rec}")
    end)

    Mix.shell().info("\nProcess Optimizations:")

    Enum.each(optimizations.process_optimizations.recommendations, fn rec ->
      Mix.shell().info("  - #{rec}")
    end)

    save_output_if_requested(optimizations, config)
  end

  defp output_json(data, config) do
    json = Jason.encode!(data, pretty: true)
    Log.info(json)
    save_output_if_requested(data, config)
  end

  defp output_markdown_analysis(analysis, config) do
    markdown = """
    # Memory Analysis Report

    Generated: #{analysis.timestamp}

    ## Memory Overview

    - **Total**: #{fmt(analysis.memory_overview.total)}
    - **Processes**: #{fmt(analysis.memory_overview.processes)}
    - **System**: #{fmt(analysis.memory_overview.system)}
    - **Binary**: #{fmt(analysis.memory_overview.binary)}

    ## Top Processes

    #{format_processes_table(analysis.process_analysis.top_consumers)}
    """

    Log.info(markdown)
    save_output_if_requested(markdown, config)
  end

  defp output_markdown_hotspots(_hotspots, config) do
    Mix.shell().info("Markdown hotspots output not yet implemented")
    save_output_if_requested("", config)
  end

  defp output_markdown_leaks(_leak_analysis, config) do
    Mix.shell().info("Markdown leaks output not yet implemented")
    save_output_if_requested("", config)
  end

  defp output_markdown_optimizations(_optimizations, config) do
    Mix.shell().info("Markdown optimizations output not yet implemented")
    save_output_if_requested("", config)
  end

  defp format_processes_table(processes) do
    processes
    |> Enum.take(5)
    |> Enum.map_join("\n", fn proc ->
      "| #{proc.name} | #{fmt(proc.memory)} |"
    end)
  end

  defp save_output_if_requested(data, config) do
    if config.output do
      content =
        case config.format do
          "json" -> Jason.encode!(data, pretty: true)
          _ -> inspect(data, pretty: true)
        end

      File.write!(config.output, content)
      Mix.shell().info("Results saved to: #{config.output}")
    end
  end

  defp fmt(bytes), do: MemoryFormatter.format_memory(bytes)
end
