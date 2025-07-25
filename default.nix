{ pkgs ? import <nixpkgs> {} }:

let
  # Use same pinned packages as shell.nix
  pinnedPkgs = import (pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "24.11";
    sha256 = "sha256-CqCX4JG7UiHvkrBTpYC3wcEurvbtTADLbo3Ns2CEoL8=";
  }) {};

  # Import shell configuration for consistency
  shell = import ./shell.nix { pkgs = pinnedPkgs; };
  
  # Reuse Erlang/Elixir from shell
  erlang = pinnedPkgs.beam.interpreters.erlang_25.override {
    enableHipe = true;
    enableDebugInfo = true;
  };
  elixir = pinnedPkgs.beam.packages.erlang_25.elixir_1_17;

in pinnedPkgs.stdenv.mkDerivation {
  name = "raxol";
  version = "0.5.0";
  
  src = ./.;
  
  buildInputs = [ erlang elixir ] ++ (with pinnedPkgs; [ gcc gnumake ]);
  
  # Production environment
  MIX_ENV = "prod";
  ERLANG_PATH = erlang;
  ELIXIR_PATH = elixir;
  ERL_EI_INCLUDE_DIR = "${erlang}/lib/erlang/usr/include";
  ERL_EI_LIBDIR = "${erlang}/lib/erlang/usr/lib";
  
  buildPhase = ''
    export PATH="${erlang}/bin:${elixir}/bin:$PATH"
    mix deps.get --only prod
    mix compile
  '';
  
  installPhase = ''
    mkdir -p $out/{bin,lib}
    cp -r _build lib priv mix.exs mix.lock $out/
    
    # Create launcher script
    cat > $out/bin/raxol <<EOF
#!/bin/bash
export PATH="${erlang}/bin:${elixir}/bin:\$PATH"
cd $out && exec mix "\$@"
EOF
    chmod +x $out/bin/raxol
  '';
  
  meta = with pinnedPkgs.lib; {
    description = "Modern TUI framework for Elixir";
    homepage = "https://github.com/Hydepwns/raxol";
    license = licenses.mit;
    platforms = platforms.unix;
  };
} 