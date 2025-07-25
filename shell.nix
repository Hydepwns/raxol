{ pkgs ? import <nixpkgs> {} }:

let
  # Use specific nixpkgs version for reproducibility
  pinnedPkgs = import (pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "24.11";
    sha256 = "sha256-CqCX4JG7UiHvkrBTpYC3wcEurvbtTADLbo3Ns2CEoL8=";
  }) {};

  # Erlang/Elixir setup
  erlang = pinnedPkgs.beam.interpreters.erlang_25.override {
    enableHipe = true;
    enableDebugInfo = true;
  };
  elixir = pinnedPkgs.beam.packages.erlang_25.elixir_1_17;

  # Core dependencies
  buildInputs = with pinnedPkgs; [
    erlang elixir
    # Build essentials
    gcc gnumake cmake pkg-config
    # Database
    postgresql_15
    # System libraries
    libffi openssl zlib ncurses imagemagick
    # Development tools
    git nodejs_20
    # Python tools
    python3Packages.pip python3Packages.setuptools python3Packages.wheel
  ];

in pinnedPkgs.mkShell {
  inherit buildInputs;

  shellHook = ''
    echo "Setting up Raxol development environment..."
    
    # Environment setup
    export PATH="${erlang}/bin:${elixir}/bin:${pinnedPkgs.imagemagick}/bin:$PATH"
    export ERLANG_PATH=${erlang}
    export ELIXIR_PATH=${elixir}
    export ERL_EI_INCLUDE_DIR="${erlang}/lib/erlang/usr/include"
    export ERL_EI_LIBDIR="${erlang}/lib/erlang/usr/lib"
    export MIX_ENV=dev
    
    # PostgreSQL setup
    export PGDATA="$PWD/.postgres"
    mkdir -p /tmp/postgresql
    
    if [ ! -d "$PGDATA" ]; then
      initdb -D "$PGDATA" --auth=trust --no-locale
      pg_ctl -D "$PGDATA" -o "-k /tmp/postgresql" start
      sleep 1 && createuser -s postgres || true
      pg_ctl -D "$PGDATA" stop
    fi
    
    if ! pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
      pg_ctl -D "$PGDATA" -o "-k /tmp/postgresql" start
    fi
    
    echo "Environment ready! Run 'mix test' to verify setup."
  '';

  shellExitHook = ''
    if pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
      pg_ctl -D "$PGDATA" stop
    fi
  '';
} 