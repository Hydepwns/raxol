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

- **Elixir** (1.14 or later)
- **Erlang/OTP** (24 or later)
- **Mix** (comes with Elixir)

## Installation Methods

### 1. Using Mix (Recommended)

Add Raxol to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:raxol, "~> 0.4.2"}
  ]
end
```

Then fetch the dependencies:

```bash
mix deps.get
```

### 2. Platform-Specific Installation

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

## Troubleshooting

### Common Issues

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
- [Components & Layout](03_components_and_layout/components/README.md) to learn about building UIs
- [Examples](../) for sample applications and use cases
