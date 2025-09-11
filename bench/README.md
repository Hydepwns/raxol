# Raxol Benchmark Suite

This directory contains all benchmarking-related files for the Raxol project.

## Directory Structure

```
bench/
├── README.md           # This file
├── baselines/          # Baseline benchmark data for comparison
├── output/             # HTML reports and visualization outputs
│   └── assets/         # Static assets for HTML reports
├── results/            # Benchmark run results
│   ├── Test Suite/     # Benchee result files (.benchee, _summary.json)
│   └── visualization/  # Visualization benchmark results
├── scripts/            # Benchmark scripts
│   └── ansi_parser_bench.exs
└── snapshots/          # Performance snapshots for regression testing
```

## Quick Start

```bash
# Run ANSI parser benchmark
mix run bench/scripts/ansi_parser_bench.exs

# Run visualization benchmarks
mix run scripts/visualization/run_visualization_benchmark.exs

# Run performance tests
mix test test/performance/performance_test.exs
```

## Documentation

For comprehensive benchmarking documentation including all available suites, advanced options, and performance guidelines, see [docs/bench/README.md](../docs/bench/README.md).

## Output Files

- **HTML Reports**: Generated in `output/` directory
- **Results**: Stored in `results/` directory (.benchee and JSON files)
- **Baselines**: Reference benchmarks in `baselines/`

## Best Practices

1. Run benchmarks before committing performance-critical changes
2. Use descriptive names with timestamps for result files
3. Update baselines after significant improvements
4. Document any performance regressions in PRs