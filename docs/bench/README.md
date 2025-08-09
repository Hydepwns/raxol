# Raxol Performance Benchmarking Suite

## Overview

The Raxol benchmarking suite provides comprehensive performance testing and analysis tools to ensure optimal performance across all components of the system.

## Quick Start

```bash
# Run all benchmarks
mix benchmark --all

# Run specific suite
mix benchmark --suite terminal

# Compare with baseline
mix benchmark --all --compare

# Quick benchmark (reduced time)
mix benchmark --suite terminal --quick
```

## Available Benchmark Suites

### Terminal Benchmarks

Tests terminal emulation performance including ANSI parsing, text rendering, cursor movement, and screen operations.

```bash
mix benchmark --suite terminal
```

### Rendering Benchmarks

Tests UI rendering pipeline performance including scene rendering, animations, and layout calculations.

```bash
mix benchmark --suite rendering
```

### Buffer Benchmarks

Tests buffer operations including read/write performance, scrolling, and memory management.

```bash
mix benchmark --suite buffer
```

### Plugin Benchmarks

Tests plugin system performance including loading, messaging, and lifecycle operations.

```bash
mix benchmark --suite plugin
```

### Component Benchmarks

Tests UI component rendering performance for various component types.

```bash
mix benchmark --suite component
```

### Security Benchmarks

Tests security operations performance including input validation and session management.

```bash
mix benchmark --suite security
```

## Advanced Usage

### Profiling Mode

Enable detailed profiling to identify performance bottlenecks:

```bash
mix benchmark --suite terminal --profile
```

### Custom Benchmark Configuration

```bash
# Longer benchmark duration for more accurate results
mix benchmark --suite terminal --time 10 --warmup 5

# Include memory measurements
mix benchmark --suite terminal --memory

# Run only specific benchmarks
mix benchmark --suite terminal --only "ANSI.*"

# Exclude specific benchmarks
mix benchmark --suite terminal --except "Complex.*"
```

### Output Formats

Generate reports in different formats:

```bash
# HTML report with charts
mix benchmark --all --format html --output bench/reports

# JSON for programmatic analysis
mix benchmark --all --format json

# Markdown for documentation
mix benchmark --all --format markdown
```

### Baseline Management

Save and compare performance baselines:

```bash
# Save current results as baseline
mix benchmark --all --save-baseline

# Compare with saved baseline
mix benchmark --all --compare

# Update baseline for specific suite
UPDATE_BASELINE_terminal=true mix benchmark --suite terminal
```

## Analyzing Results

### Performance Regression Detection

The benchmark suite automatically detects performance regressions when comparing with baselines:

- **Regression**: Performance degradation > 10%
- **Improvement**: Performance improvement > 10%

### Report Structure

Generated reports include:

1. **Summary**: Overall performance metrics
2. **Performance Highlights**: Fastest and slowest operations
3. **Regressions**: Detected performance degradations
4. **Improvements**: Detected performance improvements
5. **Recommendations**: Suggested optimizations
6. **Detailed Results**: Full benchmark data

### Historical Analysis

View performance trends over time:

```elixir
# In IEx
alias Raxol.Benchmark.Storage

# Load last 30 days of results
Storage.load_historical("terminal", days: 30)

# Export to CSV for external analysis
Storage.export_to_csv("terminal", "terminal_benchmarks.csv")
```

## Writing Custom Benchmarks

Create a new benchmark suite:

```elixir
defmodule Raxol.Benchmark.Suites.CustomBenchmarks do
  def run(opts \\ []) do
    Benchee.run(
      %{
        "my operation" => fn input ->
          # Benchmark code here
        end
      },
      Keyword.merge(default_options(), opts)
    )
  end
  
  defp default_options do
    [
      warmup: 2,
      time: 5,
      inputs: %{
        "small" => generate_small_input(),
        "large" => generate_large_input()
      }
    ]
  end
end
```

## Continuous Integration

Add benchmarking to your CI pipeline:

```yaml
# .github/workflows/benchmark.yml
- name: Run benchmarks
  run: mix benchmark --all --compare
  
- name: Upload results
  uses: actions/upload-artifact@v2
  with:
    name: benchmark-results
    path: bench/output/
```

## Performance Guidelines

### Target Performance Metrics

- **Terminal Operations**: < 1ms for typical operations
- **Rendering**: 60 FPS (16.67ms per frame)
- **Buffer Operations**: < 0.1ms for read/write
- **Component Rendering**: < 5ms for complex components

### Optimization Strategies

1. **Profile First**: Use `--profile` to identify bottlenecks
2. **Measure Impact**: Compare before/after with baselines
3. **Focus on Hot Paths**: Optimize frequently called operations
4. **Memory Efficiency**: Monitor memory usage with `--memory`

## Troubleshooting

### Common Issues

1. **Inconsistent Results**
   - Increase warmup time: `--warmup 5`
   - Increase benchmark time: `--time 10`
   - Close other applications

2. **Out of Memory**
   - Reduce input size
   - Run suites individually
   - Use `--quick` mode

3. **Missing Baseline**
   - Create initial baseline: `--save-baseline`
   - Check bench/baselines/ directory

### Debug Mode

Enable verbose output:

```bash
MIX_DEBUG=1 mix benchmark --suite terminal
```

## Directory Structure

```
bench/
├── README.md           # This file
├── baselines/         # Saved performance baselines
├── output/            # Generated reports
├── results/           # Raw benchmark results
├── snapshots/         # Version snapshots
└── scripts/           # Utility scripts
```

## Contributing

When adding new features:

1. Add corresponding benchmarks
2. Run benchmarks before submitting PR
3. Include benchmark results in PR description
4. Update baseline if intentional performance change

## Resources

- [Benchee Documentation](https://hexdocs.pm/benchee)
- [Performance Monitoring](../../examples/guides/05_development_and_testing/development/planning/performance/PerformanceMonitoring.md)
- [Performance Optimization](../../examples/guides/05_development_and_testing/development/planning/performance/PerformanceOptimization.md)
