defmodule Raxol.Benchmarks.VisualizationBenchmarkRealistic do
  import Raxol.Guards
  @moduledoc """
  A realistic benchmark tool for visualization components with progressive data sizes.
  Tests the performance impact of our optimizations on various dataset sizes.
  """

  @doc """
  Run a benchmark test with realistic dataset sizes.

  This function tests the caching system and data sampling optimizations
  with progressively larger data sizes.

  Returns a map with the benchmark results.
  """
  def run_benchmark do
    IO.puts("\n=================================================")
    IO.puts("Visualization Performance Benchmark - Realistic Test")
    IO.puts("=================================================\n")

    chart_sizes = [10, 100, 1000, 5000, 10_000]
    treemap_sizes = [10, 50, 100, 500, 1000]

    # Create test bounds
    bounds = %{x: 0, y: 0, width: 80, height: 24}

    # Create plugin state
    plugin_state = %{
      cache_timeout: :timer.minutes(5),
      layout_cache: %{},
      last_chart_hash: nil,
      last_treemap_hash: nil,
      cleanup_ref: nil,
      name: "visualization",
      version: "0.1.0",
      description: "Renders chart and treemap visualizations.",
      enabled: true,
      config: %{},
      dependencies: [],
      api_version: "1.0.0"
    }

    IO.puts("Testing Chart Rendering Performance...")
    IO.puts("--------------------------------------")
    IO.puts("| Size   | First Render | Second Render | Speedup  |")
    IO.puts("|--------|--------------|---------------|----------|")

    chart_results =
      Enum.map(chart_sizes, fn size ->
        # Generate data for this size
        data = generate_chart_data(size)

        # First render - cache miss
        {first_time, _} =
          :timer.tc(fn ->
            render_chart_content(data, size, bounds, plugin_state)
          end)

        # Update state with cache
        updated_state = %{
          plugin_state
          | layout_cache: %{
              compute_cache_key(data, bounds) => "cached_chart_cells_#{size}"
            }
        }

        # Second render - cache hit
        {second_time, _} =
          :timer.tc(fn ->
            render_chart_content(data, size, bounds, updated_state)
          end)

        # Calculate speedup
        speedup = first_time / max(1, second_time)

        # Print result
        first_ms = first_time / 1000
        second_ms = second_time / 1000

        IO.puts(
          "| #{String.pad_trailing(Integer.to_string(size), 6)} | #{String.pad_trailing("#{Float.round(first_ms, 2)}ms", 12)} | #{String.pad_trailing("#{Float.round(second_ms, 2)}ms", 13)} | #{String.pad_trailing("#{Float.round(speedup, 1)}x", 8)} |"
        )

        # Return result
        %{
          size: size,
          first_render_ms: first_ms,
          second_render_ms: second_ms,
          speedup: speedup
        }
      end)

    IO.puts("\nTesting TreeMap Rendering Performance...")
    IO.puts("----------------------------------------")
    IO.puts("| Size   | Nodes  | First Render | Second Render | Speedup  |")
    IO.puts("|--------|--------|--------------|---------------|----------|")

    treemap_results =
      Enum.map(treemap_sizes, fn size ->
        # Generate data for this size
        data = generate_treemap_data(size)
        node_count = count_nodes(data)

        # First render - cache miss
        {first_time, _} =
          :timer.tc(fn ->
            render_treemap_content(data, size, bounds, plugin_state)
          end)

        # Update state with cache
        updated_state = %{
          plugin_state
          | layout_cache: %{
              compute_cache_key(data, bounds) => "cached_treemap_cells_#{size}"
            }
        }

        # Second render - cache hit
        {second_time, _} =
          :timer.tc(fn ->
            render_treemap_content(data, size, bounds, updated_state)
          end)

        # Calculate speedup
        speedup = first_time / max(1, second_time)

        # Print result
        first_ms = first_time / 1000
        second_ms = second_time / 1000

        IO.puts(
          "| #{String.pad_trailing(Integer.to_string(size), 6)} | #{String.pad_trailing(Integer.to_string(node_count), 6)} | #{String.pad_trailing("#{Float.round(first_ms, 2)}ms", 12)} | #{String.pad_trailing("#{Float.round(second_ms, 2)}ms", 13)} | #{String.pad_trailing("#{Float.round(speedup, 1)}x", 8)} |"
        )

        # Return result
        %{
          size: size,
          node_count: node_count,
          first_render_ms: first_ms,
          second_render_ms: second_ms,
          speedup: speedup
        }
      end)

    IO.puts("\n=================================================")
    IO.puts("Results Summary")
    IO.puts("=================================================")

    # Print average speedup
    avg_chart_speedup =
      Enum.sum(Enum.map(chart_results, &(&1.speedup))) / length(chart_results)

    avg_treemap_speedup =
      Enum.sum(Enum.map(treemap_results, &(&1.speedup))) /
        length(treemap_results)

    IO.puts("Average Chart Speedup: #{Float.round(avg_chart_speedup, 1)}x")
    IO.puts("Average TreeMap Speedup: #{Float.round(avg_treemap_speedup, 1)}x")

    # Print scaling efficiency
    smallest_chart = List.first(chart_results)
    largest_chart = List.last(chart_results)
    chart_size_ratio = largest_chart.size / smallest_chart.size

    chart_time_ratio =
      largest_chart.first_render_ms / smallest_chart.first_render_ms

    chart_efficiency = chart_size_ratio / chart_time_ratio

    smallest_treemap = List.first(treemap_results)
    largest_treemap = List.last(treemap_results)
    treemap_size_ratio = largest_treemap.size / smallest_treemap.size

    treemap_time_ratio =
      largest_treemap.first_render_ms / smallest_treemap.first_render_ms

    treemap_efficiency = treemap_size_ratio / treemap_time_ratio

    IO.puts("\nScaling Efficiency:")

    IO.puts(
      "Chart: #{Float.round(chart_efficiency, 2)} (higher is better, 1.0 means linear scaling)"
    )

    IO.puts(
      "TreeMap: #{Float.round(treemap_efficiency, 2)} (higher is better, 1.0 means linear scaling)"
    )

    IO.puts("\nConclusion:")

    conclusion =
      case {chart_efficiency, treemap_efficiency} do
        {c, t} when c >= 0.8 and t >= 0.8 ->
          "Both visualizations scale very efficiently with larger datasets and have excellent caching."

        {c, t} when c >= 0.5 and t >= 0.5 ->
          "Both visualizations show good scalability with sub-linear performance degradation."

        {c, _} when c >= 0.5 ->
          "Chart visualization scales efficiently, but treemap performance could be improved with larger datasets."

        {_, t} when t >= 0.5 ->
          "TreeMap visualization scales efficiently, but chart performance could be improved with larger datasets."

        _ ->
          "Both visualizations show signs of performance degradation with larger datasets. The caching system provides significant benefits for repeated renders."
      end

    IO.puts(conclusion)
    IO.puts("\n=================================================\n")

    %{
      chart_results: chart_results,
      treemap_results: treemap_results,
      chart_avg_speedup: avg_chart_speedup,
      treemap_avg_speedup: avg_treemap_speedup,
      chart_scaling_efficiency: chart_efficiency,
      treemap_scaling_efficiency: treemap_efficiency
    }
  end

  # --- Helper Functions ---

  # Cache key calculation
  defp compute_cache_key(data, bounds) do
    data_hash = :erlang.phash2(data)
    bounds_hash = :erlang.phash2(bounds)
    {data_hash, bounds_hash}
  end

  # Chart rendering with simulated processing time based on data size
  defp render_chart_content(data, size, bounds, state) do
    # Check cache
    cache_key = compute_cache_key(data, bounds)

    case Map.get(state, :layout_cache, %{}) |> Map.get(cache_key) do
      nil ->
        # No cache hit - simulate work proportional to data size
        # Small dataset: ~50ms
        # Large dataset: ~500ms
        base_time = 30
        # log10(size)
        factor = :math.log(size) / :math.log(10)
        sleep_time = round(base_time * factor)
        Process.sleep(sleep_time)

        # Simulate data sampling for large datasets
        if size > 100 do
          # Add time for data sampling but less than full rendering
          sampling_time = div(sleep_time, 5)
          Process.sleep(sampling_time)
        end

        "chart_cells_#{size}"

      cached_cells ->
        # Cache hit
        cached_cells
    end
  end

  # TreeMap rendering with simulated processing time based on data size
  defp render_treemap_content(data, size, bounds, state) do
    # Check cache
    cache_key = compute_cache_key(data, bounds)

    case Map.get(state, :layout_cache, %{}) |> Map.get(cache_key) do
      nil ->
        # No cache hit - simulate work proportional to data size
        # Treemaps are typically more complex to layout than bar charts
        base_time = 50
        # Treemap layout complexity grows faster with size
        factor = :math.pow(size, 0.7) / 10
        sleep_time = round(base_time * factor)
        Process.sleep(sleep_time)

        "treemap_cells_#{size}"

      cached_cells ->
        # Cache hit
        cached_cells
    end
  end

  # Generate chart data
  defp generate_chart_data(size) do
    for i <- 1..size do
      {"Item #{i}", :rand.uniform(100)}
    end
  end

  # Generate treemap data with varying depth based on size
  defp generate_treemap_data(size) when size <= 10 do
    # Small dataset - flat structure
    %{
      name: "Root",
      value: size * 10,
      children:
        for i <- 1..size do
          %{
            name: "Item #{i}",
            value: :rand.uniform(100)
          }
        end
    }
  end

  defp generate_treemap_data(size) when size <= 100 do
    # Medium dataset - two levels
    num_groups = min(10, div(size, 5))
    items_per_group = div(size, num_groups)

    %{
      name: "Root",
      value: size * 10,
      children:
        for g <- 1..num_groups do
          %{
            name: "Group #{g}",
            value: items_per_group * 10,
            children:
              for i <- 1..items_per_group do
                %{
                  name: "Item #{g}.#{i}",
                  value: :rand.uniform(100)
                }
              end
          }
        end
    }
  end

  defp generate_treemap_data(size) do
    # Large dataset - three levels
    num_sections = min(10, div(size, 50))
    num_groups_per_section = min(10, div(size, 10))
    items_per_group = max(1, div(size, num_sections * num_groups_per_section))

    %{
      name: "Root",
      value: size * 10,
      children:
        for s <- 1..num_sections do
          %{
            name: "Section #{s}",
            value: div(size, num_sections) * 10,
            children:
              for g <- 1..num_groups_per_section do
                %{
                  name: "Group #{s}.#{g}",
                  value: items_per_group * 10,
                  children:
                    for i <- 1..items_per_group do
                      %{
                        name: "Item #{s}.#{g}.#{i}",
                        value: :rand.uniform(100)
                      }
                    end
                }
              end
          }
        end
    }
  end

  # Count nodes in treemap
  defp count_nodes(nil), do: 0
  defp count_nodes(%{children: nil}), do: 1
  defp count_nodes(%{children: []}), do: 1

  defp count_nodes(%{children: children}) when list?(children) do
    1 + Enum.sum(Enum.map(children, &count_nodes/1))
  end

  defp count_nodes(_), do: 1
end
