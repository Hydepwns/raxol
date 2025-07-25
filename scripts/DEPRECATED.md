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

## Note
The original scripts remain for now to ensure compatibility. They will be removed in a future phase once the migration is complete.