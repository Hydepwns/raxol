# Development Guide

This guide explains how to set up and work with the Raxol development environment using Nix.

## Prerequisites

- [Nix](https://nixos.org/download.html) installed on your system
- [direnv](https://direnv.net/) (optional, but recommended)

## Quick Setup

1. **Clone the repository**:

   ```bash
   git clone https://github.com/Hydepwns/raxol.git
   cd raxol
   ```

2. **Enter the development environment**:

   ```bash
   nix-shell
   ```

   Or if you have direnv installed, it will automatically load the environment when you `cd` into the project.

3. **Install dependencies**:

   ```bash
   mix deps.get
   git submodule update --init --recursive
   ```

4. **Setup the project**:

   ```bash
   mix setup
   ```

## What's Included

The Nix environment provides:

- **Erlang 25.3.2.7** and **Elixir 1.17.1** (matching `.tool-versions`)
- **PostgreSQL 15** with automatic setup and management
- **Build tools**: gcc, make, cmake, pkg-config
- **Image processing**: ImageMagick (for mogrify)
- **Node.js 20** (for esbuild and other JS tools)
- **Development utilities**: git, curl, wget
- **System libraries**: libffi, openssl, zlib, ncurses

## Development Workflow

### Starting the Environment

```bash
# Enter the shell
nix-shell

# The shell will automatically:
# - Set up Erlang/Elixir paths
# - Initialize PostgreSQL if needed
# - Start PostgreSQL if not running
# - Set up environment variables for termbox2_nif compilation
```

### Common Commands

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Start Phoenix server
mix phx.server

# Run credo (code quality)
mix credo

# Generate documentation
mix docs

# Stop PostgreSQL (when done)
pg_ctl -D $PGDATA stop
```

### Database Management

The Nix environment automatically manages a local PostgreSQL instance:

- **Data directory**: `$PWD/.postgres`
- **Port**: 5432
- **Authentication**: Trust (no password required)

```bash
# Check database status
pg_ctl -D $PGDATA status

# Stop database
pg_ctl -D $PGDATA stop

# Start database
pg_ctl -D $PGDATA start

# Reset database
mix ecto.reset
```

### Building Native Dependencies

The `termbox2_nif` dependency requires C compilation. The environment is configured to handle this automatically:

```bash
# The environment variables are set automatically:
# - ERL_EI_INCLUDE_DIR
# - ERL_EI_LIBDIR
# - ERLANG_PATH

# Compile dependencies
mix deps.compile
```

## Troubleshooting

### PostgreSQL Issues

If PostgreSQL fails to start:

```bash
# Remove the data directory and reinitialize
rm -rf .postgres
nix-shell  # This will reinitialize the database
```

### Compilation Issues

If you encounter compilation errors:

```bash
# Clean and rebuild
mix deps.clean --all
mix deps.get
mix deps.compile
```

### Nix Cache Issues

If you encounter Nix cache issues:

```bash
# Update Nix cache
nix-channel --update
nix-env -u

# Or rebuild the shell
nix-shell --run "echo 'Shell rebuilt'"
```

## Environment Variables

The following environment variables are set automatically:

- `ERLANG_PATH`: Path to Erlang installation
- `ELIXIR_PATH`: Path to Elixir installation
- `ERL_EI_INCLUDE_DIR`: Erlang include directory
- `ERL_EI_LIBDIR`: Erlang library directory
- `PGDATA`: PostgreSQL data directory
- `PGHOST`: PostgreSQL host
- `PGPORT`: PostgreSQL port (5432)
- `MIX_ENV`: Mix environment (dev)
- `MAGICK_HOME`: ImageMagick installation path

## Contributing

When contributing to Raxol:

1. Use the Nix environment for consistent development
2. Run tests before submitting: `mix test`
3. Check code quality: `mix credo`
4. Update documentation if needed
5. Follow the existing code style

## Advanced Usage

### Custom Nix Configuration

You can customize the Nix environment by modifying `shell.nix`:

```nix
# Add additional packages
devTools = with pinnedPkgs; [
  # ... existing tools ...
  your-custom-package
];
```

### Building with Nix

You can also build the project using Nix:

```bash
# Build the project
nix-build

# The result will be in ./result/
```

### Flakes (Experimental)

If you prefer using Nix flakes, you can create a `flake.nix` file based on the existing `shell.nix` and `default.nix` files.

## Support

If you encounter issues with the Nix setup:

1. Check the [Nix documentation](https://nixos.org/guides/)
2. Verify your Nix installation: `nix --version`
3. Try updating Nix: `nix-channel --update`
4. Open an issue on GitHub with details about your environment
