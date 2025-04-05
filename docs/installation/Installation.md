---
title: Installation Guide
description: Comprehensive guide for installing Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: installation
tags: [installation, guide, setup]
---

# Raxol Installation Guide

This guide provides detailed instructions for installing, configuring, and troubleshooting Raxol, a terminal UI framework for Elixir.

## System Requirements

- **Operating System**: macOS, Linux (Debian, Ubuntu, RHEL), or Windows
- **Terminal**: A terminal that supports ANSI color codes and UTF-8
- **Color Support**: For the best experience, a terminal with true color support is recommended

## Installation Methods

### Method 1: Pre-built Binaries (Recommended)

The easiest way to install Raxol is by using pre-built binaries for your operating system.

#### macOS

```bash
# Using Homebrew
brew tap username/raxol
brew install raxol

# Or download and install manually
curl -L https://github.com/username/raxol/releases/latest/download/raxol-latest-macos.tar.gz | tar xz -C /usr/local/bin
chmod +x /usr/local/bin/raxol
```

#### Linux

```bash
# Debian/Ubuntu
wget https://github.com/username/raxol/releases/latest/download/raxol-latest-linux.deb
sudo dpkg -i raxol-latest-linux.deb

# RHEL/Fedora
wget https://github.com/username/raxol/releases/latest/download/raxol-latest-linux.rpm
sudo rpm -i raxol-latest-linux.rpm

# Or download and install manually
curl -L https://github.com/username/raxol/releases/latest/download/raxol-latest-linux.tar.gz | tar xz -C /usr/local/bin
chmod +x /usr/local/bin/raxol
```

#### Windows

1. Download the latest Windows installer from [GitHub Releases](https://github.com/username/raxol/releases/latest)
2. Run the installer and follow the on-screen instructions
3. Raxol will be added to your PATH automatically

### Method 2: Building from Source

If you prefer to build Raxol from source, follow these steps:

1. Ensure you have Elixir (v1.14+) and OTP (v25+) installed
2. Clone the repository:
   ```bash
   git clone https://github.com/username/raxol.git
   cd raxol
   ```
3. Install dependencies:
   ```bash
   mix deps.get
   ```
4. Build the project:
   ```bash
   mix run scripts/release.exs --env prod
   ```
5. The binary will be available in the `burrito_out/prod` directory

## Environment Setup

### Terminal Configuration

For the best experience, configure your terminal to support:

1. **True Color**: Ensure your terminal supports 24-bit color
2. **UTF-8 Encoding**: Set your terminal's encoding to UTF-8
3. **Font**: Use a monospaced font with good Unicode support (e.g., Fira Code, JetBrains Mono)

### Environment Variables

Raxol supports the following environment variables:

- `RAXOL_THEME`: Set the default color theme (default: "default")
- `RAXOL_COLOR_MODE`: Force a specific color mode ("true", "256", "16", or "none")
- `RAXOL_NO_COLOR`: Set to "1" to disable colors entirely
- `RAXOL_DEBUG`: Set to "1" to enable debug logging

Example:
```bash
RAXOL_THEME="dracula" RAXOL_COLOR_MODE="true" raxol
```

## Verifying Installation

To verify that Raxol is installed correctly, run:

```bash
raxol --version
```

This should display the version number of Raxol.

## Updating Raxol

### Automatic Updates

Raxol includes a built-in update system that can check for and apply updates automatically:

```bash
# Check for updates without installing
raxol update check

# Download and install the latest version
raxol update install

# Rollback to previous version if needed
raxol update rollback
```

### Using Package Managers

If you installed Raxol using a package manager:

```bash
# macOS
brew upgrade raxol

# Debian/Ubuntu
sudo apt-get update && sudo apt-get upgrade raxol

# RHEL/Fedora
sudo yum update raxol
```

### Manual Update

If you installed Raxol manually:

1. Download the latest release for your platform
2. Replace the existing binary with the new one

## Troubleshooting

### Common Issues

#### "Command not found" error

- Ensure the Raxol binary is in your PATH
- Check if the binary has execute permissions (`chmod +x /path/to/raxol`)

#### Color rendering issues

- Check if your terminal supports true color: `echo -e "\033[38;2;255;0;0mRed\033[0m"`
- Try setting `RAXOL_COLOR_MODE="256"` if your terminal doesn't support true color

#### Terminal size detection issues

- Ensure your terminal emulator correctly reports its size
- Try resizing your terminal window or running `resize` command

#### Garbled output or incorrect characters

- Ensure your terminal is set to use UTF-8 encoding
- Check if your font supports the Unicode characters being displayed

## Platform-Specific Considerations

### macOS

- For Apple Silicon (M1/M2) Macs, ensure you're using the ARM64 version of Raxol
- macOS may require permission to run applications downloaded from the internet
- If you encounter a "damaged app" error, run: `xattr -d com.apple.quarantine /path/to/raxol`
- For notarization issues, check the security settings in System Preferences

### Linux

- Some older terminals may have limited color support
- On headless systems, ensure a terminal emulator is properly configured
- For Wayland users: ensure your terminal emulator has proper Wayland support
- Common issues with different distros:
  - **Ubuntu/Debian**: If facing shared library issues, run `sudo apt-get install -y libssl1.1`
  - **CentOS/RHEL**: Ensure `ncurses` is installed with `sudo yum install ncurses`
  - **Arch Linux**: Update your terminal configuration if Unicode characters appear misaligned

### Windows

- Windows Terminal is recommended for the best experience
- PowerShell or Command Prompt may have limited rendering capabilities
- Consider using Windows Subsystem for Linux (WSL) for better terminal compatibility
- If using ConEmu or other terminal emulators, ensure UTF-8 and ANSI color support is enabled
- Add Raxol to Windows Defender exclusions if you experience performance issues

## Version Management

Raxol supports managing multiple installed versions:

```bash
# List all installed versions
raxol version list

# Switch to a specific version
raxol version use 1.2.3

# Remove an old version
raxol version remove 1.1.0
```

## Configuration Migration

When updating to a new major version, your configuration files may need to be migrated:

```bash
# Migrate configuration to the latest format
raxol config migrate
```

## CI/CD Integration

Raxol provides tools for integrating with popular CI/CD systems to automate your build and release process.

### GitHub Actions

```yaml
# .github/workflows/release.yml
name: Release Raxol

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        
    steps:
      - uses: actions/checkout@v2
      
      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.14.x'
          otp-version: '25.x'
          
      - name: Get dependencies
        run: mix deps.get
        
      - name: Build release
        run: mix run scripts/release.exs --env prod
        
      - name: Upload artifacts
        uses: actions/upload-artifact@v2
        with:
          name: raxol-${{ matrix.os }}
          path: burrito_out/prod/
```

### GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - build
  - release

variables:
  MIX_ENV: "prod"

build:linux:
  stage: build
  image: elixir:1.14
  script:
    - mix deps.get
    - mix run scripts/release.exs --env prod --platform linux
  artifacts:
    paths:
      - burrito_out/prod/

build:macos:
  stage: build
  tags:
    - macos
  script:
    - mix deps.get
    - mix run scripts/release.exs --env prod --platform macos
  artifacts:
    paths:
      - burrito_out/prod/

release:
  stage: release
  only:
    - tags
  script:
    - mix run scripts/release.exs --tag
```

### Travis CI

```yaml
# .travis.yml
language: elixir
elixir: '1.14'
otp_release: '25.0'

jobs:
  include:
    - os: linux
      env: PLATFORM=linux
    - os: osx
      env: PLATFORM=macos

script:
  - mix deps.get
  - mix run scripts/release.exs --env prod --platform $PLATFORM

deploy:
  provider: releases
  api_key: $GITHUB_TOKEN
  file_glob: true
  file: burrito_out/prod/*
  skip_cleanup: true
  on:
    tags: true
```

## Getting Help

If you encounter issues not covered in this guide:

1. Check the [GitHub Issues](https://github.com/username/raxol/issues) for similar problems
2. Search the [documentation](https://github.com/username/raxol/docs) for more information
3. Open a new issue with detailed information about your problem

## Uninstalling

To remove Raxol from your system:

```bash
# macOS
brew uninstall raxol

# Debian/Ubuntu
sudo apt-get remove raxol

# RHEL/Fedora
sudo yum remove raxol

# Manual uninstall
sudo rm /usr/local/bin/raxol
``` 