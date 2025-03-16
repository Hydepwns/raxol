# Cross-Platform Support

Raxol is designed to work seamlessly across multiple platforms including macOS, Linux, and Windows. This document outlines platform-specific considerations and optimizations.

## Platform Matrix

| Platform | Architecture | Status | Notes |
|----------|-------------|--------|-------|
| macOS | x86_64 (Intel) | ✅ Fully supported | |
| macOS | arm64 (Apple Silicon) | ✅ Fully supported | Native performance |
| Linux (Debian/Ubuntu) | x86_64 | ✅ Fully supported | |
| Linux (Debian/Ubuntu) | arm64 | ✅ Fully supported | |
| Linux (RHEL/Fedora) | x86_64 | ✅ Fully supported | |
| Linux (Arch) | x86_64 | ✅ Fully supported | AUR package available |
| Windows | x86_64 | ✅ Fully supported | |

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

| Feature | macOS | Linux | Windows |
|---------|-------|-------|---------|
| True Color (24-bit) | ✅ | ✅ | ✅* |
| Unicode/emoji support | ✅ | ✅ | ✅* |
| Mouse support | ✅ | ✅ | ✅ |
| Keyboard shortcuts | ✅ | ✅ | ✅ |
| Clipboard integration | ✅ | ✅ | ✅ |
| Auto-update | ✅ | ✅ | ✅ |
| HiDPI support | ✅ | ✅ | ✅ |

*Full support in Windows Terminal, limited in older terminals

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