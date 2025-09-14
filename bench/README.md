# Raxol Benchmark Suite

This directory contains all benchmarking-related files for the Raxol project.

## Directory Structure

```
bench/
├── README.md           # This file
├── suites/             # Organized benchmark suites
│   ├── parser/         # ANSI parser and sequence benchmarks
│   ├── terminal/       # Buffer, cursor, and emulator benchmarks
│   ├── rendering/      # UI rendering performance benchmarks
│   ├── core/           # System-wide performance benchmarks
│   └── validation/     # Optimization validation benchmarks
├── archived/           # Historical and deprecated benchmarks
├── baselines/          # Baseline benchmark data for comparison
├── output/             # HTML reports and visualization outputs
│   └── assets/         # Static assets for HTML reports
├── results/            # Benchmark run results
│   ├── Test Suite/     # Benchee result files (.benchee, _summary.json)
│   └── visualization/  # Visualization benchmark results
├── scripts/            # Benchmark utilities and scripts
└── snapshots/          # Performance snapshots for regression testing
```

## Quick Start

```bash
# Run parser benchmarks
mix run bench/suites/parser/parser_benchmark.exs

# Run terminal benchmarks
mix run bench/suites/terminal/buffer_benchmark.exs

# Run rendering benchmarks
mix run bench/suites/rendering/render_performance_simple.exs

# Run validation benchmarks
mix run bench/suites/validation/validate_optimizations.exs

# Run system-wide benchmarks
mix run bench/suites/core/performance_summary.exs
```

## Benchmark Suites

### Parser Suite (`suites/parser/`)
- **parser_benchmark.exs**: Main ANSI parser performance tests
- **ansi_profile.exs**: Detailed ANSI sequence processing profiles  
- **parser_chain_profile.exs**: Parser state chain performance
- **sgr_comparison.exs**: SGR (color) sequence benchmark comparisons

### Terminal Suite (`suites/terminal/`)
- **buffer_benchmark.exs**: Screen buffer memory and performance tests
- **cursor_benchmark.exs**: Cursor movement and positioning benchmarks
- **emulator_profiling.exs**: Terminal emulator performance profiling
- **lite_emulator_test.exs**: Lightweight emulator performance tests

### Rendering Suite (`suites/rendering/`)
- **render_performance_simple.exs**: Basic rendering pipeline benchmarks
- **render_pipeline_profiling.exs**: Advanced rendering performance analysis

### Core Suite (`suites/core/`)
- **performance_summary.exs**: System-wide performance overview
- **performance_improvements_benchmark.exs**: Before/after optimization tests

### Validation Suite (`suites/validation/`)
- **validate_optimizations.exs**: Validation of optimization changes
- **verify_optimization.exs**: Verification of performance improvements

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