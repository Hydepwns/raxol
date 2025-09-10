[
  # Phoenix/LiveView related warnings - common false positives
  ~r"Call to missing or private function 'Phoenix\\..*'",
  ~r"Function 'Phoenix\\..*' does not exist",
  ~r"The function call 'Phoenix\\..*' will never return",
  ~r"The created fun has no local return",
  ~r"Function .*__live_view__.*has no local return",

  # NIF related warnings - termbox2_nif integration
  ~r"Function .*termbox2_nif.*has no local return",
  ~r"Call to missing or private function .*termbox2_nif.*",
  ~r"The function .*\.load_nif.* is expected to fail",
  ~r"Function .*\.load_nif.* will never return since it differs in the 2nd argument",

  # Test-specific warnings
  ~r"Function .*test.*has no local return",
  ~r"The function .*\.setup.* is expected to fail",
  ~r"Function .*ExUnit\..*has no local return",
  ~r"Call to missing or private function .*ExUnit\..*",

  # Elixir/OTP false positives
  ~r"The function .*\.start_link.* is expected to fail",
  ~r"Function .*GenServer\..*has no local return",
  ~r"The created fun has no clauses that will ever match",
  ~r"Guard test .* can never succeed",
  ~r"Pattern match .* can never succeed",

  # Mix task and application startup warnings
  ~r"Function .*Mix\..*has no local return",
  ~r"Function .*Application\..*has no local return",
  ~r"The function .*\.start.* is expected to fail",

  # Terminal/ANSI parsing specific - high-performance code optimizations
  ~r"Function .*ANSI\.Parser.*has no local return",
  ~r"The function .*\.parse_sequence.* is expected to fail",
  ~r"Pattern match on binary .* can never succeed",

  # Component lifecycle and framework integration
  ~r"Function .*\.mount.* is expected to fail",
  ~r"Function .*\.handle_event.* is expected to fail",
  ~r"Function .*\.render.* has no local return",

  # Error handler and recovery system
  ~r"Function .*ErrorHandler.*has no local return",
  ~r"The function .*\.handle_error.* is expected to fail",

  # Development and debugging utilities
  ~r"Function .*\.debug.* has no local return",
  ~r"Function .*Logger\..*has no local return"
]
