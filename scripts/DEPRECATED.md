# Deprecated Scripts

The following scripts have been consolidated into `dev.sh` for better maintainability:

## Replaced by `./dev.sh test`
- `run-local-tests.sh` → `./dev.sh test`
- `native_terminal_test.sh` → `./dev.sh test terminal`

## Replaced by `./dev.sh test-all`  
- `run_all_dashboard_tests.sh` → `./dev.sh test-all`
- `run_dashboard_integration_test.sh` → `./dev.sh test-all`
- `test_workflow.sh` → `./dev.sh test-all`

## Replaced by `./dev.sh check`
- `format_before_commit.sh` → `./dev.sh format`
- Individual check scripts are still available but `./dev.sh check` runs them all

## Replaced by `./dev.sh setup`
- Combined environment setup functionality

## Migration Guide

| Old Command | New Command |
|-------------|-------------|
| `./scripts/run-local-tests.sh` | `./scripts/dev.sh test` |
| `./scripts/run_all_dashboard_tests.sh` | `./scripts/dev.sh test-all` |
| `./scripts/format_before_commit.sh` | `./scripts/dev.sh format` |
| `./scripts/setup_db.sh` | `./scripts/dev.sh db setup` |

## Archived Scripts

The following deprecated scripts have been moved to `scripts/archived/` subdirectories:

### Moved to `scripts/archived/deprecated-by-dev-sh/`
- `run-local-tests.sh` - Replaced by `./dev.sh test`
- `native_terminal_test.sh` - Replaced by `./dev.sh test terminal`  
- `run_all_dashboard_tests.sh` - Replaced by `./dev.sh test-all`
- `run_dashboard_integration_test.sh` - Replaced by `./dev.sh test-all`
- `test_workflow.sh` - Replaced by `./dev.sh test-all`
- `format_before_commit.sh` - Replaced by `./dev.sh format`

### Moved to `scripts/archived/sprint-refactoring/`
Sprint-specific refactoring scripts that are no longer needed:
- `sprint9_analysis.exs`
- `sprint9_automated_refactor.exs`
- `sprint9_pattern_matching.exs`
- `fix_module_names.exs`
- `fix_refactored_references.exs`
- `fix_remaining_references.exs`
- `migrate_to_refactored.exs`
- `refactor_module_names.exs`
- `replace_with_refactored.exs`
- `rename_manager_references.sh`
- `rename_phase3_duplicates.sh`
- `rename_terminal_managers.sh`

### Moved to `scripts/archived/old-experiments/`
Old test and experimental scripts:
- `test_hot_reload_refactoring.exs`
- `test_safe_emulator_refactoring.exs`

## Note
These scripts have been archived to maintain a clean and organized scripts directory. They can still be accessed in the `scripts/archived/` subdirectories if needed for reference.