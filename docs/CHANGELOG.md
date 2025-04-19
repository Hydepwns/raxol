---
title: Raxol Changelog
description: History of changes and releases for the Raxol terminal emulator framework
date: 2023-04-04
author: Raxol Team
section: changelog
tags: [changelog, releases, history]
---

# Changelog

All notable changes to the Raxol project will be documented in this file.

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
  - Button component with proper click handling and state management
  - Comprehensive test suite for UI components with mock components
  - Component testing framework with visual verification

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
  - Mock components for integration testing
  - Reusable test helpers for component visual testing
  - Stub implementations for visual verification

- Dashboard and Visualization System

  - Widget positioning and resizing capabilities
  - Layout persistence with validation
  - Responsive visualization components
  - Automatic layout saving after changes
  - Widget drag-and-drop functionality
  - Comprehensive integration test suite
  - Visualization caching system with benchmark-verified performance (5,800x-15,000x speedup)

- CI/CD Improvements

  - Platform-specific security scanning approach
  - Local workflow testing with custom Docker images
  - Cross-platform compatibility enhancements
  - Character list syntax modernization
  - Platform-specific PostgreSQL handling

- Theme System
  - Multiple built-in themes (Default, Dark, High Contrast)
  - Theme selection UI with visual previews
  - Theme customization interface
  - Theme configuration API
  - Theme persistence and loading capabilities

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
  - Enhanced Git management with optimized .gitignore

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

- Fixed PostgreSQL connection errors in test environment by preventing `:postgrex` from starting when `MockDB` is configured (`runtime: false`).
- Resolved `:gen_statem` application loading error in `processor_test.exs` by ensuring `:stdlib` is started first.
- Fixed `UserPreferences` "already started" error in `system_test.exs` by using `setup_all`.
- Corrected compile error in `i18n_accessibility_test.exs` by uncommenting `assert_locale_accessibility_settings` helper function.
- Addressed several issues in `Chart` view component and tests:

  - Removed tests calling private chart helper functions.
  - Fixed line chart drawing by using integer coordinates.
  - Prevented errors in bar chart drawing by clamping dimensions and correcting padding.
  - Corrected sparkline test view access.

- Core system stability

  - Terminal startup and initialization issues
  - Buffer and rendering engine bugs
  - Layout calculation and event handling problems
  - Memory management and cleanup issues

- Component issues

  - Various widget rendering and initialization errors
  - Dashboard and visualization component bugs
  - State persistence and update problems
  - Button component click handling and state management
  - Dashboard grid container dimension handling (col_span/row_span and width/height naming)

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
  - Terminal dimension reporting inconsistencies

- CI/CD workflow
  - GitHub Actions workflow for cross-platform compatibility
  - Docker image building and testing
  - Local workflow testing with Act

### Security

- Enhanced security scanning for both Linux and macOS environments
- Improved secrets handling with example templates
- Platform-specific security testing approach

## [0.1.0] - 2023-03-15

### Added

- Initial project setup
- Basic project structure
- Core dependencies
- Development environment configuration
- CI/CD pipeline setup
