#!/usr/bin/env elixir

# Test script for VS Code extension mode with visualization components
# This script creates test data for dashboard widgets with visualization components
# and tests layout integration

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

defmodule VSCodeVisualizationTest do
  require Logger

  def run do
    IO.puts("\n=== Testing Visualization Components in Dashboard Layout ===\n")

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

    # Grid configuration for the dashboard
    grid_config = %{
      parent_bounds: %{x: 0, y: 0, width: 80, height: 24},
      cols: 8,
      rows: 6,
      gap: 1
    }

    # Initialize the dashboard model
    {:ok, dashboard_model} = Raxol.UI.Components.Dashboard.Dashboard.init(widgets, grid_config)

    # Save the test layout to file
    IO.puts("Saving test dashboard layout...")
    case Raxol.UI.Components.Dashboard.Dashboard.save_layout(widgets) do
      :ok -> IO.puts("Dashboard layout saved successfully")
      {:error, reason} -> IO.puts("Failed to save dashboard layout: #{inspect(reason)}")
    end

    # Test loading the dashboard layout
    IO.puts("\nLoading dashboard layout...")
    loaded_widgets = Raxol.UI.Components.Dashboard.Dashboard.load_layout()
    IO.puts("Loaded #{length(loaded_widgets)} widgets")

    # Render the dashboard with the test model
    IO.puts("\nRendering dashboard with visualization widgets...")
    props = %{
      dashboard_model: dashboard_model,
      grid_config: grid_config,
      app_text: "Sample app text"
    }

    # Call dashboard render function
    widget_views = Raxol.UI.Components.Dashboard.Dashboard.render(props)
    IO.puts("Dashboard rendered with #{length(widget_views)} widget views")

    # Display visualization widget configurations
    IO.puts("\nVisualization Widget Configurations:")
    Enum.each(widget_views, fn view ->
      case view do
        %{widget_config: widget_config} when is_map(widget_config) ->
          if widget_config.type in [:chart, :treemap] do
            IO.puts("  #{widget_config.type} Widget:")
            IO.puts("    ID: #{widget_config.id}")
            IO.puts("    Title: #{widget_config.title}")
            IO.puts("    Bounds: #{inspect(widget_config.bounds)}")
            IO.puts("")
          end
        _ -> nil
      end
    end)

    IO.puts("\n=== VS Code Visualization Integration Test Complete ===\n")
    IO.puts("To run the full test in VS Code Extension mode:")
    IO.puts("1. Open the VS Code Debug panel")
    IO.puts("2. Select 'Extension' from the dropdown")
    IO.puts("3. Press the play button to launch")
    IO.puts("4. Use the command palette and run 'Raxol: Show Terminal'")
    IO.puts("5. Verify visualization components render properly\n")
  end
end

# Run the tests
VSCodeVisualizationTest.run()
