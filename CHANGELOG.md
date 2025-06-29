## [0.4.2] - 2025-06-11

### Added

- **Terminal Buffer Management Refactoring:**

  - Split `manager.ex` into specialized modules:
    - `State` - Buffer initialization and state management
    - `Cursor` - Cursor position and movement
    - `Damage` - Damaged regions tracking
    - `Memory` - Memory usage and limits
    - `Scrollback` - Scrollback buffer operations
    - `Buffer` - Buffer operations and synchronization
    - `Manager` - Main facade coordination
  - Improved code organization and maintainability
  - Enhanced test coverage
  - Better error handling
  - Clearer interfaces

- **Plugin System Improvements:**

  - Implemented Tarjan's algorithm for dependency resolution
  - Enhanced version constraint handling
  - Added detailed dependency chain reporting
  - Improved error handling and diagnostics
  - Optimized dependency graph operations

- **Component System Enhancements:**

  - Harmonized API for all input components
  - Improved theme and style prop support
  - Enhanced lifecycle hooks
  - Better accessibility integration
  - Comprehensive test coverage

- **Performance Infrastructure:**

  - New `Raxol.Test.PerformanceHelper` module
  - Performance test suite for terminal manager
  - Event processing benchmarks
  - Screen update benchmarks
  - Concurrent operation benchmarks

- **Documentation Improvements:**
  - Completed comprehensive guides
  - Enhanced API documentation
  - Improved architecture documentation
  - Added migration guide
  - Updated component documentation

### Changed

- **Test Infrastructure:**

  - Replaced `Process.sleep` with event-based synchronization
  - Enhanced plugin test fixtures
  - Improved error handling
  - Better resource cleanup
  - Clear test boundaries

- **Terminal Command Handling:**

  - Standardized error/result tuples
  - Improved error propagation
  - Enhanced command handler organization
  - Better test coverage

- **Component System:**
  - Migrated to `Raxol.UI.Components` namespace
  - Improved theme handling
  - Enhanced style prop support
  - Better lifecycle management

### Deprecated

- Old event system
- Legacy rendering approach
- Previous styling methods
- `Raxol.Terminal.CommandHistory` (Use `Raxol.Terminal.Commands.History` instead)

### Removed

- Redundant `Raxol.Core.Runtime.Plugins.Commands` GenServer
- Redundant clipboard modules
- `Raxol.UI.Components.ScreenModes` module
- Direct `:meck` usage from test files

### Fixed

- **SelectList Mouse Focus Bug:**

  - Fixed focus update on mouse clicks
  - Improved test coverage
  - Enhanced mouse interaction handling

- **Accessibility Tests:**

  - Fixed color suggestion tests
  - Improved test reliability
  - Enhanced accessibility coverage

- **Test Suite:**
  - Resolved compilation errors
  - Fixed helper function scoping
  - Improved test organization

### Next Focus

1. Address remaining test failures
2. Complete OSC 4 handler implementation
3. Implement robust anchor checking
4. Document test writing guide
5. Continue code quality improvements

## [0.4.0] - 2025-05-10

### Added

- Initial public release
- Core terminal functionality
- Basic component system
- Plugin architecture
- Testing infrastructure

## [0.5.0] - 2025-06-12

### Added

- **Progress Component:**

  - New `Raxol.UI.Components.Progress` module with multiple progress indicators:
    - Progress bars with customizable styles and labels
    - Spinner animations with multiple animation types
    - Indeterminate progress bars
    - Circular progress indicators
  - Comprehensive test coverage for all progress variants
  - Full documentation with examples and usage guidelines

- **Documentation Overhaul:**

  - Major updates to all component documentation in `docs/components/`
  - Improved structure, navigation, and cross-references
  - Added mermaid diagrams and comprehensive API references
  - Expanded best practices and common pitfalls sections

- **Test Suite Improvements:**

  - Enhanced test coverage and organization
  - Updated test fixtures and support files
  - Improved reliability and maintainability

- **Code Style and Formatting:**

  - Applied consistent formatting across all Elixir source files
  - Improved code readability and maintainability

- **Utility Scripts:**
  - Added scripts for code maintenance and consistency

### Changed

- Updated guides and general documentation for clarity and completeness
- Refined documentation links and fixed broken references

### Removed

- Obsolete migration and test consolidation guides

- **Native Dependency Management:**
  - Removed vendored `termbox2` C source from `lib/termbox2_nif/c_src/termbox2`
  - Now uses the official [termbox2](https://github.com/termbox/termbox2) as a git submodule
  - Developers must run `git submodule update --init --recursive` before building
  - Updated build and documentation to reflect this change

## [0.5.1] - 2025-01-27

### Added

- **Terminal System Major Enhancements:**

  - Comprehensive refactoring of terminal buffer, ANSI, plugin, and rendering subsystems
  - Enhanced ANSI state machine with improved escape sequence handling
  - Better sixel graphics support and parsing
  - Improved mouse tracking and window manipulation
  - Enhanced buffer management with unified operations
  - Better character handling and clipboard integration
  - Comprehensive test coverage for all terminal subsystems

- **Core System Improvements:**

  - Enhanced metrics aggregation and visualization
  - Improved performance monitoring and system utilities
  - Better UX refinement with accessibility integration
  - Enhanced color system and theme management
  - Improved application lifecycle management

- **UI Component Updates:**

  - Updated base component lifecycle management
  - Enhanced input field components (multi-line, password, select)
  - Improved progress spinner and layout engine
  - Better rendering pipeline and container management
  - Enhanced test coverage for UI components

- **Testing Infrastructure:**

  - Expanded test suite with improved coverage
  - Enhanced test fixtures and support scripts
  - Better plugin test organization and reliability
  - Improved mock implementations and test helpers
  - Added comprehensive test documentation

- **Documentation and Configuration:**
  - Added compilation error plan and critical fixes reference
  - Enhanced plugin test backups and documentation
  - Updated configuration and application startup
  - Improved plugin events and metrics collector
  - Better script organization and maintenance

### Changed

- **Code Quality:**

  - Applied consistent formatting across all Elixir source files
  - Improved code readability and maintainability
  - Enhanced error handling and validation
  - Better separation of concerns in terminal subsystems
  - Standardized API patterns across components

- **Performance:**
  - Optimized terminal operations and buffer management
  - Improved rendering pipeline efficiency
  - Enhanced memory management and resource cleanup
  - Better concurrent operation handling

### Fixed

- **Terminal Operations:**

  - Fixed ANSI sequence parsing edge cases
  - Improved buffer scroll region handling
  - Enhanced cursor positioning accuracy
  - Better window state management
  - Fixed sixel graphics rendering issues

- **Test Reliability:**
  - Resolved test compilation errors
  - Fixed mock implementation inconsistencies
  - Improved test isolation and cleanup
  - Enhanced test data management

### Removed

- Obsolete UI component files
- Redundant test fixtures
- Unused configuration options
