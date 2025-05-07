---
title: Development Environment Setup
description: Setting up the Raxol development environment from source
date: 2023-04-04
author: Raxol Team
section: installation
tags: [installation, setup, development, contributing]
---

# Development Setup

This guide helps you set up your development environment for working on Raxol.

## Prerequisites

- Elixir 1.14 or higher
- Erlang/OTP 24 or higher
- Git
- A terminal emulator with ANSI support

## Installation

1. Clone the repository:

```bash
git clone https://github.com/Hydepwns/raxol.git
cd raxol
```

2. Install dependencies:

```bash
mix deps.get
```

3. Compile the project:

```bash
mix compile
```

## Running Tests

```bash
# Run all tests
mix test

# Run tests with coverage
mix coveralls

# Run static analysis
mix credo
mix dialyzer
```

## Running Examples

To run the main component showcase:

```bash
mix run examples/snippets/showcase/component_showcase.exs
```

Other examples are located within the `examples/` directory and can typically be run similarly.

## Troubleshooting

### Common Issues

1. **Termbox NIF Compilation**

If you encounter compilation errors related to Termbox NIF:

```bash
# Check that you have a C compiler installed
gcc --version

# Clean the build artifacts and recompile
mix deps.clean --all
mix deps.get
mix compile
```

2. **Terminal Display Issues**

If the terminal output appears corrupted after running an example:

```bash
# Reset your terminal
reset
```

3. **Erlang/OTP Build Failures on macOS (e.g., 'iterator' file not found)**

   If you are using `asdf` to manage Erlang versions on macOS and encounter build failures during `asdf install erlang <version>`, particularly with errors like `fatal error: 'iterator' file not found` or other C++ header issues, it might be due to problems with the Xcode Command Line Tools or conflicts between the system's `clang` compiler and one installed via Homebrew.

   **Symptoms:**

   - `asdf install erlang <version>` fails during the C/C++ compilation stage.
   - Build logs (often found in `~/.asdf/plugins/erlang/kerl-home/builds/asdf_<version>/otp_build_<version>.log`) show errors related to missing standard C++ headers (e.g., `<iterator>`, `<vector>`).

   **Potential Solution:**

   a. **Clean up any failed installation:**
   If a previous install attempt failed, `asdf` might still think the version is partially installed or corrupted. Manually remove the problematic installation directory:

   ```bash
   # Replace <version> with the actual Erlang version, e.g., 26.2.5
   rm -rf ~/.asdf/installs/erlang/<version>
   ```

   b. **Explicitly set C and C++ compilers to Homebrew's clang:**
   Before attempting the installation again, tell the build system to use `clang` and `clang++` from your Homebrew LLVM installation. This often provides a more complete and correctly configured C++ toolchain.

   ```bash
   export CC=/opt/homebrew/opt/llvm/bin/clang \
          CXX=/opt/homebrew/opt/llvm/bin/clang++

   # Then try installing Erlang again, e.g., for version 26.2.5:
   asdf install erlang 26.2.5
   asdf reshim erlang # Important to update shims after successful install
   ```

   Ensure that Homebrew and its `llvm` package are up to date (`brew update && brew upgrade llvm`).

   c. **Verify Xcode Command Line Tools:**
   As a general check, ensure your Xcode Command Line Tools are installed:

   ```bash
   xcode-select --install
   ```

   If issues persist after trying the `CC`/`CXX` export, a full reinstall of Command Line Tools might be considered as a more involved step.

## Editor Integration

### VS Code

For VS Code users, we recommend:

1. ElixirLS extension
2. Elixir Test Explorer
3. Using our provided `.vscode/settings.json` configuration
