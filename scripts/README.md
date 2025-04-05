# Raxol Scripts

This directory contains various scripts used for development, testing, and quality assurance in the Raxol project.

## Pre-Commit Checks

The following scripts are used for pre-commit checks:

- `pre_commit_check.exs`: Main script that runs all pre-commit checks.
- `check_type_safety.exs`: Checks type safety.
- `check_documentation.exs`: Checks documentation consistency.
- `check_style.exs`: Checks code style.
- `check_links.exs`: Checks for broken links in documentation.
- `check_coverage.exs`: Checks test coverage.

## Validation Scripts

The following scripts are used for validation:

- `validate_performance.exs`: Validates performance metrics.
- `validate_accessibility.exs`: Validates accessibility standards.
- `validate_e2e.exs`: Validates end-to-end tests.

## Running Pre-Commit Checks

To run the pre-commit checks manually, use the following command:

```bash
mix run scripts/pre_commit_check.exs
```

## Running Individual Checks

You can also run individual checks using the following commands:

```bash
# Check type safety
mix run scripts/check_type_safety.exs

# Check documentation consistency
mix run scripts/check_documentation.exs

# Check code style
mix run scripts/check_style.exs

# Check for broken links in documentation
mix run scripts/check_links.exs

# Check test coverage
mix run scripts/check_coverage.exs

# Validate performance metrics
mix run scripts/validate_performance.exs

# Validate accessibility standards
mix run scripts/validate_accessibility.exs

# Validate end-to-end tests
mix run scripts/validate_e2e.exs
```

## Git Pre-Commit Hook

A Git pre-commit hook is provided to automatically run the pre-commit checks before each commit. The hook is located at `.git/hooks/pre-commit`.

If the pre-commit checks fail, the commit will be aborted, and you will need to fix the issues before committing.

## Other Scripts

- `run_platform_tests.exs`: Runs platform-specific tests
- `release.exs`: Handles the release process
- `generate_elements_table.exs`: Generates the elements table for documentation 