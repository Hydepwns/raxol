## Performance

| Metric       | Raxol       |
|--------------|-------------|
| Full Frame   | 2.1ms       |
| Tree Diff    | 4us         |
| Cell Write   | 0.97us      |
| ANSI Parse   | 38us        |
| Test Suite   | 6400+ tests |

Benchmarked on Apple M1 Pro / Elixir 1.19 / OTP 27.

**Platform note**: Unix/macOS uses a termbox2 NIF (~50us/frame). Windows uses a pure Elixir terminal driver (~500us/frame, ~10x slower). Windows support is functional but not performance-optimized.
