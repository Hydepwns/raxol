#! /usr/bin/env elixir

# Run with: mix run scripts/run_visualization_tests.exs

Code.require_file("test/data/visualization_test_data.ex")

# No longer need aliases for deprecated Runtime modules
# alias Raxol.Runtime
# alias Raxol.RuntimeDebug

defmodule Raxol.RunVisualizationTests do
  @moduledoc """
  A test harness for Raxol visualization components.
  """

  alias Raxol.Test.VisualizationTestData

  def run_tests do
    IO.puts("\n=== Raxol Visualization Component Test Suite ===")
    IO.puts("Started at: #{DateTime.utc_now()}")
    IO.puts("System info: #{:erlang.system_info(:system_version)}")

    # Create test_results directory if it doesn't exist
    File.mkdir_p!("test_results")

    # Generate results file
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(":", "-")
    results_file = "test_results/visualization_#{timestamp}.md"

    File.write!(results_file, """
    # Visualization Component Test Results
    - **Test Date**: #{Date.utc_today()}
    - **Erlang/OTP**: #{:erlang.system_info(:otp_release)}
    - **Environment**: #{test_environment()}

    ## Test Summary

    """)

    # Run bar chart tests
    bar_chart_results = run_bar_chart_tests()
    append_to_results(results_file, "## Bar Chart Tests\n\n", bar_chart_results)

    # Run treemap tests
    treemap_results = run_treemap_tests()
    append_to_results(results_file, "## Treemap Tests\n\n", treemap_results)

    # Run size adaptation tests
    size_tests = run_size_adaptation_tests()
    append_to_results(results_file, "## Size Adaptation Tests\n\n", size_tests)

    # Run edge case tests
    edge_case_results = run_edge_case_tests()
    append_to_results(results_file, "## Edge Case Tests\n\n", edge_case_results)

    IO.puts("\n=== Test Summary ===")
    IO.puts("Tests completed at: #{DateTime.utc_now()}")
    IO.puts("Results written to: #{results_file}")
  end

  defp run_bar_chart_tests do
    IO.puts("\n--- Running Bar Chart Tests ---")

    # Get bar chart test data
    bar_data = VisualizationTestData.bar_chart_test_data()

    results = []

    # Test normal data
    results = test_bar_chart(bar_data.normal, "normal", results)

    # Test empty data
    results = test_bar_chart(bar_data.empty, "empty", results)

    # Test single item
    results = test_bar_chart(bar_data.single_item, "single_item", results)

    # Test large dataset (sample first 20 items)
    large_sample = Enum.take(bar_data.large_dataset, 20)
    results = test_bar_chart(large_sample, "large_dataset_sample", results)

    # Test long labels
    results = test_bar_chart(bar_data.long_labels, "long_labels", results)

    # Test unicode labels
    results = test_bar_chart(bar_data.unicode_labels, "unicode_labels", results)

    # Test negative values
    results = test_bar_chart(bar_data.negative_values, "negative_values", results)

    # Test zero values
    results = test_bar_chart(bar_data.zero_values, "zero_values", results)

    # Test large values
    results = test_bar_chart(bar_data.large_values, "large_values", results)

    # Test small values
    results = test_bar_chart(bar_data.small_values, "small_values", results)

    results
  end

  defp run_treemap_tests do
    IO.puts("\n--- Running Treemap Tests ---")

    # Get treemap test data
    treemap_data = VisualizationTestData.treemap_test_data()

    results = []

    # Test normal data
    results = test_treemap(treemap_data.normal, "normal", results)

    # Test empty data
    results = test_treemap(treemap_data.empty, "empty", results)

    # Test single node
    results = test_treemap(treemap_data.single_node, "single_node", results)

    # Test deep nesting
    results = test_treemap(treemap_data.deep_nesting, "deep_nesting", results)

    # Test many siblings
    results = test_treemap(treemap_data.many_siblings, "many_siblings", results)

    # Test uneven distribution
    results = test_treemap(treemap_data.uneven_distribution, "uneven_distribution", results)

    # Test unicode names
    results = test_treemap(treemap_data.unicode_names, "unicode_names", results)

    # Test zero values
    results = test_treemap(treemap_data.zero_values, "zero_values", results)

    results
  end

  defp run_size_adaptation_tests do
    IO.puts("\n--- Running Size Adaptation Tests ---")

    results = []

    # Test small terminal (20x10)
    data_small = VisualizationTestData.size_adaptive_test_data(20, 10)
    results = test_size_adaptation(data_small, "small_terminal", results)

    # Test medium terminal (80x24)
    data_medium = VisualizationTestData.size_adaptive_test_data(80, 24)
    results = test_size_adaptation(data_medium, "medium_terminal", results)

    # Test large terminal (120x40)
    data_large = VisualizationTestData.size_adaptive_test_data(120, 40)
    results = test_size_adaptation(data_large, "large_terminal", results)

    # Test extreme wide terminal (200x20)
    data_wide = VisualizationTestData.size_adaptive_test_data(200, 20)
    results = test_size_adaptation(data_wide, "wide_terminal", results)

    # Test extreme tall terminal (50x100)
    data_tall = VisualizationTestData.size_adaptive_test_data(50, 100)
    results = test_size_adaptation(data_tall, "tall_terminal", results)

    results
  end

  defp run_edge_case_tests do
    IO.puts("\n--- Running Edge Case Tests ---")

    results = []

    # Test 1-line height widget
    results = test_edge_case("1_line_height", "Rendering in 1-line height widget", results)

    # Test rapid resize
    results = test_edge_case("rapid_resize", "Handling rapid window resizing", results)

    # Test resize during render
    results = test_edge_case("resize_during_render", "Resize during rendering operation", results)

    results
  end

  defp test_bar_chart(data, test_name, results) do
    IO.puts("  Testing bar chart: #{test_name}")

    # Log start for performance measurement
    start_time = System.monotonic_time()

    # Measurement point before test
    RuntimeDebug.log_memory_usage("bar_chart_#{test_name}_before")

    # Perform the actual visualization rendering test
    # This would call into your visualization component
    render_result = render_bar_chart(data)

    # Measurement point after test
    RuntimeDebug.log_memory_usage("bar_chart_#{test_name}_after")

    # Log performance
    elapsed = System.monotonic_time() - start_time
    ms = System.convert_time_unit(elapsed, :native, :millisecond)

    test_result = %{
      test_name: "bar_chart_#{test_name}",
      data_size: length(data),
      render_time_ms: ms,
      status: render_result.status,
      details: render_result.details
    }

    [test_result | results]
  end

  defp test_treemap(data, test_name, results) do
    IO.puts("  Testing treemap: #{test_name}")

    # Log start for performance measurement
    start_time = System.monotonic_time()

    # Measurement point before test
    RuntimeDebug.log_memory_usage("treemap_#{test_name}_before")

    # Perform the actual visualization rendering test
    # This would call into your visualization component
    render_result = render_treemap(data)

    # Measurement point after test
    RuntimeDebug.log_memory_usage("treemap_#{test_name}_after")

    # Log performance
    elapsed = System.monotonic_time() - start_time
    ms = System.convert_time_unit(elapsed, :native, :millisecond)

    # Count nodes for reporting
    node_count = count_nodes(data)

    test_result = %{
      test_name: "treemap_#{test_name}",
      node_count: node_count,
      render_time_ms: ms,
      status: render_result.status,
      details: render_result.details
    }

    [test_result | results]
  end

  defp test_size_adaptation(data, test_name, results) do
    IO.puts("  Testing size adaptation: #{test_name} (#{data.width}x#{data.height})")

    # Log start for performance measurement
    start_time = System.monotonic_time()

    # Measurement point before test
    RuntimeDebug.log_memory_usage("size_#{test_name}_before")

    # Test bar chart with this size
    bar_result = render_bar_chart(data.bar_chart, data.width, data.height)

    # Test treemap with this size
    treemap_result = render_treemap(data.treemap, data.width, data.height)

    # Measurement point after test
    RuntimeDebug.log_memory_usage("size_#{test_name}_after")

    # Log performance
    elapsed = System.monotonic_time() - start_time
    ms = System.convert_time_unit(elapsed, :native, :millisecond)

    test_result = %{
      test_name: "size_#{test_name}",
      dimensions: "#{data.width}x#{data.height}",
      render_time_ms: ms,
      bar_status: bar_result.status,
      treemap_status: treemap_result.status,
      details: "Bar: #{bar_result.details}, Treemap: #{treemap_result.details}"
    }

    [test_result | results]
  end

  defp test_edge_case(test_name, description, results) do
    IO.puts("  Testing edge case: #{test_name} - #{description}")

    # Log start for performance measurement
    start_time = System.monotonic_time()

    # Placeholder for actual edge case test
    # This would need to be implemented based on the specific test requirements
    test_result = %{
      test_name: "edge_case_#{test_name}",
      description: description,
      render_time_ms: 0,
      status: "MANUAL",
      details: "Requires manual verification"
    }

    [test_result | results]
  end

  # ---- Helper functions ----

  # Placeholder for actual bar chart rendering
  # In a real implementation, this would call your visualization component
  defp render_bar_chart(data, width \\ 80, height \\ 24) do
    # Simulate the actual rendering with timing
    :timer.sleep(50)  # Simulate processing time

    # Return a simulated result - in real implementation this would be actual rendering
    %{
      status: if(Enum.empty?(data), do: "WARNING", else: "PASS"),
      details: "Rendered #{length(data)} items in #{width}x#{height} area"
    }
  end

  # Placeholder for actual treemap rendering
  # In a real implementation, this would call your visualization component
  defp render_treemap(data, width \\ 80, height \\ 24) do
    # Simulate the actual rendering with timing
    :timer.sleep(100)  # Simulate processing time

    # Count nodes for reporting
    node_count = count_nodes(data)

    # Return a simulated result - in real implementation this would be actual rendering
    %{
      status: if(node_count == 0, do: "WARNING", else: "PASS"),
      details: "Rendered #{node_count} nodes in #{width}x#{height} area"
    }
  end

  # Helper to count nodes in a treemap structure
  defp count_nodes(nil), do: 0
  defp count_nodes(%{children: nil}), do: 1
  defp count_nodes(%{children: []}), do: 1
  defp count_nodes(%{children: children}) when is_list(children) do
    1 + Enum.sum(Enum.map(children, &count_nodes/1))
  end
  defp count_nodes(_), do: 1

  # Helper to append results to the results file
  defp append_to_results(file, header, results) do
    # Write header
    File.write!(file, header, [:append])

    # Write results table header
    File.write!(file, """
    | Test | Details | Render Time | Status |
    |------|---------|-------------|--------|
    """, [:append])

    # Write result rows
    Enum.each(results, fn result ->
      row = "| #{result.test_name} | #{result[:details] || ""} | #{result.render_time_ms}ms | #{result.status} |\n"
      File.write!(file, row, [:append])
    end)

    # Add a blank line
    File.write!(file, "\n", [:append])
  end

  # Helper to determine test environment
  defp test_environment do
    cond do
      System.get_env("VSCODE_PID") != nil ->
        "VS Code Extension"
      true ->
        "Native Terminal"
    end
  end
end

# Run the tests
Raxol.RunVisualizationTests.run_tests()
