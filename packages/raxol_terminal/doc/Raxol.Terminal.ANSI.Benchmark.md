# `Raxol.Terminal.ANSI.Benchmark`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/benchmark.ex#L1)

Provides benchmarking capabilities for the ANSI handling system.
Measures performance of parsing and processing ANSI sequences.

# `benchmark_parsing`

```elixir
@spec benchmark_parsing() :: %{
  total_time_ms: float(),
  iterations: 1000,
  sequences_per_second: float(),
  average_time_per_sequence_ms: float()
}
```

Benchmarks the parsing performance with various ANSI sequences.

# `benchmark_processing`

```elixir
@spec benchmark_processing() :: %{
  total_time_ms: float(),
  iterations: 1000,
  sequences_per_second: float(),
  average_time_per_sequence_ms: float()
}
```

Benchmarks the processing performance with various ANSI sequences.

# `benchmark_state_machine`

```elixir
@spec benchmark_state_machine() :: %{
  total_time_ms: float(),
  iterations: 1000,
  inputs_per_second: float(),
  average_time_per_input_ms: float()
}
```

Benchmarks the state machine performance with various inputs.

# `run_benchmark`

```elixir
@spec run_benchmark() :: %{
  parse_benchmark: %{
    total_time_ms: float(),
    iterations: 1000,
    sequences_per_second: float(),
    average_time_per_sequence_ms: float()
  },
  process_benchmark: %{
    total_time_ms: float(),
    iterations: 1000,
    sequences_per_second: float(),
    average_time_per_sequence_ms: float()
  },
  state_machine_benchmark: %{
    total_time_ms: float(),
    iterations: 1000,
    inputs_per_second: float(),
    average_time_per_input_ms: float()
  }
}
```

Runs a benchmark suite on the ANSI handling system.
Returns a map of benchmark results.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
