# Raxol Scripts

This directory contains helper scripts for development, testing, and quality assurance.

## Table of Contents

- [Pre-Commit & Quality Checks](#pre-commit--quality-checks)
- [Validation Scripts](#validation-scripts)
- [Testing Scripts](#testing-scripts)
  - [General Testing](#general-testing)
  - [Dashboard/UI Testing](#dashboardui-testing)
  - [Visualization Testing](#visualization-testing)
  - [Terminal Testing & Verification](#terminal-testing--verification)
  - [VS Code Testing](#vs-code-testing)
- [Database Scripts](#database-scripts)
- [Build & Release Scripts](#build--release-scripts)
- [Development Utilities](#development-utilities)
- [Git Pre-Commit Hook](#git-pre-commit-hook)

## Pre-Commit & Quality Checks

Ensure code quality before committing.

- `pre_commit_check.exs`: Runs all applicable checks (Dialyzer, Credo, Format, Docs, Links, Coverage).

  ```bash
  mix run scripts/pre_commit_check.exs
  ```

- `check_type_safety.exs`: Runs Dialyzer.

  ```bash
  mix run scripts/check_type_safety.exs
  ```

- `check_documentation.exs`: Checks documentation consistency.

  ```bash
  mix run scripts/check_documentation.exs
  ```

- `check_style.exs`: Runs Credo.

  ```bash
  mix run scripts/check_style.exs
  ```

- `check_links.exs`: Checks for broken links in Markdown files.

  ```bash
  mix run scripts/check_links.exs
  ```

- `check_coverage.exs`: Checks test coverage.

  ```bash
  mix run scripts/check_coverage.exs
  ```

- `format_before_commit.sh`: Runs `mix format`. Use manually or in a hook.

  ```bash
  ./scripts/format_before_commit.sh
  ```

- `explain_credo_warning.exs`: Explains specific Credo warnings.

  ```bash
  mix run scripts/explain_credo_warning.exs [WarningName]
  ```

## Validation Scripts

Perform specific validation checks.

- `validate_performance.exs`: Validates performance against benchmarks.

  ```bash
  mix run scripts/validate_performance.exs
  ```

- `validate_accessibility.exs`: Validates accessibility standards.

  ```bash
  mix run scripts/validate_accessibility.exs
  ```

- `validate_e2e.exs`: Validates end-to-end test setup/results.

  ```bash
  mix run scripts/validate_e2e.exs
  ```

## Testing Scripts

Run various test suites.

### General Testing

- `run-local-tests.sh`: Runs the main local test suite (`mix test`).

  ```bash
  ./scripts/run-local-tests.sh
  ```

- `test_workflow.sh`: Executes a specific multi-step test workflow.

  ```bash
  ./scripts/test_workflow.sh
  ```

- `run_platform_tests.exs`: Runs platform-specific tests.

  ```bash
  mix run scripts/run_platform_tests.exs [PlatformArg]
  ```

### Dashboard/UI Testing

- `run_all_dashboard_tests.sh`: Runs all UI/dashboard-related tests.

  ```bash
  ./scripts/run_all_dashboard_tests.sh
  ```

- `run_dashboard_integration_test.sh`: Runs UI/dashboard integration tests.

  ```bash
  ./scripts/run_dashboard_integration_test.sh
  ```

- `test_dashboard_layout_integration.exs`: Specific layout integration tests.

  ```bash
  mix test test/integration/dashboard_layout_integration_test.exs # Example path
  ```

- `test_layout_persistence.exs`: Tests layout persistence.

  ```bash
  mix test test/integration/layout_persistence_test.exs # Example path
  ```

### Visualization Testing

- `run_visualization_tests.exs`: Runs visualization component tests.

  ```bash
  mix run scripts/run_visualization_tests.exs
  ```

- `test_visualization.exs`: Specific visualization tests.

  ```bash
  mix test test/visualization/visualization_test.exs # Example path
  ```

- `run_visualization_benchmark.exs`: Runs visualization benchmarks.

  ```bash
  mix run scripts/run_visualization_benchmark.exs
  ```

### Terminal Testing & Verification

- `native_terminal_test.sh`: Runs tests within a native terminal.

  ```bash
  ./scripts/native_terminal_test.sh
  ```

- `test_terminal_visualization.exs`: Tests visualization in a terminal context.

  ```bash
  mix test test/terminal/visualization_test.exs # Example path
  ```

- `run_native_terminal.sh`: Runs the app or tests in a native terminal.

  ```bash
  ./scripts/run_native_terminal.sh
  ```

- `verify_terminal_dimensions.exs`: Verifies terminal dimension handling.

  ```bash
  mix run scripts/verify_terminal_dimensions.exs
  ```

- `verify_terminal_compatibility.exs`: Checks terminal compatibility.

  ```bash
  mix run scripts/verify_terminal_compatibility.exs
  ```

### VS Code Testing

- `vs_code_test.sh`: Runs tests for the VS Code integration.

  ```bash
  ./scripts/vs_code_test.sh
  ```

- `test_vscode_visualization.exs`: Tests visualization in VS Code.

  ```bash
  mix test test/vscode/visualization_test.exs # Example path
  ```

## Database Scripts

Manage development/test database.

- `setup_db.sh`: Sets up database schemas, users, data.

  ```bash
  ./scripts/setup_db.sh
  ```

- `check_db.exs`: Checks database status/integrity.

  ```bash
  mix run scripts/check_db.exs
  ```

- `diagnose_db.exs`: Provides database diagnostics.

  ```bash
  mix run scripts/diagnose_db.exs
  ```

## Build & Release Scripts

Handle build and release tasks.

- `release.exs`: Creates project releases (tagging, artifacts).

  ```bash
  mix run scripts/release.exs [ReleaseArgs]
  ```

## Development Utilities

General development helpers.

- `run.exs`: Runs the main application or a specific entry point.

  ```bash
  mix run scripts/run.exs
  ```

- `generate_elements_table.exs`: Generates UI element documentation.

  ```bash
  mix run scripts/generate_elements_table.exs
  ```

- `run-local-actions.sh`: Simulates GitHub Actions locally using `act` (see [.github/workflows/README.md](../.github/workflows/README.md)).

  ```bash
  ./scripts/run-local-actions.sh [WorkflowName]
  ```

## Git Pre-Commit Hook

Set up a Git pre-commit hook (e.g., in `.git/hooks/pre-commit`) to automate checks:

```bash
#!/bin/sh
# Example pre-commit hook

echo "Running pre-commit checks..."

# Format code
./scripts/format_before_commit.sh || exit 1

# Run main checks
mix run scripts/pre_commit_check.exs || exit 1

echo "Pre-commit checks passed."
exit 0
```

Make the hook executable: `chmod +x .git/hooks/pre-commit`.

If checks fail, the commit is aborted. Fix issues and commit again.
