#!/usr/bin/env elixir

# Test script for native terminal mode with visualization components
# This script creates test data for dashboard widgets with visualization components
# and tests layout integration in native terminal mode

Mix.install([
  {:jason, "~> 1.4"}
])

# Ensure the Raxol application code is available
Code.prepend_path("_build/dev/lib/raxol/ebin")
Code.prepend_path("_build/dev/lib/raxol/consolidated")

# Compile the latest code if needed
if !File.exists?("_build/dev/lib/raxol/ebin") do
  IO.puts("Compiling Raxol application...")
  System.cmd("mix", ["compile"], cd: ".")
end

defmodule TerminalVisualizationTest do
  require Raxol.Core.Runtime.Log

  def run do
    IO.puts("\n=== Testing Visualization Components in Native Terminal ===\n")

    # Set environment variables for native terminal mode
    System.put_env("RAXOL_ENV", "dev")
    System.put_env("RAXOL_MODE", "native")

    # Create test chart data
    bar_chart_data = [
      %{label: "Jan", value: 12},
      %{label: "Feb", value: 19},
      %{label: "Mar", value: 3},
      %{label: "Apr", value: 7},
      %{label: "May", value: 15}
    ]

    # Create test treemap data
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

    # Create a sample dashboard layout with widgets
    widgets = [
      %{
        id: "chart1",
        type: :chart,
        title: "Monthly Sales",
        grid_spec: %{col: 0, row: 0, width: 4, height: 3},
        data: bar_chart_data,
        component_opts: %{
          type: :bar,
          title: "Monthly Sales"
        }
      },
      %{
        id: "treemap1",
        type: :treemap,
        title: "Project Breakdown",
        grid_spec: %{col: 4, row: 0, width: 4, height: 3},
        data: treemap_data,
        component_opts: %{
          title: "Project Breakdown"
        }
      },
      %{
        id: "info1",
        type: :info,
        title: "Information Widget",
        grid_spec: %{col: 0, row: 3, width: 8, height: 2},
        data: "This is an information widget",
        component_opts: %{}
      }
    ]

    # Save the test layout to file
    IO.puts("Saving test dashboard layout...")
    case Raxol.UI.Components.Dashboard.Dashboard.save_layout(widgets) do
      :ok -> IO.puts("Dashboard layout saved successfully")
      {:error, reason} -> IO.puts("Failed to save dashboard layout: #{inspect(reason)}")
    end

    IO.puts("\n=== Native Terminal Test Setup Complete ===\n")
    IO.puts("To run the full test in Native Terminal mode:")
    IO.puts("1. Exit this test script")
    IO.puts("2. Run: ./scripts/run_native_terminal.sh")
    IO.puts("3. Verify visualization components render properly")
    IO.puts("4. Test keyboard interaction and resizing")
    IO.puts("5. Use Ctrl+C to exit cleanly\n")

    IO.puts("Would you like to launch the native terminal application now? (y/n)")
    response = IO.gets("") |> String.trim() |> String.downcase()

    if response == "y" do
      IO.puts("\nLaunching native terminal application...")
      # Use :os.cmd to run the bash script
      {output, status} = System.cmd("./scripts/run_native_terminal.sh", [], into: IO.stream(:stdio, :line))
      IO.puts("Application exited with status: #{status}")
    else
      IO.puts("\nSkipping launch. Run ./scripts/run_native_terminal.sh manually to test.")
    end
  end
end

# Run the tests
TerminalVisualizationTest.run()
