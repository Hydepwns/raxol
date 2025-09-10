# Visualization Components Testing Guide

This guide provides comprehensive instructions for testing the visualization components in the Raxol application, covering both VS Code Extension and Native Terminal environments.

## Overview

Raxol's visualization components can be tested in two different environments:

1. **VS Code Extension Mode**: Components rendered in a VS Code webview panel
2. **Native Terminal Mode**: Components rendered directly in the terminal using terminal graphics

Both environments provide similar functionality with slight differences in appearance due to different rendering capabilities.

## Prerequisites

### System Requirements

- Elixir 1.14+ and Erlang/OTP 25+
- Node.js 16+ (for VS Code Extension)
- PostgreSQL 13+ (for database components)
- Terminal with true color support (for Native Terminal mode)

### Setup Steps

1. Compile the latest version:

   ```bash
   mix deps.get
   mix compile
   ```

2. For VS Code Extension:

   ```bash
   cd extensions/vscode
   npm install
   ```

3. Set up test database:
   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

## Test Scripts

### Available Scripts

1. **VS Code Extension Tests**:

   ```bash
   ./scripts/test_vscode_visualization.exs
   ```

2. **Native Terminal Tests**:

   ```bash
   ./scripts/test_terminal_visualization.exs
   ```

3. **Performance Tests**:
   ```bash
   mix benchmark.visualization [small|medium|large|production]
   ```

## Testing in VS Code Extension Mode

### Environment Setup

1. Run the VS Code Extension test script:

   ```bash
   ./scripts/test_vscode_visualization.exs
   ```

2. The script will:
   - Create test data for all visualization types
   - Generate a sample dashboard layout
   - Save layout to `~/.raxol/dashboard_layout.bin`
   - Verify layout loading
   - Display widget configurations

### Launching Tests

1. Open VS Code Debug panel (View > Run)
2. Select "Extension" from dropdown
3. Press play to launch extension
4. Open command palette (Ctrl+Shift+P or Cmd+Shift+P)
5. Run "Raxol: Show Terminal"

### Verification Checklist

- [ ] Chart rendering with correct labels and bars
- [ ] Treemap rendering with proper nesting
- [ ] Responsive resizing behavior
- [ ] Keyboard navigation
- [ ] Mouse interaction
- [ ] Proper application termination

## Testing in Native Terminal Mode

### Environment Setup

1. Run the Native Terminal test script:

   ```bash
   ./scripts/test_terminal_visualization.exs
   ```

2. The script will:
   - Set environment variables
   - Create test data
   - Generate dashboard layout
   - Save layout configuration
   - Offer direct launch option

### Launching Tests

```bash
./scripts/run_native_terminal.sh
```

### Verification Checklist

- [ ] Terminal initialization
- [ ] Chart rendering
- [ ] Treemap rendering
- [ ] Window resizing
- [ ] Keyboard navigation
- [ ] Clean application termination

## Performance Testing

### Benchmarking Tools

```bash
# Run benchmarks
mix benchmark.visualization small    # 1,000 data points
mix benchmark.visualization medium   # 10,000 data points
mix benchmark.visualization large    # 100,000 data points
mix benchmark.visualization production # 1,000,000 data points
```

### Performance Metrics

| Component | Without Cache | With Cache | Speedup Factor |
| --------- | ------------- | ---------- | -------------- |
| Charts    | ~350ms        | ~0.06ms    | 5,852.9x       |
| TreeMaps  | ~757ms        | ~0.05ms    | 15,140.4x      |

### Performance Verification

1. **Initial Render Time**

   - Should be < 100ms for small datasets
   - Should be < 500ms for large datasets

2. **Subsequent Render Time**

   - Should be < 50ms for small datasets
   - Should be < 200ms for large datasets

3. **Memory Usage**

   - Monitor with `mix profile.memory`
   - Should not exceed 100MB for large datasets

4. **CPU Usage**
   - Monitor with `mix profile.cpu`
   - Should not spike above 50% during rendering

## Advanced Testing

### Custom Data Testing

```elixir
# Generate test data
large_chart_data = Raxol.Benchmarks.VisualizationBenchmark.generate_chart_data(10000)
large_treemap_data = Raxol.Benchmarks.VisualizationBenchmark.generate_treemap_data(1000)

# Test with custom data
Raxol.Visualization.TestRunner.run_with_data(large_chart_data)
```

### Edge Cases

1. **Empty Data**

   - Should display appropriate empty state
   - Should handle zero values correctly

2. **Invalid Data**

   - Should handle null values
   - Should handle undefined values
   - Should handle out-of-range values

3. **Large Datasets**
   - Should implement virtual scrolling
   - Should maintain performance
   - Should handle memory efficiently

## Troubleshooting

### VS Code Extension Issues

1. **Panel Not Opening**

   - Check extension activation
   - Review Debug Console for errors
   - Verify webview permissions

2. **Rendering Issues**

   - Check JSON parsing
   - Verify plugin initialization
   - Review webview console

3. **Performance Issues**
   - Monitor data set size
   - Check memory usage
   - Review rendering cycles

### Native Terminal Issues

1. **Terminal Errors**

   - Verify rrex_termbox installation
   - Check terminal compatibility
   - Review NIF compilation

2. **Rendering Issues**

   - Check terminal dimensions
   - Verify color support
   - Review buffer management

3. **VM Issues**
   - Check terminate function
   - Review process cleanup
   - Monitor resource usage
