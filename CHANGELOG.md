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
  - Removed vendored `termbox2` C source from `lib/termbox2_nif/c_src/termbox2`.
  - Now uses the official [termbox2](https://github.com/termbox/termbox2) as a git submodule.
  - Developers must run `git submodule update --init --recursive` before building.
  - Updated build and documentation to reflect this change.
