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

_Raxol 0.8.0 is a full-stack terminal application framework with web interface support, plugin system, and enterprise features. Make sure you are using the latest version for the best experience!_

## Prerequisites

- Elixir 1.17.1 or higher
- Erlang/OTP 25.3.2.7 or higher
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
   # It's also good to ensure asdf can correctly uninstall the version if possible:
   asdf uninstall erlang <version>
   ```

   _Note: If `asdf uninstall` fails, updating `asdf` itself (`brew upgrade asdf` if installed via Homebrew, or `asdf update`) might resolve the uninstall issue._

   b. **Explicitly set C and C++ compilers and flags using Homebrew's LLVM/Clang:**
   Before attempting the installation again, tell the build system to use `clang` and `clang++` from your Homebrew LLVM installation. This often provides a more complete and correctly configured C++ toolchain.

   First, ensure `llvm` is installed and up-to-date via Homebrew:

   ```bash
   brew install llvm
   # or if already installed:
   brew upgrade llvm
   ```

   Then, use the following environment variables when running `asdf install erlang`:

   ```bash
   export CC=/opt/homebrew/opt/llvm/bin/clang \
          CXX=/opt/homebrew/opt/llvm/bin/clang++ \
          LDFLAGS="-L/opt/homebrew/opt/llvm/lib" \
          CPPFLAGS="-I/opt/homebrew/opt/llvm/include"

   # Then try installing Erlang again, e.g., for version 27.0.1:
   asdf install erlang 27.0.1
   asdf reshim erlang # Important to update shims after successful install
   ```

   _Remember to unset these environment variables or open a new terminal session if you don't want them to persist for other operations._

   c. **Verify Xcode Command Line Tools:**
   As a general check, ensure your Xcode Command Line Tools are installed:

   ```bash
   xcode-select --install
   ```

   If issues persist after trying the `CC`/`CXX` export, a full reinstall of Command Line Tools might be considered as a more involved step.

4. **Mox Compilation Error (`Mox.__using__/1 is undefined or private`)**

   When using Mox for testing, particularly version 1.2.0 or newer, you might encounter a compilation error:
   `** (UndefinedFunctionError) function Mox.__using__/1 is undefined or private`

   **Symptoms:**

   - `mix test` fails with the `Mox.__using__/1 is undefined` error.
   - The error points to the line where `use Mox` is located in a test module.

   **Status & Solution:**

   - This issue was observed with Mox v1.2.0. The compilation error `(UndefinedFunctionError) function Mox.__using__/1 is undefined or private` occurs because the `Mox` module does not define a `__using__/1` macro.
   - The statement `use Mox` in test files triggers this error.
   - **Solution:** Remove `use Mox` from your test files. Instead, use `import Mox` to bring Mox functions (like `expect/3`, `stub/3`, `verify!/1`) into the current scope. Functions like `Mox.defmock/2` should continue to be called explicitly or imported if preferred (e.g., `import Mox, only: [defmock: 2]` or rely on the general `import Mox`). Ensure `Mox.start_link_ownership()` is used in `test_helper.exs` as appropriate for Mox v1.2.0+.

## Editor Integration

### VS Code

For VS Code users, we recommend:

1. ElixirLS extension
2. Elixir Test Explorer
3. Using our provided `.vscode/settings.json` configuration
