# `Raxol.Terminal.Emulator.OptimizedInputProcessor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/optimized_input_processor.ex#L1)

Optimized input processing for the terminal emulator.

This module provides performance-optimized versions of input processing
functions with the following improvements:

- Removed debug IO.puts statements
- Optimized string concatenation using iolists
- Reduced function calls and pattern matching
- Implemented caching for charset commands
- Minimized cursor position checks

# `batch_process_inputs`

Batch process multiple input chunks for better performance.

# `ensure_cursor_visible_optimized`

Optimized cursor visibility check that minimizes repeated calculations.

# `precompile_sequences`

Precompile common escape sequences for faster matching.

# `process_input`

Optimized version of process_input that minimizes allocations and function calls.

# `profile_input_processing`

Profile input processing performance.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
