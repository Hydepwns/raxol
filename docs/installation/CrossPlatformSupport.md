---
title: Cross-Platform Support
description: Documentation for cross-platform support in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: installation
tags: [installation, cross-platform, support]
---

# Cross-Platform Support

Raxol is designed to work seamlessly across multiple platforms including macOS, Linux, and Windows. This document outlines platform-specific considerations and optimizations.

## System Dependency Installation

Before cloning and building Raxol from source (see [Development Environment Setup](DevelopmentSetup.md)), you need to install the core system dependencies. The main requirements are Elixir, Erlang, and potentially Node.js/npm if you plan to work with frontend components.

### Linux (Debian/Ubuntu Example)

```bash
# Install Elixir and Erlang
sudo apt-get update
sudo apt-get install elixir erlang

# Install Node.js and npm (if needed)
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt-get install -y nodejs
```

_(Adapt package manager commands for other distributions like Fedora, Arch, etc.)_

### macOS

```bash
# Install Elixir and Erlang using Homebrew
brew install elixir erlang

# Install Node.js and npm (if needed)
brew install node
```

### Windows

1. Install [Elixir](https://elixir-lang.org/install.html#windows) (includes Erlang)
2. Install [Node.js](https://nodejs.org/en/download/) (includes npm, if needed)

_(Ensure the installers add the commands to your system's PATH.)_

## Platform Matrix

| Platform              | Architecture          | Status             | Notes                 |
| --------------------- | --------------------- | ------------------ | --------------------- |
| macOS                 | x86_64 (Intel)        | ✅ Fully supported |                       |
| macOS                 | arm64 (Apple Silicon) | ✅ Fully supported | Native performance    |
| Linux (Debian/Ubuntu) | x86_64                | ✅ Fully supported |                       |
| Linux (Debian/Ubuntu) | arm64                 | ✅ Fully supported |                       |
| Linux (RHEL/Fedora)   | x86_64                | ✅ Fully supported |                       |
| Linux (Arch)          | x86_64                | ✅ Fully supported | AUR package available |
| Windows               | x86_64                | ✅ Fully supported |                       |

## Platform-Specific Considerations

### macOS

#### Terminal Support

- **Terminal.app**: Fully supported with True Color
- **iTerm2**: Recommended for best experience with advanced features
- **Alacritty**: Excellent performance with True Color support
- **Kitty**: Full feature support including ligatures and True Color

#### Installation Options

- Homebrew: `brew install username/raxol/raxol`
- Direct download: DMG installer available
- Source build: Full support for both architectures

#### Apple Silicon Optimization

Raxol has been optimized for Apple Silicon (M1/M2/M3) processors, providing:

- Native ARM64 binaries for maximum performance
- Reduced memory usage compared to Rosetta 2 translation
- Optimized rendering pipeline for Apple GPU architecture

### Linux

#### Terminal Support

- **GNOME Terminal**: Full True Color and Unicode support
- **Konsole**: Excellent KDE integration with all features
- **XFCE Terminal**: Lightweight with good compatibility
- **Terminator**: Full support for split panes and True Color
- **Alacritty/Kitty**: Recommended for best performance

#### Distribution Packages

- **Debian/Ubuntu**: `.deb` packages with automatic dependency resolution
- **RHEL/Fedora/CentOS**: `.rpm` packages available
- **Arch Linux**: Available in the AUR
- **NixOS**: Nix package available

#### Wayland Considerations

Raxol fully supports Wayland display servers, with:

- Proper handling of HiDPI displays
- Clipboard integration
- Touch input support where available

### Windows

#### Terminal Support

- **Windows Terminal**: Recommended for best experience
- **PowerShell**: Supported with some rendering limitations
- **Command Prompt**: Basic support with limited color capabilities
- **ConEmu/Cmder**: Full support with proper configuration

#### Installation Options

- Windows Installer (.exe)
- Portable ZIP archive
- Windows Package Manager: `winget install raxol`

#### WSL Integration

Raxol can be used within Windows Subsystem for Linux with:

- Full performance on both WSL1 and WSL2
- Proper rendering in Windows Terminal
- Integration with VS Code Remote WSL

## Feature Compatibility Matrix

| Feature               | macOS | Linux | Windows |
| --------------------- | ----- | ----- | ------- |
| True Color (24-bit)   | ✅    | ✅    | ✅\*    |
| Unicode/emoji support | ✅    | ✅    | ✅\*    |
| Mouse support         | ✅    | ✅    | ✅      |
| Keyboard shortcuts    | ✅    | ✅    | ✅      |
| Clipboard integration | ✅    | ✅    | ✅      |
| Auto-update           | ✅    | ✅    | ✅      |
| HiDPI support         | ✅    | ✅    | ✅      |

\*Full support in Windows Terminal, limited in older terminals

## Building for Multiple Platforms

Raxol uses Burrito to build native executables for each platform. To build for a specific platform:

```bash
# Build for all platforms
mix run scripts/release.exs --env prod --all

# Build for a specific platform
mix run scripts/release.exs --env prod --platform [macos|linux|windows]
```

## Troubleshooting Platform-Specific Issues

### macOS

- **Permission issues**: Run `chmod +x /path/to/raxol` to make executable
- **"App is damaged"**: Run `xattr -d com.apple.quarantine /path/to/raxol`
- **Terminal.app color issues**: Enable "Use bright colors for bold text" in Terminal preferences

### Linux

- **Missing libraries**: Install `libssl` and `libncurses` packages
- **Permission denied**: Ensure executable permission with `chmod +x ./raxol`
- **Rendering issues**: Verify your terminal supports UTF-8 with `locale`

### Windows

- **PATH issues**: Ensure installation directory is in your PATH
- **Color rendering**: Use Windows Terminal for best experience
- **Unicode problems**: Set PowerShell to UTF-8 with `[console]::OutputEncoding = [System.Text.Encoding]::UTF8`
