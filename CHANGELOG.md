# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2023-05-24

### Added

- Initial release of Raxol
- Terminal UI framework with web interface capabilities
- Core components library
- Visualization plugins
- Internationalization support
- Theme system

### Known Issues

- Various compiler warnings as documented in the CI logs

## [Unreleased]

### Added

- **Project Foundation:** Initial structure, config, docs, CI/CD, dev env, quality tools, test framework.
- **Terminal Capabilities:** Emulation layer, ANSI processing, platform/feature detection (colors, mouse, etc.).
- **Buffer Management:** Double buffering, damage tracking, virtual scrolling, cursor management.
- **Plugin System:** Core API, configuration, dependency management, clipboard/notification plugins.
- **Enhanced ANSI Processing:** Advanced formatting, device status reports, screen modes, character sets.
- **Component System:** Refactored View DSL, dashboard/layout components, specialized widgets (Info, Chart, etc.), testing framework.
- **VS Code Extension Integration:** Communication protocol, WebView panel, JSON interface.
- **Database Improvements:** Connection management, error handling, diagnostics.
- **Testing Framework:** Test plan, scripts (VS Code/native), mock components, performance monitoring.
- **Dashboard/Visualization:** Widget positioning/resizing, layout persistence, responsive components, drag-and-drop, caching.
- **CI/CD Improvements:** Local testing (`act`), cross-platform enhancements, security scanning.
- **Theme System:** Multiple built-in themes, selection UI, customization API, persistence.

### Changed

- **Architecture:** Improved modularity, configuration management, development workflow, documentation structure.
- **Terminal Functionality:** Improved feature detection, refined ANSI processing, optimized config/memory.
- **Plugin System:** Improved initialization, dependency resolution, API versioning, maintainability.
- **Runtime System:** Dual-mode operation (native/VS Code), conditional init, improved startup/error handling.
- **Project Structure:** Consolidated examples, dedicated frontend dir, normalized extensions, improved secrets/git handling.

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

- Numerous fixes across core system stability, components, database connections, VS Code integration, runtime issues, CI/CD, ANSI processing, and test suites (details below).

- **Detailed Fix History (Recent First):**
- **(2024-06-03):** Resolved remaining compilation warnings. Verified that previously listed warnings were mostly outdated or already fixed. Corrected `.screen_buffer` access in `lib/raxol/terminal/session.ex` to use `Emulator.get_active_buffer/1`.

## [Unreleased] - 2024-06-03

### Added

- **Project Foundation:** Initial structure, config, docs, CI/CD, dev env, quality tools, test framework.
- **Terminal Capabilities:** Emulation layer, ANSI processing, platform/feature detection (colors, mouse, etc.).
- **Buffer Management:** Double buffering, damage tracking, virtual scrolling, cursor management.
- **Plugin System:** Core API, configuration, dependency management, clipboard/notification plugins.
- **Enhanced ANSI Processing:** Advanced formatting, device status reports, screen modes, character sets.
- **Component System:** Refactored View DSL, dashboard/layout components, specialized widgets (Info, Chart, etc.), testing framework.
- **VS Code Extension Integration:** Communication protocol, WebView panel, JSON interface.
- **Database Improvements:** Connection management, error handling, diagnostics.
- **Testing Framework:** Test plan, scripts (VS Code/native), mock components, performance monitoring.
- **Dashboard/Visualization:** Widget positioning/resizing, layout persistence, responsive components, drag-and-drop, caching.
- **CI/CD Improvements:** Local testing (`act`), cross-platform enhancements, security scanning.
- **Theme System:** Multiple built-in themes, selection UI, customization API, persistence.

### Changed

- **Architecture:** Improved modularity, configuration management, development workflow, documentation structure.
- **Terminal Functionality:** Improved feature detection, refined ANSI processing, optimized config/memory.
- **Plugin System:** Improved initialization, dependency resolution, API versioning, maintainability.
- **Runtime System:** Dual-mode operation (native/VS Code), conditional init, improved startup/error handling.
- **Project Structure:** Consolidated examples, dedicated frontend dir, normalized extensions, improved secrets/git handling.

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

- Numerous fixes across core system stability, components, database connections, VS Code integration, runtime issues, CI/CD, ANSI processing, and test suites (details below).

- **Detailed Fix History (Recent First):**
- **(2024-06-03):** Resolved remaining compilation warnings. Verified that previously listed warnings were mostly outdated or already fixed. Corrected `.screen_buffer` access in `lib/raxol/terminal/session.ex` to use `Emulator.get_active_buffer/1`.
