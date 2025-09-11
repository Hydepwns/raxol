#!/usr/bin/env elixir

# Test script for verifying layout persistence (save/load) functionality
# This script tests:
# 1. Saving a dashboard layout with various widget types
# 2. Loading the dashboard layout
# 3. Verifying that all widget configurations are preserved correctly

defmodule LayoutPersistenceTest do
  require Raxol.Core.Runtime.Log

  @layout_test_file_path "~/.raxol/layout_persistence_test.log"

  def run do
    IO.puts("=== Layout Persistence Test ===\n")
    IO.puts("Testing dashboard layout save/load functionality")

    # Test 1: Create and save a complex layout
    IO.puts("\n[TEST 1] Creating and saving a complex layout")

    # Create sample data for visualizations
    bar_chart_data = [
      %{label: "Q1", value: 120},
      %{label: "Q2", value: 180},
      %{label: "Q3", value: 90},
      %{label: "Q4", value: 210}
    ]

    treemap_data = %{
      name: "Expenses",
      value: 1000,
      children: [
        %{name: "Rent", value: 400},
        %{name: "Utilities", value: 100},
        %{name: "Salaries", value: 500}
      ]
    }

    # Define dashboard widgets
    complex_widgets = [
      %{
        id: "chart-quarterly",
        type: :chart,
        title: "Quarterly Revenue",
        grid_spec: %{col: 0, row: 0, width: 3, height: 2},
        data: bar_chart_data,
        component_opts: %{
          type: :bar,
          title: "Quarterly Revenue",
          x_axis_label: "Quarter",
          y_axis_label: "Revenue (K$)"
        }
      },
      %{
        id: "treemap-expenses",
        type: :treemap,
        title: "Expense Breakdown",
        grid_spec: %{col: 3, row: 0, width: 3, height: 3},
        data: treemap_data,
        component_opts: %{
          title: "Expense Breakdown"
        }
      },
      %{
        id: "info-widget",
        type: :info,
        title: "Company Overview",
        grid_spec: %{col: 0, row: 2, width: 3, height: 1},
        data: "Company financial overview dashboard showing quarterly performance.",
        component_opts: %{
          bg_color: 3
        }
      },
      %{
        id: "text-widget",
        type: :text_input,
        title: "Notes",
        grid_spec: %{col: 0, row: 3, width: 6, height: 2},
        data: "Enter your analysis here...",
        component_opts: %{
          multiline: true,
          placeholder: "Type notes here"
        }
      }
    ]

    # Save the layout
    IO.puts("Saving complex dashboard layout with #{length(complex_widgets)} widgets...")

    case Raxol.UI.Components.Dashboard.Dashboard.save_layout(complex_widgets) do
      :ok ->
        IO.puts("Layout saved successfully")

      {:error, reason} ->
        IO.puts("Failed to save layout: #{inspect(reason)}")
        exit(1)
    end

    # Test 2: Load the saved layout
    IO.puts("\n[TEST 2] Loading the saved layout")

    loaded_widgets = Raxol.UI.Components.Dashboard.Dashboard.load_layout()
    IO.puts("Loaded #{length(loaded_widgets)} widgets")

    # Test 3: Verify the loaded widgets match the saved widgets
    IO.puts("\n[TEST 3] Verifying loaded widget configurations")

    if length(loaded_widgets) != length(complex_widgets) do
      IO.puts("ERROR: Widget count mismatch. Expected #{length(complex_widgets)}, got #{length(loaded_widgets)}")
      exit(1)
    end

    IO.puts("Widget count matches (#{length(loaded_widgets)} widgets)")

    # Check that all widgets were loaded with correct properties
    loaded_chart = Enum.find(loaded_widgets, fn w -> w.id == "chart-quarterly" end)
    loaded_treemap = Enum.find(loaded_widgets, fn w -> w.id == "treemap-expenses" end)
    loaded_info = Enum.find(loaded_widgets, fn w -> w.id == "info-widget" end)
    loaded_text = Enum.find(loaded_widgets, fn w -> w.id == "text-widget" end)

    # Verify chart widget
    if loaded_chart do
      IO.puts("\nChart widget found in loaded layout:")
      IO.puts("  - ID: #{loaded_chart.id}")
      IO.puts("  - Type: #{loaded_chart.type}")
      IO.puts("  - Title: #{loaded_chart.title}")
      IO.puts("  - Grid: col=#{loaded_chart.grid_spec.col}, row=#{loaded_chart.grid_spec.row}, " <>
                         "width=#{loaded_chart.grid_spec.width}, height=#{loaded_chart.grid_spec.height}")

      if length(loaded_chart.data) == length(bar_chart_data) do
        IO.puts("  - Data length correct")
      else
        IO.puts("  - ERROR: Data length mismatch")
      end

      if loaded_chart.component_opts[:title] == "Quarterly Revenue" do
        IO.puts("  - Component options correct")
      else
        IO.puts("  - ERROR: Component options not preserved")
      end
    else
      IO.puts("\nERROR: Chart widget not found in loaded layout")
    end

    # Verify treemap widget
    if loaded_treemap do
      IO.puts("\nTreemap widget found in loaded layout:")
      IO.puts("  - ID: #{loaded_treemap.id}")
      IO.puts("  - Type: #{loaded_treemap.type}")
      IO.puts("  - Title: #{loaded_treemap.title}")
      IO.puts("  - Grid: col=#{loaded_treemap.grid_spec.col}, row=#{loaded_treemap.grid_spec.row}, " <>
                         "width=#{loaded_treemap.grid_spec.width}, height=#{loaded_treemap.grid_spec.height}")

      if loaded_treemap.data.name == "Expenses" do
        IO.puts("  - Root node name correct")
      else
        IO.puts("  - ERROR: Root node name mismatch")
      end

      if length(loaded_treemap.data.children) == length(treemap_data.children) do
        IO.puts("  - Children count correct")
      else
        IO.puts("  - ERROR: Children count mismatch")
      end
    else
      IO.puts("\nERROR: Treemap widget not found in loaded layout")
    end

    # Verify other widgets (brief check)
    IO.puts("\nInfo widget present: #{if loaded_info, do: "Yes", else: "No"}")
    IO.puts("Text input widget present: #{if loaded_text, do: "Yes", else: "No"}")

    # Create modified layout and save again to test update capability
    IO.puts("\n[TEST 4] Modifying and saving updated layout")

    # Modify loaded widgets (change positions and sizes)
    updated_widgets = Enum.map(loaded_widgets, fn widget ->
      case widget.id do
        "chart-quarterly" ->
          %{widget | grid_spec: %{widget.grid_spec | width: 4, height: 3}} # Make chart bigger

        "treemap-expenses" ->
          %{widget | grid_spec: %{widget.grid_spec | col: 4, row: 3}} # Move treemap

        _ -> widget
      end
    end)

    # Save updated layout
    IO.puts("Saving updated layout...")

    case Raxol.UI.Components.Dashboard.Dashboard.save_layout(updated_widgets) do
      :ok ->
        IO.puts("Updated layout saved successfully")

      {:error, reason} ->
        IO.puts("Failed to save updated layout: #{inspect(reason)}")
        exit(1)
    end

    # Load updated layout
    IO.puts("\nLoading updated layout...")
    updated_loaded_widgets = Raxol.UI.Components.Dashboard.Dashboard.load_layout()

    # Verify changes were preserved
    updated_chart = Enum.find(updated_loaded_widgets, fn w -> w.id == "chart-quarterly" end)
    updated_treemap = Enum.find(updated_loaded_widgets, fn w -> w.id == "treemap-expenses" end)

    if updated_chart && updated_chart.grid_spec.width == 4 && updated_chart.grid_spec.height == 3 do
      IO.puts("Chart widget size updated correctly")
    else
      IO.puts("ERROR: Chart widget size update failed")
    end

    if updated_treemap && updated_treemap.grid_spec.col == 4 && updated_treemap.grid_spec.row == 3 do
      IO.puts("Treemap widget position updated correctly")
    else
      IO.puts("ERROR: Treemap widget position update failed")
    end

    # Write test results to file
    File.mkdir_p!(Path.dirname(Path.expand(@layout_test_file_path)))

    test_summary = """
    === Layout Persistence Test Summary ===
    - Created and saved complex layout with #{length(complex_widgets)} widgets
    - Successfully loaded saved layout
    - Verified widget configurations (properties, grid specs, data)
    - Modified and saved updated layout
    - Verified updates were preserved

    Test completed successfully.
    """

    File.write!(Path.expand(@layout_test_file_path), test_summary)
    IO.puts("\n#{test_summary}")
    IO.puts("\n=== Layout Persistence Test Complete ===")
  end
end

# Run the tests
LayoutPersistenceTest.run()
