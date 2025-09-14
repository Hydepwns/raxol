# Simple Muzak configuration for Raxol
# Issue: Current version appears to have compatibility issues with configuration format
# TODO: Investigate alternative mutation testing approaches or upgrade muzak version

[
  # Basic paths to test
  paths: ["lib/raxol/core"],

  # Simple test command
  test_cmd: "mix test --max-failures 1",

  # Basic mutators
  mutators: [:arithmetic_operator, :boolean_operator],

  # Exclude test files
  ignore: ["test/**/*"]
]
