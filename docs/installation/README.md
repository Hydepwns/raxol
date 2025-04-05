---
title: Installation Documentation
description: Documentation for installing and setting up Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: installation
tags: [installation, setup, documentation]
---

# Installation Documentation

This directory contains documentation for installing and setting up the Raxol Terminal Emulator.

## Available Documentation

- [Installation Guide](Installation.md) - Detailed instructions for installing Raxol
- [Version Management](VersionManagement.md) - Managing different versions of Raxol
- [Cross-Platform Support](CrossPlatformSupport.md) - Platform-specific installation instructions

## Quick Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/raxol.git
   cd raxol
   ```

2. Install dependencies:
   ```bash
   mix deps.get
   ```

3. Build the project:
   ```bash
   mix compile
   ```

4. Run the tests:
   ```bash
   mix test
   ```

## System Requirements

- Elixir 1.14 or later
- Erlang/OTP 25 or later
- Node.js 16 or later (for JavaScript components)
- npm 8 or later (for JavaScript components)

## Platform-Specific Instructions

### Linux

```bash
# Install Elixir and Erlang
sudo apt-get update
sudo apt-get install elixir erlang

# Install Node.js and npm
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt-get install -y nodejs

# Clone and build Raxol
git clone https://github.com/yourusername/raxol.git
cd raxol
mix deps.get
mix compile
```

### macOS

```bash
# Install Elixir and Erlang using Homebrew
brew install elixir

# Install Node.js and npm
brew install node

# Clone and build Raxol
git clone https://github.com/yourusername/raxol.git
cd raxol
mix deps.get
mix compile
```

### Windows

1. Install [Elixir](https://elixir-lang.org/install.html#windows)
2. Install [Node.js](https://nodejs.org/en/download/)
3. Clone and build Raxol:
   ```bash
   git clone https://github.com/yourusername/raxol.git
   cd raxol
   mix deps.get
   mix compile
   ```

## Troubleshooting

If you encounter any issues during installation, please check the [Installation Guide](Installation.md) for detailed troubleshooting steps. 