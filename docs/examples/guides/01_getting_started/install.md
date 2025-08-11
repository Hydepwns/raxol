---
title: Installation Guide
description: How to install and set up Raxol on your system
date: 2025-06-18
author: Raxol Team
section: guides
tags: [installation, setup, getting started]
---

# Installation Guide

This guide will help you install Raxol and its dependencies on your system. Raxol is designed to work seamlessly across multiple platforms including macOS, Linux, and Windows.

## Prerequisites

Before installing Raxol, ensure you have the following installed:

### For Development (Recommended)

- **[Nix](https://nixos.org/download.html)** - For reproducible development environment
- **[direnv](https://direnv.net/)** (optional) - For automatic environment loading

### For Manual Installation

- **Elixir** (1.17.1 or later)
- **Erlang/OTP** (25.3.2.7 or later)
- **Mix** (comes with Elixir)
- **PostgreSQL** (15 or later)
- **Build tools** (gcc, make, cmake, pkg-config)
- **ImageMagick** (for image processing)
- **Node.js** (20 or later, for asset compilation)

## Installation Methods

### 1. Using Nix (Recommended for Development)

For the best development experience, we recommend using Nix:

```bash
# Clone the repository
git clone https://github.com/Hydepwns/raxol.git
cd raxol

# Enter the development environment
nix-shell

# Or if you have direnv installed, just cd into the project
# direnv will automatically load the environment

# Install dependencies and setup
mix deps.get
git submodule update --init --recursive
mix setup
```

The Nix environment provides:

- Erlang 25.3.2.7 and Elixir 1.17.1 (matching `.tool-versions`)
- PostgreSQL 15 with automatic setup and management
- All necessary build tools and system libraries
- ImageMagick for image processing
- Node.js 20 for asset compilation

### 2. Using Mix (For Production Use)

Add Raxol to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:raxol, "~> 0.9.0"}
  ]
end
```

Then fetch the dependencies:

```bash
mix deps.get
```

### 3. Platform-Specific Installation

#### macOS

Using Homebrew:

```bash
brew install hydepwns/raxol/raxol
```

#### Linux

**Debian/Ubuntu:**

```bash
# Add the repository
curl -fsSL https://deb.raxol.dev/gpg | sudo gpg --dearmor -o /usr/share/keyrings/raxol-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/raxol-archive-keyring.gpg] https://deb.raxol.dev stable main" | sudo tee /etc/apt/sources.list.d/raxol.list

# Install Raxol
sudo apt update
sudo apt install raxol
```

**Arch Linux:**

```bash
yay -S raxol
```

#### Windows

Using Windows Package Manager:

```bash
winget install raxol
```

## Platform Support

Raxol is fully supported on the following platforms:

| Platform | Architecture          | Status             |
| -------- | --------------------- | ------------------ |
| macOS    | x86_64 (Intel)        | ✅ Fully supported |
| macOS    | arm64 (Apple Silicon) | ✅ Fully supported |
| Linux    | x86_64                | ✅ Fully supported |
| Linux    | arm64                 | ✅ Fully supported |
| Windows  | x86_64                | ✅ Fully supported |

## Terminal Compatibility

Raxol works best with modern terminal emulators that support True Color and Unicode:

### Recommended Terminals

- **macOS**: iTerm2, Alacritty, Kitty
- **Linux**: GNOME Terminal, Konsole, Alacritty, Kitty
- **Windows**: Windows Terminal

## Feature Support

| Feature               | macOS | Linux | Windows |
| --------------------- | ----- | ----- | ------- |
| True Color (24-bit)   | ✅    | ✅    | ✅      |
| Unicode/emoji support | ✅    | ✅    | ✅      |
| Mouse support         | ✅    | ✅    | ✅      |
| Keyboard shortcuts    | ✅    | ✅    | ✅      |
| Clipboard integration | ✅    | ✅    | ✅      |
| HiDPI support         | ✅    | ✅    | ✅      |
| Plugin system         | ✅    | ✅    | ✅      |
| Improved reliability  | ✅    | ✅    | ✅      |

_Note: Raxol 0.9.0 is a full-stack terminal application framework with web interface support, plugin system, and enterprise features across all platforms._

## Troubleshooting

### Nix Environment Issues

If you're using the Nix environment and encounter issues:

1. **Shell not loading properly**:

   ```bash
   # Rebuild the shell
   nix-shell --run "echo 'Shell rebuilt'"
   ```

2. **PostgreSQL issues**:

   ```bash
   # Remove and reinitialize the database
   rm -rf .postgres
   nix-shell  # This will reinitialize the database
   ```

3. **Compilation issues**:

   ```bash
   # Clean and rebuild
   mix deps.clean --all
   mix deps.get
   mix deps.compile
   ```

### Manual Installation Issues

1. **Missing Dependencies**

   ```bash
   # Linux
   sudo apt install libssl-dev libncurses5-dev

   # macOS
   brew install openssl ncurses
   ```

2. **Permission Issues**

   ```bash
   # Make executable
   chmod +x /path/to/raxol
   ```

3. **Terminal Color Issues**
   - Enable "Use bright colors for bold text" in terminal preferences
   - Verify your terminal supports True Color

### Platform-Specific Notes

#### macOS

- For Apple Silicon (M1/M2/M3) users, Raxol provides native ARM64 binaries
- If you see "App is damaged" warning, run:

  ```bash
  xattr -d com.apple.quarantine /path/to/raxol
  ```

#### Linux

- For Wayland users, ensure your terminal emulator has proper Wayland support
- Set your locale to UTF-8:

  ```bash
  locale-gen en_US.UTF-8
  update-locale LANG=en_US.UTF-8
  ```

#### Windows

- Use Windows Terminal for the best experience
- If using PowerShell, set UTF-8 encoding:

  ```powershell
  [console]::OutputEncoding = [System.Text.Encoding]::UTF8
  ```

## Next Steps

After installation, check out:

- [Quick Start Guide](quick_start.md) to create your first Raxol application
- [Examples](../) for sample applications and use cases
- [Development Guide](docs/DEVELOPMENT.html) for detailed development setup instructions
