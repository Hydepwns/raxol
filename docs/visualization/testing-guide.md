# Visualization Components Testing Guide

This guide provides instructions for testing the visualization components in the Raxol application in both VS Code Extension and Native Terminal environments.

## Overview

Raxol's visualization components (bar charts and treemaps) can be tested in two different environments:

1. **VS Code Extension Mode**: The visualization components are rendered in a VS Code webview panel.
2. **Native Terminal Mode**: The visualization components are rendered directly in the terminal using terminal graphics.

Both environments should provide similar functionality but may have slight differences in appearance due to the different rendering capabilities.

## Prerequisites

- Ensure you have compiled the latest version of the Raxol application with `mix compile`.
- For VS Code Extension Mode, ensure you have the necessary dependencies installed with `cd extensions/vscode && npm install`.

## Test Scripts

We've provided two test scripts to help you test the visualization components:

1. **`scripts/test_vscode_visualization.exs`**: Prepares and tests visualization components in VS Code Extension mode.
2. **`scripts/test_terminal_visualization.exs`**: Prepares and tests visualization components in Native Terminal mode.

## Testing in VS Code Extension Mode

### Step 1: Prepare the Test Environment

Run the VS Code Extension test script:

```bash
cd /path/to/raxol
./scripts/test_vscode_visualization.exs
```

This script will:

- Create test data for bar charts and treemaps
- Generate a sample dashboard layout with visualization widgets
- Save the layout to `~/.raxol/dashboard_layout.bin`
- Verify that the layout can be loaded correctly
- Show details about the visualization widget configurations

### Step 2: Test in VS Code

1. Open the VS Code Debug panel (View > Run)
2. Select "Extension" from the dropdown menu
3. Press the play button to launch the extension in a new VS Code window
4. In the new window, open the command palette (Ctrl+Shift+P or Cmd+Shift+P)
5. Run the command "Raxol: Show Terminal"
6. A new panel should open showing the Raxol application with visualization components

### Step 3: Verify Functionality

- **Chart Rendering**: The bar chart should display correctly with labels and bars
- **Treemap Rendering**: The treemap should display hierarchical data with proper nesting
- **Resizing**: Try resizing the VS Code window or panel and verify that the visualizations adjust properly
- **Interaction**: Test keyboard navigation and interaction with the widgets
- **Quit**: Verify that Ctrl+C or the configured quit key properly terminates the application

## Testing in Native Terminal Mode

### Step 1: Prepare the Test Environment

Run the Native Terminal test script:

```bash
cd /path/to/raxol
./scripts/test_terminal_visualization.exs
```

This script will:

- Set the appropriate environment variables for native terminal mode
- Create test data for bar charts and treemaps
- Generate a sample dashboard layout with visualization widgets
- Save the layout to `~/.raxol/dashboard_layout.bin`
- Offer to launch the native terminal application directly

### Step 2: Launch the Native Terminal Application

If you didn't launch from the script, run:

```bash
./scripts/run_native_terminal.sh
```

### Step 3: Verify Functionality

- **Terminal Initialization**: Verify that ExTermbox initializes properly
- **Chart Rendering**: The bar chart should display correctly with labels and bars
- **Treemap Rendering**: The treemap should display hierarchical data with proper nesting
- **Resizing**: Try resizing the terminal window and verify that the visualizations adjust properly
- **Interaction**: Test keyboard navigation and interaction with the widgets
- **Quit**: Verify that Ctrl+C properly terminates the application without VM hang

## Common Issues and Troubleshooting

### VS Code Extension Mode

- **Panel Not Opening**: Ensure VS Code extension is activated properly; check the Debug Console for errors
- **No Visualization**: Check the output console for JSON parsing errors or missing visualization plugin initialization
- **Slow Performance**: Check if large data sets are causing performance issues

### Native Terminal Mode

- **ExTermbox Errors**: Ensure ExTermbox is properly compiled for your platform
- **Incorrect Terminal Dimensions**: The application may use fallback dimensions; try resizing the terminal
- **VM Hang on Exit**: If the BEAM VM hangs on exit, check the terminate function in Terminal.ex

## Additional Testing

### Dashboard Layout Integration

After verifying basic visualization rendering, test the integration with the dashboard system:

1. Try dragging widgets to different positions
2. Resize widgets using the resize handle
3. Test that layout persists across application restarts

### Custom Data Sets

Test with your own data sets:

1. Modify the test scripts to include your own data
2. Test with edge cases (empty data, large data sets, negative values)

## Performance Testing

### Benchmarking Visualization Components

Raxol includes comprehensive benchmarking tools for measuring visualization performance:

```bash
# Run small visualization benchmark
mix benchmark.visualization small

# Run medium visualization benchmark
mix benchmark.visualization medium

# Run large visualization benchmark
mix benchmark.visualization large

# Run production-level benchmark
mix benchmark.visualization production
```

### Recent Benchmark Results

Our latest benchmark results show exceptional performance improvements:

| Component | Without Cache | With Cache | Speedup Factor |
| --------- | ------------- | ---------- | -------------- |
| Charts    | ~350ms        | ~0.06ms    | 5,852.9x       |
| TreeMaps  | ~757ms        | ~0.05ms    | 15,140.4x      |

### Verifying Performance

When testing visualization components, observe:

1. **Initial Render Time**: The time it takes for visualizations to appear when first loaded
2. **Subsequent Render Time**: The time for redrawing after data changes or resizing
3. **Memory Usage**: Monitor system memory during visualization rendering
4. **CPU Usage**: Check for spikes during rendering operations

### Testing with Large Datasets

To test with larger datasets:

```elixir
# In iex or a script
large_chart_data = Raxol.Benchmarks.VisualizationBenchmark.generate_chart_data(10000)
large_treemap_data = Raxol.Benchmarks.VisualizationBenchmark.generate_treemap_data(1000)

# Then use this data in your test widgets
```

## Reporting Issues

If you encounter any issues during testing, please document:

1. The environment (VS Code Extension or Native Terminal)
2. The exact steps to reproduce
3. Any error messages in the console
4. Screenshots if possible

---

For questions or support, refer to the documentation or open an issue in the project repository.
