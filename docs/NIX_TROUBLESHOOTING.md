# Nix Troubleshooting Guide

This guide helps you resolve common issues when using the Nix development environment for Raxol.

## Common Issues and Solutions

### 1. Shell Not Loading

**Problem**: `nix-shell` fails to load or shows errors.

**Solutions**:

```bash
# Update Nix channels
nix-channel --update
nix-env -u

# Clear Nix cache
nix-store --gc

# Rebuild the shell
nix-shell --run "echo 'Shell rebuilt'"
```

### 2. PostgreSQL Issues

**Problem**: PostgreSQL fails to start or connect.

**Solutions**:

```bash
# Check if PostgreSQL is running
pg_ctl -D $PGDATA status

# If not running, start it
pg_ctl -D $PGDATA start

# If there are permission issues, reinitialize
rm -rf .postgres
nix-shell  # This will reinitialize the database
```

### 3. Native Compilation Errors

**Problem**: `termbox2_nif` or other native dependencies fail to compile.

**Solutions**:

```bash
# Clean all dependencies
mix deps.clean --all

# Reinstall dependencies
mix deps.get

# Recompile with verbose output
mix deps.compile --verbose

# Check environment variables
echo $ERL_EI_INCLUDE_DIR
echo $ERL_EI_LIBDIR
echo $ERLANG_PATH
```

### 4. Permission Issues

**Problem**: Permission denied errors when accessing files or directories.

**Solutions**:

```bash
# Check file permissions
ls -la

# Fix permissions if needed
chmod +x scripts/*
chmod 755 priv/

# If using WSL or similar, ensure proper ownership
sudo chown -R $USER:$USER .
```

### 5. Memory Issues

**Problem**: Out of memory errors during compilation.

**Solutions**:

```bash
# Increase Nix memory limit
export NIX_BUILD_CORES=1
export NIX_REMOTE=daemon

# Or use a swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 6. Network Issues

**Problem**: Cannot download packages or dependencies.

**Solutions**:

```bash
# Check Nix configuration
cat ~/.config/nix/nix.conf

# Use a different mirror
export NIXPKGS_ALLOW_UNFREE=1
export NIXPKGS_ALLOW_BROKEN=1

# Or use a local cache
nix-copy-closure --from cache.example.com /nix/store/...
```

### 7. Version Conflicts

**Problem**: Version mismatches between Erlang/Elixir and dependencies.

**Solutions**:

```bash
# Check versions
elixir --version
erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell

# Ensure you're using the Nix environment
which elixir
which erl

# Should point to Nix store paths, not system paths
```

### 8. Asset Compilation Issues

**Problem**: esbuild, sass, or other asset tools fail.

**Solutions**:

```bash
# Check Node.js installation
node --version
npm --version

# Reinstall Node.js tools
mix assets.setup

# Or manually install
npm install -g esbuild
npm install -g sass
```

### 9. Test Failures

**Problem**: Tests fail in the Nix environment.

**Solutions**:

```bash
# Ensure database is running
pg_ctl -D $PGDATA status

# Reset test database
mix ecto.reset

# Run tests with verbose output
mix test --trace

# Check test configuration
cat config/test.exs
```

### 10. IDE/Editor Issues

**Problem**: IDE cannot find Elixir/Erlang or other tools.

**Solutions**:

```bash
# Use direnv for automatic environment loading
echo "use nix" > .envrc
direnv allow

# Or manually set paths in your IDE
export PATH="$PWD/.nix-profile/bin:$PATH"
export ERL_LIBS="$PWD/.nix-profile/lib/erlang/lib"
```

## Environment Verification

Run this script to verify your Nix environment is properly set up:

```bash
#!/bin/bash
echo "=== Nix Environment Verification ==="

echo "1. Checking Nix installation..."
nix --version

echo "2. Checking Erlang..."
erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell

echo "3. Checking Elixir..."
elixir --version

echo "4. Checking PostgreSQL..."
pg_ctl -D $PGDATA status

echo "5. Checking environment variables..."
echo "ERLANG_PATH: $ERLANG_PATH"
echo "ELIXIR_PATH: $ELIXIR_PATH"
echo "ERL_EI_INCLUDE_DIR: $ERL_EI_INCLUDE_DIR"
echo "ERL_EI_LIBDIR: $ERL_EI_LIBDIR"
echo "PGDATA: $PGDATA"
echo "MIX_ENV: $MIX_ENV"

echo "6. Checking build tools..."
which gcc
which make
which cmake
which pkg-config

echo "7. Checking Node.js..."
node --version
npm --version

echo "=== Verification Complete ==="
```

## Getting Help

If you're still experiencing issues:

1. **Check the logs**: Look for error messages in the terminal output
2. **Search existing issues**: Check the [GitHub issues](https://github.com/Hydepwns/raxol/issues)
3. **Create a new issue**: Include your system information and the exact error message
4. **Join the community**: Ask questions in the project discussions

### System Information to Include

When reporting issues, include:

```bash
# System information
uname -a
cat /etc/os-release

# Nix information
nix --version
nix-channel --list

# Environment information
env | grep -E "(ERL|ELIXIR|PG|MIX|NIX)"

# Error logs
mix deps.compile --verbose 2>&1 | tail -20
```

## Alternative Solutions

If Nix continues to cause issues, you can:

1. **Use Docker**: Create a Docker environment with the same dependencies
2. **Manual installation**: Install dependencies manually following the [Installation Guide](../examples/guides/01_getting_started/install.md)
3. **Use asdf**: Use asdf version manager with the versions specified in `.tool-versions`

Remember that the Nix environment is designed to provide a consistent, reproducible development experience. Most issues can be resolved by following the solutions above. 