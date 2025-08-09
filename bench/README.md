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

## Running Benchmarks

### ANSI Parser Benchmark
```bash
mix run bench/scripts/ansi_parser_bench.exs
```

### Visualization Benchmarks
```bash
mix run scripts/run_visualization_benchmark.exs
```

### Performance Tests
```bash
mix test test/performance/performance_test.exs
```

## Output Files

- **HTML Reports**: Generated in `output/` directory
  - `report.html` - Main benchmark report
  - `report_comparison.html` - Comparison between runs
  - Individual operation reports

- **Results**: Stored in `results/` directory
  - `.benchee` files - Raw benchmark data
  - `_summary.json` files - JSON summaries for processing

- **Baselines**: Reference benchmarks stored in `baselines/`
  - Used for regression detection
  - Update with `mix benchmark.update_baseline`

## Best Practices

1. **Before Committing**: Run benchmarks to ensure no performance regressions
2. **Naming Convention**: Use descriptive names with timestamps
3. **Clean Up**: Old result files can be safely deleted after analysis
4. **Documentation**: Update this README when adding new benchmark scripts

## Ignored Files

The following are ignored by git:
- `output/` - Generated HTML reports
- `results/**/*.benchee` - Raw benchmark data
- `results/**/*_summary.json` - JSON summaries
- `snapshots/` - Temporary snapshots

Keep important baseline data in `baselines/` for version control.