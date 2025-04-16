# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial project structure
- Basic documentation framework
- Development roadmap
- Architecture documentation
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
- Enhanced text style handling
- Refactored View DSL macros (`box`/`panel`) to flatten children and reject `nil`.
- Introduced `Raxol.View.to_element/1` for component type consistency.
- Refactored `Raxol.View` DSL (`box`/`flex`) to use keyword arguments and updated call sites.
- Implemented initial `Dashboard` layout component, moving logic from `MyApp`.
- Created `WidgetContainer` and dedicated widget components (`InfoWidget`, `TextInputWidget`, `ChartWidget`, `TreeMapWidget`).
- Integrated `ChartWidget` and `TreeMapWidget` into `Dashboard`.
- Refactored `ChartWidget` and `TreeMapWidget` to return data maps instead of using `Raxol.App`.
- Created `VisualizationPlugin` to handle rendering of visualization data maps.
- Updated `Runtime` to parse OSC 8 hyperlink sequences and call `VisualizationPlugin`.
- Implemented clipboard paste injection via `ClipboardPlugin`, `PluginManager`, `Runtime`, and `MyApp`.
- Implemented basic TUI bar chart and treemap rendering in `VisualizationPlugin`.
- Refined TUI visualization rendering (colors, fractional blocks, text handling).
- Updated dashboard persistence to save widget options and trigger on change.
- Refactored `Runtime` event handling logic.
- Adjusted `Runtime` render loop to send plugin commands after presenting buffer.

### Changed

- Restructured for modular architecture
- Updated documentation style
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

### Deprecated

- Old event system
- Legacy rendering approach
- Previous styling methods

### Removed

- Outdated configuration files
- Unused dependencies
- Redundant documentation
- Legacy terminal handling code
- `use Raxol.Component` from helper modules (`Modal`, `TabBar`, `Table`).
- None

### Fixed

- `ex_termbox` compilation failure due to invalid file mode in `waf` scripts (patched dependency).
- Infinite loop in `ImagePlugin` by ensuring state updates are persisted.
- Runtime startup crashes (`:already_running` Termbox error, `FunctionClauseError` in `MyApp.init`).
- Distinct type comparison compiler warning.
- Duplicate private function definitions in `lib/raxol/terminal/configuration.ex`.
- Incorrect `ex_termbox` function call (`set_buffer_cells/1` -> `change_cell/5`) in `lib/raxol/runtime.ex`.
- `HEEx.Sigil is not loaded` compilation errors in visualization widgets.
- `no_return` Dialyzer warning in `UserRegistrationController` via `Accounts` fix.
- `call` error for `Enum.sort_by/3` in `Table` component.
- Various compiler warnings (unused imports/variables, invalid aliases, etc.) after refactoring.
- Various Dialyzer warnings through suppression (`@dialyzer {:nowarn_function, ...}`) or fixes (spec updates, type definitions like `theme_map()`, contract adjustments).
- Manual fix for missing `end` keyword in `Button` component (acknowledged).
- Initial set of `callback_type_mismatch` / `callback_arg_type_mismatch` Dialyzer warnings in various components.
- `FunctionClauseError` in `Dashboard.render/1` (widget init).
- `KeyError` in `Runtime` rendering logic (dimension map).
- `:image` placeholder creation bug in `Runtime` (missing `:opts` copy).
- `ArgumentError` in `VisualizationPlugin` chart rendering (incorrect data handling).
- `IO.write` protocol error in `Runtime.send_plugin_commands`.
- `GridContainer` calculation logic (used `div`, switched to `round`).
- `Runtime` crash loop (`KeyError: :parent_bounds`).
- `ScreenBuffer` diff/update logic (full comparison, wide char handling).
- `Runtime` usage of `ScreenBuffer` diff.
- Immediate quit-on-start issue (adjusted default `quit_keys`).
- `ArgumentError` (`:parent_bounds` on nil) by correcting `RuntimeDebug.init` return value handling.
- `UndefinedFunctionError` (`Access` behaviour) by using struct access in `RuntimeDebug` render logic.
- None

### Security

- Input validation
- Resource access controls
- Event sanitization
- Security vulnerabilities (Note: Item moved from root file's Fixed section)

## [0.1.0] - YYYY-MM-DD

### Added

- Core runtime system
  - BEAM integration
  - Process supervision
  - Hot code reloading
- Basic rendering engine
  - Terminal buffer management
  - Double buffering support
  - Frame rate control
- Event system foundation
  - Event handling
  - Input processing
  - Event delegation
- Style system basics
  - Color support
  - Layout engine
  - Border system
- Initial component library
  - Text input
  - Selection components
  - Progress indicators
- Testing infrastructure
  - Unit testing setup
  - Integration testing framework
  - Visual testing tools
- Documentation
  - Architecture overview
  - Component guides
  - Style system documentation
- Burrito integration
  - Basic packaging
  - Distribution setup
- Terminal emulation layer
- ANSI processing module
- Web interface components
- Authentication system
- Session management
- Performance monitoring

### Changed

- Refactored from Ratatouille base
- Enhanced event handling system
- Improved rendering performance
- Updated component architecture
- Improved error handling
- Enhanced configuration options
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

- Event handling issues
- Rendering glitches
- Style inconsistencies
- Various bugs and issues
- Performance bottlenecks
- Screen mode transition edge cases
- Character set switching issues
- Text formatting state persistence

### Security

- Input validation
- Resource access controls
- Event sanitization
- Security vulnerabilities (Note: Item moved from root file's Fixed section)

[Unreleased]: https://github.com/Hydepwns/raxol/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Hydepwns/raxol/releases/tag/v0.1.0
