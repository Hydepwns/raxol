---
title: Testing Guide
description: Comprehensive guide for testing Raxol applications and components
date: 2024-07-27 # Updated date
author: Raxol Team
section: guides
tags: [guides, testing, documentation, exunit]
---

# Raxol Testing Guide

## Overview

This guide covers best practices and examples for testing Raxol applications and components. Testing typically involves standard Elixir tooling like ExUnit, possibly complemented by project-specific helpers found in `test/support/`.

Testing strategies might include:

1. **Unit Testing:** Testing individual functions or components in isolation.
2. **Integration Testing:** Testing the interaction between multiple components or parts of the application.
3. **Visual/Snapshot Testing:** Verifying the rendered output of components (if applicable, using tools like snapshot testing).
4. **Performance Testing:** Measuring the performance characteristics of components or the application.

## Test Types & Examples

### Unit Testing

Unit tests focus on testing individual functions or modules. For UI components (if applicable, depending on the component model used, e.g., `Raxol.App` or lower-level parts), this might involve testing state transitions or helper functions.

```elixir
# Example assuming standard ExUnit tests
defmodule MyApp.MyComponentTest do
  use ExUnit.Case, async: true

  alias MyApp.MyComponent

  test "component logic updates state correctly" do
    initial_state = MyComponent.init()
    event = :some_event
    params = %{} # Example params
    # Assuming a function handles state transitions
    {:ok, new_state} = MyComponent.handle_event(event, params, initial_state)
    assert new_state.value == :expected_value
  end
end
```

**Best Practices:**

- Test one behavior per test.
- Use descriptive test names.
- Mock external dependencies where necessary (e.g., using Mox).
- Test edge cases and error conditions.

### Integration Testing

Integration tests verify interactions between different parts of your Raxol application. This could involve testing how events flow, how parent/child components interact (if applicable), or how the application state changes in response to sequences of events.

```elixir
# Example: Testing interaction within an App or View
defmodule MyApp.AppIntegrationTest do
  use ExUnit.Case # Or potentially a ConnCase/FeatureCase if web features are involved

  # Example - Highly dependent on actual Raxol.App structure
  # This might involve starting the Runtime and sending events,
  # or testing composite views.
  test "user action triggers expected state change across components" do
    # Setup might involve starting the Raxol runtime or rendering a view
    # with multiple interacting parts.
    # ... setup code ...

    # Simulate an action
    # ... simulation code ...

    # Assert the final state or effects
    # ... assertion code ...
    assert true # Placeholder
  end
end
```

**Best Practices:**

- Test realistic user flows or interaction scenarios.
- Verify state changes across relevant parts of the application.
- Test error handling across boundaries.

### Visual/Snapshot Testing

Visual tests ensure components render correctly. This often involves "snapshot testing", where the rendered output (e.g., terminal character grid, ANSI sequences, or HTML if applicable) is compared against a previously approved "snapshot" file. The `test/snapshots/` directory suggests this might be used. Tools or custom helpers in `test/support/` might facilitate this.

```elixir
# Hypothetical Snapshot Test Example
# Check test/support/ or specific snapshot tests for actual implementation
defmodule MyApp.MyComponentSnapshotTest do
  use ExUnit.Case
  # Possibly import snapshotting helpers from test/support

  test "component renders correctly with given state" do
    state = %{value: "Example"}
    # Assuming a function generates the renderable output
    output = MyApp.MyComponent.render(state) # Or similar render call

    # Assert against a stored snapshot
    assert_snapshot "my_component_example_state", output
  end
end
```

**Best Practices:**

- Maintain snapshot tests: Review and update snapshots intentionally when UI changes are expected.
- Test components with different states/props.
- Ensure snapshot stability across environments.

### Performance Testing

Performance tests measure and verify component or application efficiency. Elixir has tools like `Benchee` that can be integrated. The `test/performance/` directory suggests dedicated performance tests exist.

```elixir
# Example using Benchee (requires adding :benchee to deps)
# Check test/performance/ for actual implementation
defmodule MyApp.PerformanceTest do
  use ExUnit.Case

  def run_render(state) do
    # Replace with actual render logic
    MyApp.MyComponent.render(state)
  end

  # @tag :performance # Optional tag for selective running
  # test "render performance is adequate" do
  #   state = %{value: "complex data"}
  #   Benchee.run(
  #     %{ "render_component" => fn -> run_render(state) end },
  #     time: 5, # seconds
  #     memory: true
  #   )
  #   # Assertions might involve checking Benchee output or comparing to baseline
  # end
end
```

**Best Practices:**

- Establish realistic benchmarks based on expected usage.
- Test with varying data sizes or complexity.
- Measure relevant metrics (time, memory, reductions).
- Monitor for performance regressions over time.

## Test Organization

### Directory Structure

The actual test directory structure appears organized by feature area or test type:

```
test/
├── core/               # Core Raxol logic tests
├── data/               # Data structure related tests
├── examples/           # Tests related to examples
├── js/                 # JavaScript-related tests (if any)
├── performance/        # Performance benchmarks
├── platform/           # Platform abstraction tests
├── platform_specific/  # Tests for specific platforms (OS, terminal)
├── raxol/              # General Raxol feature tests
├── raxol_web/          # Web-related feature tests (if any)
├── snapshots/          # Snapshot files for visual/render testing
├── support/            # Helper modules and setup for tests
├── terminal/           # Terminal emulation layer tests
├── setup.ts            # TypeScript setup for JS tests (if any)
└── test_helper.exs     # Main test helper setup (loads support/*)
```

### Naming Conventions

Follow standard Elixir conventions:

- Test files typically end with `_test.exs`.
- Use descriptive module and test names.

## Test Helpers and Utilities

Helper modules are often placed in `test/support/`. These might include:

- Setup functions for components or application state.
- Custom assertion functions.

- Factories for generating test data (e.g., using `ExMachina`).

- Mocks for external services (e.g., using `Mox`).

Examine `test/support/` and individual tests to understand available helpers.

## Continuous Integration

### Test Running

The primary command to run the default test suite is:

```bash
# Run all tests defined in mix.exs test paths
mix test
```

You can often run specific test files or directories:

```bash
# Run a specific file
mix test test/core/some_feature_test.exs

# Run all tests in a directory
mix test test/terminal/
```

**Specialized Test Scripts:**

The project utilizes helper scripts for more specific testing scenarios (e.g., platform-specific tests, dashboard tests). These provide more control and target different aspects of the testing matrix.

**Refer to the [Scripts Documentation](../../../scripts/README.md) for details on available testing scripts** like `run-local-tests.sh`, `run_all_dashboard_tests.sh`, and others, and how to use them. These are crucial for comprehensive testing beyond the basic `mix test` command.

### Performance Monitoring

If performance benchmarks exist (`test/performance/`), they might be integrated into CI to:

- Establish performance baselines.
- Monitor trends over time.
- Detect performance regressions.

## Common Pitfalls

1. **Snapshot Test Maintenance:** Brittle snapshots require frequent updates. Ensure changes are intentional.
2. **Test Environment Consistency:** Differences between local and CI environments can lead to flaky tests. Use containers (like Docker, suggested by the `/docker` directory) or consistent setup procedures.
3. **Integration Test Complexity:** Overly complex integration tests can be slow and difficult to debug. Focus on key interactions.

## Best Practices Summary

1. **General Testing:** Use standard ExUnit practices. Write clear, focused tests. Leverage helpers from `test/support/`.
2. **Component Testing:** Test component state, events, and rendering logic according to the specific component model used.
3. **Visual Testing:** If using snapshots (`test/snapshots/`), maintain them carefully.
4. **Performance Testing:** Use tools like Benchee (`test/performance/`) and integrate them into CI if needed.
5. **Utilize Scripts:** Use the helper scripts detailed in `../../../scripts/README.md` for comprehensive testing.

### Project Structure for Testing

```bash
raxol/
├── lib/                    # Source code
├── test/
│   ├── support/            # Test helpers (mocks, fixtures)
│   ├── raxol/              # Unit/integration tests mirroring lib/raxol structure
│   │   ├── core/
│   │   ├── terminal/
│   │   └── ui/
│   ├── raxol_web/          # Tests specific to web integration (if applicable)
│   └── test_helper.exs     # Configures ExUnit, starts necessary applications
├── examples/               # Example applications (runnable, not part of core tests)
├── priv/                   # Private files (e.g., themes, static assets)
├── mix.exs
└── ...
```
