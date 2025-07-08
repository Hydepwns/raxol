{ pkgs ? import <nixpkgs> {} }:

let
  # Use a specific version of nixpkgs for reproducibility
  pinnedPkgs = import (pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "23.11";  # Use a stable release
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";  # This will be replaced by nix
  }) {};

  # Erlang and Elixir versions matching .tool-versions
  erlangVersion = "25.3.2.7";
  elixirVersion = "1.17.1";

  # Custom Erlang derivation with specific version
  erlang = pinnedPkgs.beam.interpreters.erlang_25.override {
    enableHipe = true;
    enableDebugInfo = true;
  };

  # Custom Elixir derivation
  elixir = pinnedPkgs.beam.packages.erlang_25.elixir_1_17;

  # Development tools
  devTools = with pinnedPkgs; [
    # Build tools
    gcc
    gnumake
    cmake
    pkg-config
    
    # Database
    postgresql_15
    
    # Image processing (for mogrify)
    imagemagick
    
    # Development utilities
    git
    curl
    wget
    
    # Node.js for esbuild and other JS tools
    nodejs_20
    
    # Additional system libraries that might be needed
    libffi
    openssl
    zlib
    ncurses
    
    # For termbox2_nif compilation
    glibc
    glibc.static
  ];

  # Python tools for some dependencies
  pythonTools = with pinnedPkgs.python3Packages; [
    pip
    setuptools
    wheel
  ];

in pinnedPkgs.mkShell {
  buildInputs = [
    erlang
    elixir
  ] ++ devTools ++ pythonTools;

  # Environment variables
  shellHook = ''
    echo "Setting up Raxol development environment..."
    
    # Set Erlang and Elixir paths
    export ERLANG_PATH=${erlang}
    export ELIXIR_PATH=${elixir}
    
    # Add Erlang and Elixir to PATH
    export PATH="${erlang}/bin:${elixir}/bin:$PATH"
    
    # Set up PostgreSQL
    export PGDATA="$PWD/.postgres"
    export PGHOST="$PWD/.postgres"
    export PGPORT=5432
    
    # Create PostgreSQL data directory if it doesn't exist
    if [ ! -d "$PGDATA" ]; then
      echo "Initializing PostgreSQL database..."
      initdb -D "$PGDATA" --auth=trust --no-locale
    fi
    
    # Start PostgreSQL if not running
    if ! pg_ctl -D "$PGDATA" status > /dev/null 2>&1; then
      echo "Starting PostgreSQL..."
      pg_ctl -D "$PGDATA" start
    fi
    
    # Set up environment for termbox2_nif compilation
    export ERL_EI_INCLUDE_DIR="${erlang}/lib/erlang/usr/include"
    export ERL_EI_LIBDIR="${erlang}/lib/erlang/usr/lib"
    export ERLANG_PATH="${erlang}"
    
    # Set up Node.js environment
    export NODE_PATH="${pinnedPkgs.nodejs_20}/lib/node_modules"
    
    # Set up ImageMagick for mogrify
    export MAGICK_HOME="${pinnedPkgs.imagemagick}"
    export PATH="${pinnedPkgs.imagemagick}/bin:$PATH"
    
    # Set up development environment
    export MIX_ENV=dev
    
    echo "Raxol development environment ready!"
    echo "Available commands:"
    echo "  mix deps.get          - Install dependencies"
    echo "  mix setup             - Setup the project"
    echo "  mix test              - Run tests"
    echo "  mix phx.server        - Start Phoenix server"
    echo "  pg_ctl -D $PGDATA stop - Stop PostgreSQL"
  '';

  # Cleanup hook
  shellExitHook = ''
    echo "Cleaning up..."
    if pg_ctl -D "$PGDATA" status > /dev/null 2>&1; then
      echo "Stopping PostgreSQL..."
      pg_ctl -D "$PGDATA" stop
    fi
  '';

  # Allow unfree packages (some Node.js packages might be unfree)
  allowUnfree = true;
  
  # Allow broken packages if needed
  allowBroken = false;
} 