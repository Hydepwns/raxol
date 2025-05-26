#!/usr/bin/env elixir

# This script tests the VisualizationPlugin rendering capabilities
# by directly calling the plugin's functions with test data

Mix.install([
  {:jason, "~> 1.4"}
])

# Ensure the Raxol application code is available
Code.prepend_path("_build/dev/lib/raxol/ebin")
Code.prepend_path("_build/dev/lib/raxol/consolidated")

# Compile the latest code
if !File.exists?("_build/dev/lib/raxol/ebin") do
  IO.puts("Compiling Raxol application...")
  System.cmd("mix", ["compile"], cd: ".")
end

defmodule VisualizationTest do
  require Raxol.Core.Runtime.Log

  def run do
    IO.puts("\n=== Testing VisualizationPlugin ===\n")

    # Initialize the plugin
    {:ok, plugin_state} = Raxol.Plugins.VisualizationPlugin.init()

    # Test data for bar chart
    bar_chart_data = [
      %{label: "Jan", value: 12},
      %{label: "Feb", value: 19},
      %{label: "Mar", value: 3},
      %{label: "Apr", value: 7},
      %{label: "May", value: 15}
    ]

    # Test data for treemap
    treemap_data = %{
      name: "Projects",
      value: 100,
      children: [
        %{
          name: "Frontend",
          value: 45,
          children: [
            %{name: "UI/UX", value: 20},
            %{name: "Components", value: 25}
          ]
        },
        %{
          name: "Backend",
          value: 55,
          children: [
            %{name: "API", value: 30},
            %{name: "Database", value: 15},
            %{name: "Infra", value: 10}
          ]
        }
      ]
    }

    # Create test bounds
    bounds = %{x: 0, y: 0, width: 80, height: 20}

    # Test chart cell creation
    chart_cell = %{
      type: :placeholder,
      value: :chart,
      data: bar_chart_data,
      opts: %{
        type: :bar,
        title: "Monthly Sales"
      },
      bounds: bounds
    }

    # Test treemap cell creation
    treemap_cell = %{
      type: :placeholder,
      value: :treemap,
      data: treemap_data,
      opts: %{
        title: "Project Breakdown"
      },
      bounds: bounds
    }

    # Call the plugin's handle_cells function with each test cell
    IO.puts("Testing bar chart rendering...")
    case Raxol.Plugins.VisualizationPlugin.handle_cells(chart_cell, %{}, plugin_state) do
      {:ok, _updated_state, chart_cells, _commands} ->
        IO.puts("Generated #{length(chart_cells)} cells for chart")
        print_sample_cells(chart_cells, 10)
      other ->
        IO.puts("Unexpected result: #{inspect(other)}")
    end

    IO.puts("\nTesting treemap rendering...")
    case Raxol.Plugins.VisualizationPlugin.handle_cells(treemap_cell, %{}, plugin_state) do
      {:ok, _updated_state, treemap_cells, _commands} ->
        IO.puts("Generated #{length(treemap_cells)} cells for treemap")
        print_sample_cells(treemap_cells, 10)
      other ->
        IO.puts("Unexpected result: #{inspect(other)}")
    end

    IO.puts("\n=== Visualization Tests Complete ===\n")
  end

  # Helper to print a sample of cells for verification
  defp print_sample_cells(cells, count) do
    IO.puts("Sample of cells (first #{min(count, length(cells))} of #{length(cells)}):")

    cells
    |> Enum.take(count)
    |> Enum.each(fn {x, y, cell} ->
      char = case cell.char do
        c when is_integer(c) -> <<c::utf8>>
        other -> inspect(other)
      end

      IO.puts("  Position: (#{x},#{y}) - Char: #{char}, FG: #{cell.fg}, BG: #{cell.bg}")
    end)
  end
end

# Run the tests
VisualizationTest.run()
