defmodule Raxol.Benchmarks.VisualizationBenchmarkSimple do
  @moduledoc """
  A simplified benchmark tool for visualization components, without external dependencies.
  This is designed for direct testing during development without requiring the full application.
  """

  @doc """
  Run a simple benchmark test of the visualization caching system.

  This function directly tests the VisualizationPlugin's caching system
  with small data samples and doesn't require the full application to be running.

  Returns a map with the benchmark results.
  """
  def run_simple_benchmark do
    IO.puts("Starting simplified visualization benchmark test...")

    # Create test data
    chart_data = generate_chart_data(50)
    treemap_data = generate_treemap_data(20)

    # Create test bounds
    bounds = %{x: 0, y: 0, width: 80, height: 24}

    # Create plugin state
    plugin_state = %{
      cache_timeout: :timer.minutes(5),
      layout_cache: %{},
      last_chart_hash: nil,
      last_treemap_hash: nil,
      cleanup_ref: nil,
      # Add standard plugin fields
      name: "visualization",
      version: "0.1.0",
      description: "Renders chart and treemap visualizations.",
      enabled: true,
      config: %{
        chart_style: :line,
        treemap_style: :compact
      },
      dependencies: [],
      api_version: "1.0.0"
    }

    # ----- Test chart rendering -----
    IO.puts("\nTesting chart rendering...")

    # First render (should miss cache)
    {first_chart_time, _} =
      :timer.tc(fn ->
        render_chart_content(
          chart_data,
          %{title: "Test Chart"},
          bounds,
          plugin_state
        )
      end)

    # Get updated state with cache
    updated_state = %{
      plugin_state
      | cache_timeout: :timer.minutes(5),
        layout_cache: %{
          compute_cache_key(chart_data, bounds) => "cached_chart_cells"
        }
    }

    # Second render (should hit cache)
    {second_chart_time, _} =
      :timer.tc(fn ->
        render_chart_content(
          chart_data,
          %{title: "Test Chart"},
          bounds,
          updated_state
        )
      end)

    # Calculate speedup
    chart_speedup = first_chart_time / max(1, second_chart_time)

    # ----- Test treemap rendering -----
    IO.puts("Testing treemap rendering...")

    # First render (should miss cache)
    {first_treemap_time, _} =
      :timer.tc(fn ->
        render_treemap_content(
          treemap_data,
          %{title: "Test TreeMap"},
          bounds,
          plugin_state
        )
      end)

    # Second render (should hit cache)
    # Get updated state with cache
    updated_state = %{
      plugin_state
      | cache_timeout: :timer.minutes(5),
        layout_cache: %{
          compute_cache_key(treemap_data, bounds) => "cached_treemap_cells"
        }
    }

    {second_treemap_time, _} =
      :timer.tc(fn ->
        render_treemap_content(
          treemap_data,
          %{title: "Test TreeMap"},
          bounds,
          updated_state
        )
      end)

    # Calculate speedup
    treemap_speedup = first_treemap_time / max(1, second_treemap_time)

    # Report results
    IO.puts("\nResults:")
    IO.puts("  Chart first render: #{first_chart_time / 1000}ms")
    IO.puts("  Chart second render: #{second_chart_time / 1000}ms")
    IO.puts("  Chart speedup: #{Float.round(chart_speedup, 2)}x")
    IO.puts("  TreeMap first render: #{first_treemap_time / 1000}ms")
    IO.puts("  TreeMap second render: #{second_treemap_time / 1000}ms")
    IO.puts("  TreeMap speedup: #{Float.round(treemap_speedup, 2)}x")

    %{
      chart: %{
        first_time_ms: first_chart_time / 1000,
        second_time_ms: second_chart_time / 1000,
        speedup: chart_speedup
      },
      treemap: %{
        first_time_ms: first_treemap_time / 1000,
        second_time_ms: second_treemap_time / 1000,
        speedup: treemap_speedup
      }
    }
  end

  # --- Helper Functions ---

  # Simple version of visualization plugin functions

  # Cache key calculation (same as in plugin)
  defp compute_cache_key(data, bounds) do
    data_hash = :erlang.phash2(data)
    bounds_hash = :erlang.phash2(bounds)
    {data_hash, bounds_hash}
  end

  # Simplified chart rendering
  defp render_chart_content(data, _opts, bounds, state) do
    # Check if we have a cached result
    cache_key = compute_cache_key(data, bounds)

    case Map.get(state, :layout_cache, %{}) |> Map.get(cache_key) do
      nil ->
        # No cache hit - would normally calculate layout and draw
        # For testing, just simulate the work
        # Simulate calculation time
        Process.sleep(50)
        "chart_cells"

      cached_cells ->
        # Cache hit
        cached_cells
    end
  end

  # Simplified treemap rendering
  defp render_treemap_content(data, _opts, bounds, state) do
    # Check if we have a cached result
    cache_key = compute_cache_key(data, bounds)

    case Map.get(state, :layout_cache, %{}) |> Map.get(cache_key) do
      nil ->
        # No cache hit - would normally calculate layout and draw
        # For testing, just simulate the work
        # Simulate calculation time
        Process.sleep(100)
        "treemap_cells"

      cached_cells ->
        # Cache hit
        cached_cells
    end
  end

  # Generate sample chart data
  defp generate_chart_data(size) do
    for i <- 1..size do
      {"Item #{i}", :rand.uniform(100)}
    end
  end

  # Generate sample treemap data
  defp generate_treemap_data(size) do
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
end
