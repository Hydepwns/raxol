{ pkgs ? import <nixpkgs> {} }:

let
  # Import the shell configuration
  shell = import ./shell.nix { inherit pkgs; };
  
  # Get the same pinned packages
  pinnedPkgs = import (pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "23.11";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  }) {};

  # Erlang and Elixir
  erlang = pinnedPkgs.beam.interpreters.erlang_25.override {
    enableHipe = true;
    enableDebugInfo = true;
  };
  elixir = pinnedPkgs.beam.packages.erlang_25.elixir_1_17;

in pinnedPkgs.stdenv.mkDerivation {
  name = "raxol";
  version = "0.5.0";
  
  src = ./.;
  
  buildInputs = shell.buildInputs;
  
  # Set up environment variables
  ERLANG_PATH = erlang;
  ELIXIR_PATH = elixir;
  ERL_EI_INCLUDE_DIR = "${erlang}/lib/erlang/usr/include";
  ERL_EI_LIBDIR = "${erlang}/lib/erlang/usr/lib";
  MIX_ENV = "prod";
  
  buildPhase = ''
    # Add Erlang and Elixir to PATH
    export PATH="${erlang}/bin:${elixir}/bin:$PATH"
    
    # Install dependencies
    mix deps.get
    mix deps.compile
    
    # Compile the project
    mix compile
  '';
  
  installPhase = ''
    # Create output directory
    mkdir -p $out
    
    # Copy compiled artifacts
    cp -r _build $out/
    cp -r lib $out/
    cp -r priv $out/
    cp mix.exs $out/
    cp mix.lock $out/
    
    # Create a wrapper script
    cat > $out/bin/raxol <<EOF
    #!${pinnedPkgs.bash}/bin/bash
    export PATH="${erlang}/bin:${elixir}/bin:\$PATH"
    export ERLANG_PATH="${erlang}"
    export ELIXIR_PATH="${elixir}"
    export ERL_EI_INCLUDE_DIR="${erlang}/lib/erlang/usr/include"
    export ERL_EI_LIBDIR="${erlang}/lib/erlang/usr/lib"
    cd $out
    exec mix "\$@"
    EOF
    chmod +x $out/bin/raxol
  '';
  
  meta = {
    description = "A modern toolkit for building terminal user interfaces (TUIs) in Elixir";
    homepage = "https://github.com/Hydepwns/raxol";
    license = pinnedPkgs.lib.licenses.mit;
    maintainers = ["DROO AMOR"];
    platforms = pinnedPkgs.lib.platforms.unix;
  };
} 