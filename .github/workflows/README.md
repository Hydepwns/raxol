# GitHub Actions Workflows

This directory contains the GitHub Actions workflows for Raxol Terminal Emulator. These workflows handle continuous integration, testing, and releases.

## Workflow Files

- **`ci.yml`**: Main continuous integration workflow that runs on push/PR to main branches
- **`cross_platform_tests.yml`**: Cross-platform test workflow that verifies compatibility on Linux, macOS, and Windows
- **`ci-local.yml`**: Simplified CI workflow for local testing
- **`ci-local-deps.yml`**: Focused workflow for testing dependencies
- **`test-snyk.yml`**: Security testing with Snyk
- **`release.yml`**: Workflow for creating releases

## Local Testing with `act`

We use [act](https://github.com/nektos/act) to run GitHub Actions workflows locally. This helps debug workflows before pushing changes to the repository.

### Setup and Requirements

1. **Install act**:

   ```bash
   brew install act
   ```

2. **Docker/Orbstack**:

   - You need Docker or Orbstack running
   - We recommend Orbstack for macOS with ARM chips for better performance

3. **Configuration**:
   - `.actrc` in the project root contains configuration for act
   - Custom Docker images are available in `docker/`

### Running Workflows Locally

We provide a helper script to make it easier to run workflows:

```bash
# Basic usage (runs the CI workflow)
./scripts/run-local-actions.sh

# Run a specific workflow and job
./scripts/run-local-actions.sh -w cross_platform_tests.yml -j test

# Enable verbose debugging
./scripts/run-local-actions.sh -d

# Print help
./scripts/run-local-actions.sh -h
```

### Simplified Testing with dummy-test.yml

For quick verification of the GitHub Actions setup without running the full test suite:

```bash
# Run the dummy test workflow
./scripts/run-local-actions.sh -w dummy-test.yml -j test
```

The `dummy-test.yml` workflow:

- Uses mock Elixir and Node.js setups
- Simulates running tests without actual dependencies
- Provides a quick way to verify your GitHub Actions setup is working

This is especially useful when:

- Troubleshooting GitHub Actions configuration issues
- Verifying your local act setup is correct
- Testing new workflow steps without running the full test suite

### Tips for macOS with ARM Chips

When testing on macOS with Apple Silicon (M1/M2/M3):

1. Use Orbstack instead of Docker Desktop for better performance
2. Use our custom Docker images (elixir-arm64) for compatibility
3. Set the architecture flag in act: `--container-architecture linux/arm64`

### Custom Docker Images

For optimal compatibility and performance, we use custom Docker images:

1. **Build the custom image**:

   ```bash
   ./docker/build-docker-image.sh
   ```

2. This creates the `elixir-arm64:latest` image optimized for:
   - ARM64 architecture (M1/M2/M3 Macs)
   - Multiple Erlang/Elixir versions
   - All required dependencies

### Troubleshooting

Common issues:

1. **GitHub Authentication Issues**:

   - When seeing `authentication required: Support for password authentication was removed` errors, you need to provide a GitHub token
   - Set the token in your environment: `export GITHUB_TOKEN=your_token_here`
   - Or pass it directly: `GITHUB_TOKEN=your_token_here ./scripts/run-local-actions.sh ...`
   - For testing simple workflows without GitHub dependencies, use `dummy-test.yml`

2. **PostgreSQL connection errors**:

   - Check PostgreSQL is running locally on port 5433
   - For macOS, verify PostgreSQL was started with `brew services start postgresql@14`

3. **Docker/Orbstack connectivity**:

   - Ensure Docker/Orbstack is running
   - Check `docker ps` works without errors

4. **Permission issues**:

   - Ensure `./scripts/run-local-actions.sh` is executable: `chmod +x ./scripts/run-local-actions.sh`

5. **Architecture issues**:
   - If running on ARM Mac, ensure `--container-architecture linux/arm64` is in `.actrc`
   - Our CI workflows test on both Linux and macOS for cross-platform compatibility
   - For macOS, PostgreSQL is set up locally since GitHub Actions service containers only work on Linux
   - When testing locally on ARM chips, use the custom Docker images with ARM64 support

For more help, see the full [GitHub Actions documentation](https://docs.github.com/en/actions).
