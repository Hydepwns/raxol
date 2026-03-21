# Benchmarking

Raxol's benchmark suite measures performance across terminal emulation, rendering, buffers, plugins, components, and security operations.

## Quick Start

```bash
mix benchmark --all                    # Run everything
mix benchmark --suite terminal         # Run one suite
mix benchmark --all --compare          # Compare against saved baseline
mix benchmark --suite terminal --quick # Shorter run
```

## Suites

- **Terminal** -- ANSI parsing, text rendering, cursor movement, screen ops
- **Rendering** -- Scene rendering, animations, layout calculations
- **Buffer** -- Read/write performance, scrolling, memory management
- **Plugin** -- Loading, messaging, lifecycle operations
- **Component** -- UI component rendering across types
- **Security** -- Input validation, session management

## Configuration

```bash
# Longer runs for more stable numbers
mix benchmark --suite terminal --time 10 --warmup 5

# Include memory measurements
mix benchmark --suite terminal --memory

# Filter benchmarks
mix benchmark --suite terminal --only "ANSI.*"
mix benchmark --suite terminal --except "Complex.*"

# Profiling mode
mix benchmark --suite terminal --profile
```

## Output Formats

```bash
mix benchmark --all --format html --output bench/reports  # HTML with charts
mix benchmark --all --format json                         # JSON
mix benchmark --all --format markdown                     # Markdown
```

## Baselines

```bash
mix benchmark --all --save-baseline                              # Save current results
mix benchmark --all --compare                                    # Compare with baseline
UPDATE_BASELINE_terminal=true mix benchmark --suite terminal     # Update one suite
```

Regression detection thresholds: >10% degradation flags a regression, >10% improvement flags a win.

## Historical Analysis

```elixir
# In IEx
alias Raxol.Benchmark.Storage

Storage.load_historical("terminal", days: 30)
Storage.export_to_csv("terminal", "terminal_benchmarks.csv")
```

## Writing Custom Benchmarks

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

## CI Integration

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

## Performance Targets

- Terminal operations: < 1ms
- Rendering: 60 FPS (16.67ms per frame)
- Buffer read/write: < 0.1ms
- Component rendering: < 5ms for complex components

## Troubleshooting

**Inconsistent results** -- increase warmup (`--warmup 5`) and run time (`--time 10`), close other apps.

**Out of memory** -- reduce input size, run suites individually, or use `--quick`.

**Missing baseline** -- run `--save-baseline` first. Check `bench/baselines/`.

**Debug mode**: `MIX_DEBUG=1 mix benchmark --suite terminal`

## Directory Layout

```
bench/
├── README.md        # This file
├── baselines/       # Saved performance baselines
├── output/          # Generated reports
├── results/         # Raw benchmark results
├── snapshots/       # Version snapshots
└── scripts/         # Utility scripts
```
