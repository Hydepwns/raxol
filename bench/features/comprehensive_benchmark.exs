
# Comprehensive Phase 6 Features Benchmark
# Runs all feature benchmarks with performance targets

IO.puts("=== Phase 6 Features Comprehensive Benchmark ===\n")

# VIM Navigation
IO.puts("\n--- VIM Navigation ---")
Code.eval_file("bench/features/vim_navigation_benchmark.exs")

# Command Parser
IO.puts("\n\n--- Command Parser ---")
Code.eval_file("bench/features/command_parser_benchmark.exs")

# Fuzzy Search
IO.puts("\n\n--- Fuzzy Search ---")
Code.eval_file("bench/features/fuzzy_search_benchmark.exs")

# Virtual FileSystem
IO.puts("\n\n--- Virtual FileSystem ---")
Code.eval_file("bench/features/filesystem_benchmark.exs")

# Cursor Trail Effects
IO.puts("\n\n--- Cursor Trail Effects ---")
Code.eval_file("bench/features/cursor_trail_benchmark.exs")

IO.puts("\n\n=== Comprehensive Benchmark Complete ===")
