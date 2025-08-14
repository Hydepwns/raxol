{ pkgs ? import <nixpkgs> {} }:

let
  # Core dependencies
  buildInputs = with pkgs; [
    elixir
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

in pkgs.mkShell {
  inherit buildInputs;

  shellHook = ''
    echo "Setting up Raxol development environment..."
    
    # Environment setup
    export PATH="${pkgs.elixir}/bin:${pkgs.imagemagick}/bin:$PATH"
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