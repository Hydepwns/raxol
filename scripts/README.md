# Raxol Scripts

This directory contains various scripts used for development, testing, and quality assurance in the Raxol project.

## Table of Contents

- [Pre-Commit & Quality Checks](#pre-commit--quality-checks)
- [Validation Scripts](#validation-scripts)
- [Testing Scripts](#testing-scripts)
  - [General Testing](#general-testing)
  - [Dashboard Testing](#dashboard-testing)
  - [Visualization Testing](#visualization-testing)
  - [Terminal Testing & Verification](#terminal-testing--verification)
  - [VS Code Testing](#vs-code-testing)
- [Database Scripts](#database-scripts)
- [Build & Release Scripts](#build--release-scripts)
- [Development Utilities](#development-utilities)
- [Git Pre-Commit Hook](#git-pre-commit-hook)

## Pre-Commit & Quality Checks

These scripts ensure code quality, style, and consistency before committing changes.

- `pre_commit_check.exs`: Main script that runs all applicable pre-commit checks below.
  ```bash
  mix run scripts/pre_commit_check.exs
  ```
- `check_type_safety.exs`: Checks type safety using Dialyzer.
  ```bash
  mix run scripts/check_type_safety.exs
  ```
- `check_documentation.exs`: Checks documentation consistency (e.g., module attributes).
  ```bash
  mix run scripts/check_documentation.exs
  ```
- `check_style.exs`: Checks code style using Credo.
  ```bash
  mix run scripts/check_style.exs
  ```
- `check_links.exs`: Checks for broken links in documentation files.
  ```bash
  mix run scripts/check_links.exs
  ```
- `check_coverage.exs`: Checks test coverage percentage. (Leverages `check_coverage.js`)
  ```bash
  mix run scripts/check_coverage.exs
  ```
- `check_coverage.js`: Helper script for coverage calculation/reporting (likely used by `check_coverage.exs`).
- `format_before_commit.sh`: Formats Elixir code using `mix format`. Can be used as a pre-commit hook or manually.
  ```bash
  ./scripts/format_before_commit.sh
  ```
- `explain_credo_warning.exs`: Provides explanations for specific Credo warnings.
  ```bash
  mix run scripts/explain_credo_warning.exs [WarningName]
  ```

## Validation Scripts

These scripts perform specific validation checks beyond standard testing.

- `validate_performance.exs`: Validates performance metrics against defined benchmarks.
  ```bash
  mix run scripts/validate_performance.exs
  ```
- `validate_accessibility.exs`: Validates accessibility standards compliance.
  ```bash
  mix run scripts/validate_accessibility.exs
  ```
- `validate_e2e.exs`: Validates end-to-end test results or setup.
  ```bash
  mix run scripts/validate_e2e.exs
  ```

## Testing Scripts

Scripts for running various test suites and scenarios.

### General Testing

- `run-local-tests.sh`: Runs the main local test suite.
  ```bash
  ./scripts/run-local-tests.sh
  ```
- `test_workflow.sh`: Executes a specific test workflow, potentially involving multiple steps or integrations.
  ```bash
  ./scripts/test_workflow.sh
  ```
- `run_platform_tests.exs`: Runs tests specific to different platforms or environments.
  ```bash
  mix run scripts/run_platform_tests.exs [PlatformArg]
  ```

### Dashboard Testing

- `run_all_dashboard_tests.sh`: Runs all tests related to the dashboard features.
  ```bash
  ./scripts/run_all_dashboard_tests.sh
  ```
- `run_dashboard_integration_test.sh`: Runs integration tests specifically for the dashboard.
  ```bash
  ./scripts/run_dashboard_integration_test.sh
  ```
- `test_dashboard_layout_integration.exs`: Tests the integration of dashboard layout components.
  ```bash
  mix test scripts/test_dashboard_layout_integration.exs # Or mix run? Verify usage
  ```
- `test_layout_persistence.exs`: Tests the persistence of layout configurations.
  ```bash
  mix test scripts/test_layout_persistence.exs # Or mix run? Verify usage
  ```

### Visualization Testing

- `run_visualization_tests.exs`: Runs tests specifically for the visualization components.
  ```bash
  mix run scripts/run_visualization_tests.exs
  ```
- `test_visualization.exs`: Contains specific tests for visualization logic.
  ```bash
  mix test scripts/test_visualization.exs # Or mix run? Verify usage
  ```
- `run_visualization_benchmark.exs`: Runs benchmarks for visualization performance.
  ```bash
  mix run scripts/run_visualization_benchmark.exs
  ```

### Terminal Testing & Verification

- `native_terminal_test.sh`: Runs tests within a native terminal environment.
  ```bash
  ./scripts/native_terminal_test.sh
  ```
- `test_terminal_visualization.exs`: Tests visualization rendering in a standard terminal context.
  ```bash
  mix test scripts/test_terminal_visualization.exs # Or mix run? Verify usage
  ```
- `run_native_terminal.sh`: Runs the application or specific tests in a native terminal.
  ```bash
  ./scripts/run_native_terminal.sh
  ```
- `verify_terminal_dimensions.exs`: Verifies or tests behavior related to terminal dimensions.
  ```bash
  mix run scripts/verify_terminal_dimensions.exs
  ```
- `verify_terminal_compatibility.exs`: Checks terminal compatibility features.
  ```bash
  mix run scripts/verify_terminal_compatibility.exs
  ```

### VS Code Testing

- `vs_code_test.sh`: Runs tests specifically for the VS Code integrated terminal or extension environment.
  ```bash
  ./scripts/vs_code_test.sh
  ```
- `test_vscode_visualization.exs`: Tests visualization rendering within the VS Code environment.
  ```bash
  mix test scripts/test_vscode_visualization.exs # Or mix run? Verify usage
  ```

## Database Scripts

Scripts for setting up and managing the development/test database.

- `setup_db.sh`: Sets up the necessary database schemas, users, or initial data.
  ```bash
  ./scripts/setup_db.sh
  ```
- `check_db.exs`: Checks the status or integrity of the database connection and schema.
  ```bash
  mix run scripts/check_db.exs
  ```
- `diagnose_db.exs`: Provides diagnostic information about the database setup or potential issues.
  ```bash
  mix run scripts/diagnose_db.exs
  ```

## Build & Release Scripts

Scripts related to the build and release process.

- `release.exs`: Handles tasks related to creating project releases (e.g., tagging, building artifacts).
  ```bash
  mix run scripts/release.exs [ReleaseArgs]
  ```

## Development Utilities

General helper scripts for development tasks.

- `run.exs`: A simple script likely used to run the main application or a specific entry point.
  ```bash
  mix run scripts/run.exs
  ```
- `generate_elements_table.exs`: Generates a table or documentation related to UI elements.
  ```bash
  mix run scripts/generate_elements_table.exs
  ```
- `run-local-actions.sh`: Simulates GitHub Actions workflows locally, possibly using `act`.
  ```bash
  ./scripts/run-local-actions.sh [WorkflowName]
  ```

## Git Pre-Commit Hook

A Git pre-commit hook can be set up to automatically run checks before each commit. You can often use `format_before_commit.sh` or invoke `mix run scripts/pre_commit_check.exs` within your `.git/hooks/pre-commit` file.

If the pre-commit checks fail, the commit will be aborted, and you will need to fix the issues before committing again.
