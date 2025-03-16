# Performance Validation

This document outlines Raxol's performance validation framework, including benchmark methodology, performance metrics, and validation criteria.

## Table of Contents

1. [Overview](#overview)
2. [Performance Metrics](#performance-metrics)
3. [Benchmark Methodology](#benchmark-methodology)
4. [Running Benchmarks](#running-benchmarks)
5. [Interpreting Results](#interpreting-results)
6. [Baseline Metrics](#baseline-metrics)
7. [Troubleshooting Performance](#troubleshooting-performance)

## Overview

The performance validation system ensures that Raxol maintains high performance across different platforms and use cases. It measures four key areas:

1. **Rendering Performance**: How quickly components and screens can be rendered
2. **Event Handling**: Latency and throughput of the event system
3. **Memory Usage**: Efficiency of memory allocation and detection of potential leaks
4. **Animation Performance**: Smoothness and consistency of animations

Each area has specific metrics and baseline requirements that must be met for Raxol to be considered performant.

## Performance Metrics

### Rendering Performance

| Metric | Description | Target |
|--------|-------------|--------|
| Simple Component Time | Time to render a basic component | < 50μs |
| Medium Component Time | Time to render a medium-complexity component | < 200μs |
| Complex Component Time | Time to render a complex component | < 1ms |
| Full Screen Render Time | Time to render a complete 80x24 screen | < 16.7ms |
| Components Per Frame | Number of simple components that can be rendered in a 60 FPS frame budget | > 300 |
| Renders Per Second | Number of full screens that can be rendered per second | > 60 |

### Event Handling

| Metric | Description | Target |
|--------|-------------|--------|
| Keyboard Event Latency | Time to process a keyboard event | < 30μs |
| Mouse Event Latency | Time to process a mouse event | < 30μs |
| Window Event Latency | Time to process a window event | < 50μs |
| Custom Event Latency | Time to process a custom event | < 40μs |
| Burst Events Latency | Average time per event when processing a burst of events | < 50μs |
| Events Per Second | Number of events that can be processed per second | > 20,000 |

### Memory Usage

| Metric | Description | Target |
|--------|-------------|--------|
| Simple Component Memory | Memory used by a simple component | < 500 bytes |
| Medium Component Memory | Memory used by a medium-complexity component | < 2KB |
| Complex Component Memory | Memory used by a complex component | < 10KB |
| Rendering Memory Growth | Memory growth during continuous rendering | < 1MB |
| Memory Efficiency Score | Overall memory efficiency score (0-100) | > 85 |
| Memory Leak Detection | Whether a memory leak was detected | No leaks |

### Animation Performance

| Metric | Description | Target |
|--------|-------------|--------|
| Maximum FPS | Maximum frames per second achievable | > 60 FPS |
| Frame Time Consistency | Standard deviation of frame times (lower is better) | < 2ms |
| Dropped Frames | Percentage of frames that miss their deadline | < 2% |
| CPU Usage | CPU usage during animation | < 30% |
| Animation Smoothness | Overall animation smoothness score (0-100) | > 90 |

## Benchmark Methodology

The benchmark framework uses a combination of simulated workloads and actual component rendering to measure performance:

### Rendering Benchmarks

1. **Component Rendering**: Creates test components of varying complexity and measures rendering time
2. **Full Screen Rendering**: Simulates rendering a full terminal screen (80x24) and measures time
3. **Components Per Frame**: Calculates how many components can theoretically be rendered in 16.7ms (60 FPS budget)
4. **Renders Per Second**: Measures maximum full screen renders possible in one second

### Event Benchmarks

1. **Event Processing**: Measures time to process different event types
2. **Burst Handling**: Creates a burst of mixed events and measures processing time
3. **Event Throughput**: Calculates maximum events processable per second

### Memory Benchmarks

1. **Component Memory**: Measures memory used by different component types
2. **Rendering Memory**: Tracks memory growth during continuous rendering
3. **Memory Leak Detection**: Uses statistical analysis to detect potential memory leaks
4. **Memory Efficiency Scoring**: Calculates an overall memory efficiency score

### Animation Benchmarks

1. **Maximum FPS**: Measures maximum achievable frame rate
2. **Frame Time Consistency**: Analyzes variance in frame rendering times
3. **Dropped Frame Analysis**: Counts frames that miss their target time
4. **Smoothness Calculation**: Combines metrics to score animation smoothness

## Running Benchmarks

### Using the CLI Script

The simplest way to run performance benchmarks is using the provided script:

```bash
# Run all benchmarks
mix run scripts/validate_performance.exs

# Run with detailed output
mix run scripts/validate_performance.exs --detailed

# Save results to file
mix run scripts/validate_performance.exs --save

# Run a specific category
mix run scripts/validate_performance.exs --category render
mix run scripts/validate_performance.exs --category event
mix run scripts/validate_performance.exs --category memory
mix run scripts/validate_performance.exs --category animation

# Run a quicker (less accurate) benchmark
mix run scripts/validate_performance.exs --quick
```

### Using the ExUnit Tests

Performance tests are also available as ExUnit tests:

```bash
# Run all performance tests
mix test test/performance

# Run specific performance test
mix test test/performance/performance_test.exs:10

# Run the full benchmark suite
mix test test/performance/performance_test.exs --only full_benchmark
```

### From Elixir Code

You can also run benchmarks programmatically:

```elixir
# Run all benchmarks
results = Raxol.Benchmarks.Performance.run_all()

# Run specific benchmark
render_results = Raxol.Benchmarks.Performance.benchmark_rendering()
event_results = Raxol.Benchmarks.Performance.benchmark_event_handling()
memory_results = Raxol.Benchmarks.Performance.benchmark_memory_usage()
animation_results = Raxol.Benchmarks.Performance.benchmark_animation_performance()
```

## Interpreting Results

### Overall Performance Rating

The benchmark system provides an overall performance rating:

- **Excellent**: 95%+ metrics pass baseline validation
- **Good**: 80-95% metrics pass baseline validation
- **Acceptable**: 60-80% metrics pass baseline validation
- **Failed**: Less than 60% metrics pass baseline validation

### Understanding Metric Validation

Each metric is validated against a baseline value appropriate for the current platform. The validation:

1. Compares the measured value against the baseline
2. Determines if the metric passes or fails
3. Provides a detailed message explaining the result

For example:

```
✓ Simple component render time: 35μs (baseline: 50μs)
✗ Full screen render time: 22ms (baseline: 16.7ms)
```

## Baseline Metrics

Baseline metrics are platform-specific target values that Raxol should meet or exceed. They are stored in JSON files in the `priv/baseline_metrics` directory:

- `default_baseline.json`: Default baseline for all platforms
- `macos_baseline.json`: macOS-specific baselines
- `linux_baseline.json`: Linux-specific baselines
- `windows_baseline.json`: Windows-specific baselines

The benchmark system automatically selects the appropriate baseline based on the current platform, falling back to default baseline if no platform-specific baseline exists.

### Customizing Baselines

To customize baselines for your specific hardware or use case:

1. Run a benchmark with the `--save` flag
2. Examine the generated JSON file in `_build/benchmark_results`
3. Copy relevant sections to your platform's baseline file
4. Adjust values as needed

## Troubleshooting Performance

If performance validation fails, consider the following steps:

### Rendering Performance Issues

- Check for excessive component nesting
- Look for components that render unnecessarily
- Verify terminal capabilities and fallbacks
- Check for frequent full-screen rendering

### Event Handling Issues

- Look for excessive event subscriptions
- Check for complex event processing logic
- Verify event dispatch patterns
- Consider optimizing high-frequency events

### Memory Usage Issues

- Check for component leaks (components not being garbage collected)
- Look for large data structures in component state
- Verify cleanup of subscriptions and resources
- Consider profiling with memory tools

### Animation Performance Issues

- Check for complex animations running simultaneously
- Verify frame timing consistency
- Look for unnecessary rendering during animation
- Consider reducing animation complexity on slower platforms

## Continuous Integration

The performance validation framework is integrated with the CI/CD pipeline:

1. Performance tests run on every pull request
2. Baseline validation runs on release branches
3. Performance regressions block merges to main branches
4. Benchmark results are stored as artifacts for analysis

This ensures that performance remains a priority and prevents regressions from being introduced. 