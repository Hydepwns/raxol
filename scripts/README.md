# 🛠️ Raxol Scripts

Welcome! This directory contains helper scripts for development, testing, and quality assurance in Raxol.

---

## 🗂️ What's Inside

- **Pre-Commit & Quality Checks:**
  Scripts to ensure code quality before every commit.
- **Validation Scripts:**
  Tools for performance, accessibility, and end-to-end validation.
- **Testing Scripts:**
  Helpers for running and automating various test suites.
- **Database Scripts:**
  Utilities for managing the development/test database.
- **Build & Release Scripts:**
  Tools for building and releasing Raxol.
- **Development Utilities:**
  Miscellaneous helpers for day-to-day development.
- **Git Pre-Commit Hook:**
  Automates formatting and quality checks on commit.

---

## ✅ Pre-Commit & Quality Checks

- `pre_commit_check.exs` — Runs all checks (Dialyzer, Credo, Format, Docs, Links, Coverage).
- `check_type_safety.exs` — Runs Dialyzer.
- `check_documentation.exs` — Checks documentation consistency.
- `check_style.exs` — Runs Credo.
- `check_links.exs` — Checks for broken links in Markdown.
- `check_coverage.exs` — Checks test coverage.
- `format_before_commit.sh` — Runs `mix format`.
- `explain_credo_warning.exs` — Explains specific Credo warnings.

Run any script with:

```bash
mix run scripts/<script_name>.exs
# or
./scripts/<script_name>.sh
```

---

## 🧪 Validation & Testing Scripts

- `validate_performance.exs` — Validates performance benchmarks.
- `validate_accessibility.exs` — Checks accessibility standards.
- `validate_e2e.exs` — Validates end-to-end test setup/results.

### General Testing

- `run-local-tests.sh` — Runs the main test suite.
- `test_workflow.sh` — Executes a multi-step test workflow.
- `run_platform_tests.exs` — Runs platform-specific tests.

### Dashboard/UI Testing

- `run_all_dashboard_tests.sh` — Runs all UI/dashboard tests.
- `run_dashboard_integration_test.sh` — UI/dashboard integration tests.

### Visualization Testing

- `run_visualization_tests.exs` — Visualization component tests.
- `run_visualization_benchmark.exs` — Visualization benchmarks.

### Terminal Testing & Verification

- `native_terminal_test.sh` — Runs tests in a native terminal.
- `run_native_terminal.sh` — Runs the app/tests in a native terminal.
- `verify_terminal_dimensions.exs` — Verifies terminal dimension handling.
- `verify_terminal_compatibility.exs` — Checks terminal compatibility.

### VS Code Testing

- `vs_code_test.sh` — Tests for the VS Code integration.

---

## 🗄️ Database Scripts

- `setup_db.sh` — Sets up database schemas, users, and data.
- `check_db.exs` — Checks database status/integrity.
- `diagnose_db.exs` — Provides database diagnostics.

---

## 🚀 Build & Release Scripts

- `release.exs` — Creates project releases (tagging, artifacts).

---

## ⚙️ Development Utilities

- `run.exs` — Runs the main application or a specific entry point.
- `generate_elements_table.exs` — Generates UI element documentation.
- `run-local-actions.sh` — Simulates GitHub Actions locally.

---

## 🪝 Git Pre-Commit Hook

Install with:

```bash
./scripts/install_pre_commit.sh
```

This will:

- Format staged Elixir files with `mix format`
- Run basic code quality checks

If you have issues, check permissions or re-run the install script.

---

Happy scripting!
