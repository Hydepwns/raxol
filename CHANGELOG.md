# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial project structure and configuration
- Terminal and web supervisors
- CI/CD pipeline setup
- Development environment configuration
- Documentation framework
- ANSI processing module structure
- Terminal emulation layer foundation
- GitHub Actions workflows
- Dependabot configuration
- Code quality tools (Credo, Dialyzer)
- Test framework setup
- Comprehensive terminal capability detection
- Platform-specific feature support
- Terminal configuration management
- Advanced ANSI escape code processing
- Terminal platform detection and optimization
- Test coverage for terminal features
- Support for various terminal types (iTerm2, Windows Terminal, xterm)
- Color mode detection (basic, 256-color, true color)
- Unicode support detection
- Mouse and clipboard support detection
- Terminal feature detection framework
- Screen buffer management system with double buffering
- Damage tracking for optimized rendering
- Virtual scrolling with configurable history size
- Memory-efficient buffer management with compression
- Cursor management with multiple styles (block, underline, bar)
- Cursor state persistence and animation system
- Terminal integration layer for component coordination
- Comprehensive test coverage for buffer and cursor systems
- Plugin configuration persistence
  - Plugin settings are now automatically saved to disk
  - Configurations are restored when the terminal is restarted
  - Support for plugin-specific settings and enabled/disabled state
- Notification plugin
  - Configurable notification styles (minimal, banner, popup)
  - Support for different notification positions
  - Customizable duration and sound settings
  - Maximum notification limit
  - Color-coded notification types (success, error, warning, info)
- Plugin dependency management
  - Automatic dependency resolution with topological sorting
  - Version compatibility checks for plugin dependencies
  - Support for optional and required dependencies
  - Circular dependency detection
  - Dependency validation before plugin loading
- Plugin API versioning
  - API version compatibility checks
  - Major version compatibility enforcement
  - Semantic versioning support for plugin APIs
- Clipboard plugin
  - Copy text from terminal to system clipboard
  - Paste text from system clipboard to terminal
  - Multiple selection modes (line, block, word)
  - Mouse-based text selection
  - Platform-specific clipboard integration (Unix, Windows)
  - Integration with notification plugin for operation feedback
- Enhanced ANSI processing system:
  - Advanced text formatting support (double-width/double-height characters)
  - Device status reports and terminal state queries
  - Terminal identification responses
  - Improved screen mode transitions
  - Better character set handling
- New modules for better code organization:
  - `TextFormatting` for advanced text formatting features
  - `ScreenModes` for screen mode transitions
  - `DeviceStatus` for terminal state queries
- Comprehensive test coverage for new ANSI features

### Changed

- Consolidated repository structure
- Updated dependencies
- Improved configuration management
- Enhanced documentation
- Streamlined development workflow
- Enhanced terminal emulation capabilities
- Improved platform detection accuracy
- Updated terminal feature detection logic
- Refined ANSI processing implementation
- Optimized terminal configuration handling
- Improved memory management with automatic cleanup
- Enhanced cursor visibility control and position tracking
- Optimized buffer switching for reduced screen flicker
- Updated plugin manager to support configuration persistence
- Improved plugin initialization with merged configurations
- Enhanced plugin manager with dependency resolution
- Updated plugin behavior to include dependency and API version information
- Refactored ANSI processing code for better maintainability
- Improved screen mode state management
- Enhanced text style handling

### Removed

- Outdated configuration files
- Unused dependencies
- Redundant documentation
- Legacy terminal handling code

## [0.1.0] - YYYY-MM-DD

### Added

- Terminal emulation layer
- ANSI processing module
- Web interface components
- Authentication system
- Session management
- Performance monitoring
- Documentation

### Changed

- Improved error handling
- Enhanced configuration options
- Optimized performance

### Fixed

- Various bugs and issues
- Security vulnerabilities
- Performance bottlenecks

- Screen mode transition edge cases
- Character set switching issues
- Text formatting state persistence
