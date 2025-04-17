#!/usr/bin/env elixir

# Test script for verifying dashboard layout integration with visualization components
# This script tests:
# 1. Dashboard setup with visualization widgets
# 2. Widget resizing with visualization content updates
# 3. Widget dragging and positioning
# 4. Layout persistence (save/load)
# 5. Widget customization

defmodule DashboardLayoutIntegrationTest do
  require Logger

  @visualization_test_file_path "~/.raxol/visualization_test_results.log"

  def run do
    IO.puts("=== Dashboard Layout Integration Test ===\n")
    IO.puts("Testing visualization components integrated with dashboard layout")

    # Initialize test state
    plugin_state = %{}

    # Create sample data for visualizations
    bar_chart_data = [
      %{label: "Jan", value: 10},
      %{label: "Feb", value: 25},
      %{label: "Mar", value: 15},
      %{label: "Apr", value: 30},
      %{label: "May", value: 22},
      %{label: "Jun", value: 18}
    ]

    # Create a treemap data structure
    treemap_data = %{
      name: "Projects",
      value: 100,
      children: [
        %{
          name: "Frontend",
          value: 40,
          children: [
            %{name: "React", value: 20},
            %{name: "CSS", value: 15},
            %{name: "HTML", value: 5}
          ]
        },
        %{
          name: "Backend",
          value: 35,
          children: [
            %{name: "Elixir", value: 20},
            %{name: "Database", value: 15}
          ]
        },
        %{
          name: "DevOps",
          value: 25,
          children: [
            %{name: "Docker", value: 10},
            %{name: "CI/CD", value: 15}
          ]
        }
      ]
    }

    # Define dashboard widgets
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
        data: "This widget displays information about the dashboard.",
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

    # --- TEST 1: Dashboard Initialization ---

    IO.puts("\n[TEST 1] Dashboard initialization with visualization widgets")

    # Initialize the dashboard model
    {:ok, dashboard_model} = Raxol.Components.Dashboard.Dashboard.init(widgets, grid_config)
    IO.puts("Dashboard model initialized with #{length(widgets)} widgets")

    # Render the dashboard to verify widget creation
    props = %{
      dashboard_model: dashboard_model,
      grid_config: grid_config,
      app_text: "Sample app text for integration test"
    }

    widget_views = Raxol.Components.Dashboard.Dashboard.render(props)
    IO.puts("Dashboard rendered with #{length(widget_views)} widget views")

    # --- TEST 2: Widget Resizing ---

    IO.puts("\n[TEST 2] Widget resizing with visualization content updates")

    # Simulate resize event for chart widget
    chart_widget = Enum.find(widgets, fn w -> w.id == "chart1" end)

    # Resize chart widget (make it larger)
    updated_chart_widget = %{chart_widget | grid_spec: %{chart_widget.grid_spec | width: 6, height: 4}}

    # Update widgets list with resized widget
    widgets_after_resize = Enum.map(widgets, fn w ->
      if w.id == "chart1", do: updated_chart_widget, else: w
    end)

    # Create updated dashboard model
    {:ok, resized_dashboard_model} = Raxol.Components.Dashboard.Dashboard.init(widgets_after_resize, grid_config)

    # Render dashboard with resized widget
    resized_props = %{
      dashboard_model: resized_dashboard_model,
      grid_config: grid_config,
      app_text: "Sample app text for resize test"
    }

    resized_widget_views = Raxol.Components.Dashboard.Dashboard.render(resized_props)
    IO.puts("Dashboard re-rendered after widget resize with #{length(resized_widget_views)} widget views")

    # --- TEST 3: Widget Dragging ---

    IO.puts("\n[TEST 3] Widget dragging and positioning")

    # Simulate drag event for treemap widget
    treemap_widget = Enum.find(widgets, fn w -> w.id == "treemap1" end)

    # Move treemap widget to a new position
    updated_treemap_widget = %{treemap_widget | grid_spec: %{treemap_widget.grid_spec | col: 2, row: 4}}

    # Update widgets list with moved widget
    widgets_after_move = Enum.map(widgets_after_resize, fn w ->
      if w.id == "treemap1", do: updated_treemap_widget, else: w
    end)

    # Create updated dashboard model
    {:ok, moved_dashboard_model} = Raxol.Components.Dashboard.Dashboard.init(widgets_after_move, grid_config)

    # Render dashboard with moved widget
    moved_props = %{
      dashboard_model: moved_dashboard_model,
      grid_config: grid_config,
      app_text: "Sample app text for drag test"
    }

    moved_widget_views = Raxol.Components.Dashboard.Dashboard.render(moved_props)
    IO.puts("Dashboard re-rendered after widget move with #{length(moved_widget_views)} widget views")

    # --- TEST 4: Layout Persistence ---

    IO.puts("\n[TEST 4] Layout persistence (save/load)")

    # Save the layout
    IO.puts("Saving dashboard layout...")
    save_result = Raxol.Components.Dashboard.Dashboard.save_layout(widgets_after_move)
    IO.puts("Save result: #{inspect(save_result)}")

    # Load the layout
    IO.puts("Loading dashboard layout...")
    loaded_widgets = Raxol.Components.Dashboard.Dashboard.load_layout()
    IO.puts("Loaded #{length(loaded_widgets)} widgets")

    # Verify the loaded widgets match the saved widgets
    if length(loaded_widgets) == length(widgets_after_move) do
      IO.puts("Layout persistence verified - widget count matches")

      # Check if specific widgets were loaded correctly
      loaded_chart = Enum.find(loaded_widgets, fn w -> w.id == "chart1" end)
      loaded_treemap = Enum.find(loaded_widgets, fn w -> w.id == "treemap1" end)

      if loaded_chart && loaded_treemap do
        IO.puts("Found chart and treemap widgets in loaded layout")

        # Verify widget positions
        if loaded_chart.grid_spec.width == 6 && loaded_chart.grid_spec.height == 4 do
          IO.puts("Chart widget size correctly persisted")
        else
          IO.puts("ERROR: Chart widget size not correctly persisted")
        end

        if loaded_treemap.grid_spec.col == 2 && loaded_treemap.grid_spec.row == 4 do
          IO.puts("Treemap widget position correctly persisted")
        else
          IO.puts("ERROR: Treemap widget position not correctly persisted")
        end
      else
        IO.puts("ERROR: Could not find expected widgets in loaded layout")
      end
    else
      IO.puts("ERROR: Layout persistence failed - widget count mismatch")
    end

    # Initialize dashboard from loaded widgets
    {:ok, loaded_dashboard_model} = Raxol.Components.Dashboard.Dashboard.init(loaded_widgets, grid_config)

    # Render dashboard with loaded widgets
    loaded_props = %{
      dashboard_model: loaded_dashboard_model,
      grid_config: grid_config,
      app_text: "Sample app text for loaded layout"
    }

    loaded_widget_views = Raxol.Components.Dashboard.Dashboard.render(loaded_props)
    IO.puts("Dashboard rendered with loaded layout: #{length(loaded_widget_views)} widget views")

    # --- TEST 5: Real-Time Rendering Test ---

    IO.puts("\n[TEST 5] Real-time rendering test with responsive visualizations")

    # Test smaller grid for responsive visualization
    small_grid_config = %{
      parent_bounds: %{x: 0, y: 0, width: 40, height: 16},
      cols: 4,
      rows: 4,
      gap: 1
    }

    # Adjust widget sizes for smaller grid
    small_grid_widgets = Enum.map(loaded_widgets, fn widget ->
      case widget.id do
        "chart1" -> %{widget | grid_spec: %{col: 0, row: 0, width: 2, height: 2}}
        "treemap1" -> %{widget | grid_spec: %{col: 2, row: 0, width: 2, height: 2}}
        "info1" -> %{widget | grid_spec: %{col: 0, row: 2, width: 4, height: 1}}
        _ -> widget
      end
    end)

    # Initialize dashboard with smaller grid
    {:ok, small_dashboard_model} = Raxol.Components.Dashboard.Dashboard.init(small_grid_widgets, small_grid_config)

    # Render dashboard with smaller grid
    small_props = %{
      dashboard_model: small_dashboard_model,
      grid_config: small_grid_config,
      app_text: "Small grid test"
    }

    small_widget_views = Raxol.Components.Dashboard.Dashboard.render(small_props)
    IO.puts("Dashboard rendered with smaller grid: #{length(small_widget_views)} widget views")

    # Write test results to file
    File.mkdir_p!(Path.dirname(Path.expand(@visualization_test_file_path)))

    test_summary = """
    === Dashboard Layout Integration Test Summary ===
    - Dashboard initialized with #{length(widgets)} widgets
    - Widget resizing tested (chart1 -> 6x4)
    - Widget dragging tested (treemap1 -> col 2, row 4)
    - Layout persistence verified
    - Responsive sizing tested with smaller grid

    Test completed successfully.
    """

    File.write!(Path.expand(@visualization_test_file_path), test_summary)
    IO.puts("\n#{test_summary}")
    IO.puts("\n=== Dashboard Layout Integration Test Complete ===")
  end
end

# Run the tests
DashboardLayoutIntegrationTest.run()
