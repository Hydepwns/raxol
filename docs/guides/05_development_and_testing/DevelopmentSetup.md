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

## Editor Integration

### VS Code

For VS Code users, we recommend:

1. ElixirLS extension
2. Elixir Test Explorer
3. Using our provided `.vscode/settings.json` configuration
