# GitHub Actions Workflows

This directory contains GitHub Actions workflows for CI, testing, and releases.

## Workflow Files

- **`ci.yml`**: Main CI workflow (push/PR to main branches).
- **`cross_platform_tests.yml`**: Verifies compatibility on Linux, macOS, Windows.
- **`ci-local.yml`**: Simplified CI for local `act` testing.
- **`ci-local-deps.yml`**: Tests dependencies locally.
- **`test-snyk.yml`**: Security testing with Snyk.
- **`release.yml`**: Creates releases.
- **`dummy-test.yml`**: Quick workflow for verifying `act` setup.

## Local Testing with `act`

Use [act](https://github.com/nektos/act) to run workflows locally for debugging.

### Setup

1. **Install act**: `brew install act` (or other methods).
2. **Docker/Orbstack**: Ensure Docker or Orbstack is running (Orbstack recommended on macOS ARM).
3. **Configuration**: Review `.actrc` in project root. Custom Docker images in `/docker` may be used.

### Running Workflows Locally (`run-local-actions.sh`)

Use the helper script `./scripts/run-local-actions.sh`:

```bash
# Run the default CI workflow (ci.yml)
./scripts/run-local-actions.sh

# Run a specific workflow (-w) and job (-j)
./scripts/run-local-actions.sh -w cross_platform_tests.yml -j test_linux

# Enable verbose debugging (-d)
./scripts/run-local-actions.sh -d

# List available workflows and options (-h)
./scripts/run-local-actions.sh -h

# Run the dummy test to quickly verify setup
./scripts/run-local-actions.sh -w dummy-test.yml
```

The `dummy-test.yml` workflow uses mock setups for quick verification without running the full suite. It's useful for:

- Troubleshooting `act` or workflow configuration.
- Verifying local setup.
- Testing new workflow steps quickly.

### Tips for macOS ARM (M1/M2/M3)

- Use Orbstack for better performance.
- Use custom Docker images (built via `./docker/build-docker-image.sh`) if needed for ARM64 compatibility.
- Check `.actrc` for architecture flags like `--container-architecture linux/arm64`.

### Custom Docker Images

Build custom images (e.g., `elixir-arm64`) if needed:

```bash
./docker/build-docker-image.sh
```

These images can provide specific Erlang/Elixir versions or pre-installed dependencies optimized for ARM64.

### Troubleshooting

- **GitHub Authentication**: If seeing `authentication required` errors, provide a token:
  - `export GITHUB_TOKEN=your_personal_access_token`
  - Or pass directly: `GITHUB_TOKEN=... ./scripts/run-local-actions.sh ...`
  - Use `dummy-test.yml` if the workflow doesn't require GitHub access.
- **PostgreSQL Connection (macOS)**: Ensure PostgreSQL (e.g., `postgresql@14`) is running locally (`brew services start postgresql@14`). Port 5433 is often used in tests.
- **Docker/Orbstack**: Ensure the daemon is running (`docker ps`).
- **Permissions**: Make scripts executable (`chmod +x ./scripts/run-local-actions.sh`).
- **Architecture**: Ensure correct architecture flags in `.actrc` if on ARM.

Refer to the official [act documentation](https://github.com/nektos/act) and [GitHub Actions documentation](https://docs.github.com/en/actions) for more details.
