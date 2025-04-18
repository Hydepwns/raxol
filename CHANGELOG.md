# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Project foundation

  - Initial structure and configuration
  - Documentation framework and roadmap
  - CI/CD pipeline and GitHub Actions
  - Development environment setup
  - Code quality tools (Credo, Dialyzer)
  - Test framework

- Terminal capabilities

  - Terminal emulation layer and ANSI processing
  - Platform detection and feature support
  - Support for various terminal types (iTerm2, Windows Terminal, xterm)
  - Color, Unicode, mouse and clipboard support detection

- Buffer management

  - Screen buffer with double buffering and damage tracking
  - Virtual scrolling with configurable history
  - Memory-efficient buffer management with compression
  - Cursor management with multiple styles and animation

- Plugin system

  - Configuration persistence and restoration
  - Dependency management with resolution and validation
  - API versioning with compatibility checks
  - Notification plugin with configurable styles
  - Clipboard plugin with selection modes and platform integration

- Enhanced ANSI processing

  - Advanced text formatting support
  - Device status reports and queries
  - Screen mode transitions and character set handling
  - New specialized modules (`TextFormatting`, `ScreenModes`, `DeviceStatus`)

- Component system

  - Refactored View DSL with improved consistency
  - Dashboard layout and widget container components
  - Specialized widgets (Info, TextInput, Chart, TreeMap)
  - Visualization plugin for data rendering

- VS Code Extension Integration

  - Extension-backend communication protocol
  - WebView panel creation and management
  - JSON-based communication interface
  - Extension-specific rendering path

- Database improvements

  - Connection management with retry logic
  - Error handling and logging
  - Diagnostic tools
  - Enhanced repository configuration

- Testing Framework

  - Comprehensive test plan with clear success criteria
  - Testing scripts for both VS Code and native terminal environments
  - Visualization test data generators
  - Performance monitoring utilities

- Dashboard and Visualization System

  - Widget positioning and resizing capabilities
  - Layout persistence with validation
  - Responsive visualization components
  - Automatic layout saving after changes
  - Widget drag-and-drop functionality
  - Comprehensive integration test suite

- CI/CD Improvements
  - Platform-specific security scanning approach
  - Local workflow testing with custom Docker images
  - Cross-platform compatibility enhancements
  - Character list syntax modernization

### Changed

- Architecture and organization

  - Modular architecture with improved separation of concerns
  - Optimized configuration management
  - Streamlined development workflow
  - Enhanced documentation structure

- Terminal functionality

  - Improved feature detection accuracy
  - Refined ANSI processing implementation
  - Optimized configuration handling
  - Enhanced memory management

- Plugin system

  - Improved initialization with merged configurations
  - Enhanced dependency resolution
  - Updated API version handling
  - Refactored for better maintainability

- Runtime system

  - Dual-mode operation (native terminal and VS Code extension)
  - Conditional initialization based on environment
  - Improved startup sequence and error handling
  - Environment-specific output targets

- Project structure
  - Consolidated examples into a single location
  - Created dedicated frontend directory
  - Normalized extension organization
  - Improved secrets handling with templates

### Deprecated

- Old event system
- Legacy rendering approach
- Previous styling methods

### Removed

- Outdated configuration files and dependencies
- Redundant documentation
- Legacy terminal handling code
- `use Raxol.Component` from helper modules

### Fixed

- Core system stability

  - Terminal startup and initialization issues
  - Buffer and rendering engine bugs
  - Layout calculation and event handling problems
  - Memory management and cleanup issues

- Component issues

  - Various widget rendering and initialization errors
  - Dashboard and visualization component bugs
  - State persistence and update problems

- Database connections

  - Connection pooling and management
  - Error handling with retry mechanism
  - Repository configuration and initialization

- VS Code integration

  - Extension activation and environment detection
  - Communication protocol implementation
  - UI rendering through proper interface integration
  - User input and resize handling
  - JSON message formatting with markers

- Runtime issues

  - BEAM VM hang on exit in stdio mode
  - Layout saving and loading functionality
  - ExTermbox initialization failure
  - Resize handling with proper model updates
  - User input handling with quit key detection

- CI/CD workflow

  - GitHub Actions workflow for cross-platform compatibility
  - Security scanning on macOS without Docker
  - Test workflow verification
  - Local CI testing with custom Docker images

- Code quality
  - Compiler warnings and type issues
  - Dialyzer warnings in components and core modules
  - Function and callback implementation mismatches

### Security

- Input validation
- Resource access controls
- Event sanitization
- Security vulnerabilities
- Platform-specific security scanning approach

## [0.1.0] - YYYY-MM-DD

### Added

- Core runtime system
  - BEAM integration and process supervision
  - Hot code reloading
- Rendering engine
  - Terminal buffer management with double buffering
  - Frame rate control
- Event and input handling system
- Style system with layout engine
- Component library (text input, selection, progress indicators)
- Testing infrastructure
- Documentation
- Packaging and distribution setup
- Terminal emulation and ANSI processing
- Web interface, authentication and session management

### Changed

- Refactored from Ratatouille base
- Enhanced event handling and rendering
- Improved component architecture and error handling
- Optimized performance

### Deprecated

- Old event system
- Legacy rendering approach
- Previous styling methods

### Removed

- Unused Ratatouille components
- Outdated documentation
- Legacy test framework

### Fixed

- Event handling and rendering issues
- Style inconsistencies
- Performance bottlenecks
- Screen mode and character set handling

### Security

- Input validation
- Resource access controls
- Event sanitization

[Unreleased]: https://github.com/Hydepwns/raxol/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Hydepwns/raxol/releases/tag/v0.1.0
