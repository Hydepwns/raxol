## [Unreleased]

### Added

- **Terminal Buffer Management Refactoring:**
  - Split `manager.ex` into specialized modules for better separation of concerns:
    - `State` - Handles buffer initialization and state management
    - `Cursor` - Manages cursor position and movement
    - `Damage` - Tracks damaged regions in the buffer
    - `Memory` - Handles memory usage and limits
    - `Scrollback` - Manages scrollback buffer operations
    - `Buffer` - Handles buffer operations and synchronization
    - `Manager` - Main facade that coordinates all components
  - Improved code organization and maintainability
  - Enhanced test coverage for each specialized module
  - Better error handling and state management
  - Clearer interfaces between components
  - Comprehensive documentation for all modules
- **Dependency Resolution System Improvements:**
  - Enhanced version constraint handling with support for complex requirements (e.g., ">= 1.0.0 || >= 2.0.0")
  - Implemented Tarjan's algorithm for efficient cycle detection and component identification
  - Added detailed dependency chain reporting for better error diagnostics
  - Improved version parsing with comprehensive error handling
  - Optimized dependency graph operations for better performance
  - Added type specifications for better documentation and type safety
- **CSI Handlers Refactoring:**
  - Refactored `CSIHandlers` module to delegate command handling to specialized modules
  - Created specialized handlers for cursor, buffer, erase, device, and mode operations
  - Added comprehensive test coverage and improved error handling
  - Standardized parameter handling across all handlers
  - Added TODOs for future improvements in window manipulation
- **Test Infrastructure Improvements:**
  - Added unique state tracking for test plugins using `state_id` and timestamps
  - Enhanced plugin test fixtures with better state management
  - Added comprehensive metadata validation testing
  - Improved resource cleanup in plugin lifecycle
  - Event-based test synchronization replacing all `Process.sleep` calls
  - System interaction adapter pattern for testable system calls
  - High-contrast mode support and reduced motion preference
- **Performance Testing Infrastructure:**
  - New `Raxol.Test.PerformanceHelper` module for benchmarking
  - Performance test suite for terminal manager
  - Performance requirements and metrics collection
  - Event processing benchmarks (< 1ms average, < 2ms 95th percentile)
  - Screen update benchmarks (< 2ms average, < 5ms 95th percentile)
  - Concurrent operation benchmarks (< 5ms average, < 10ms 95th percentile)
- **Terminal Refactoring (Complete):**
  - Created specialized managers for buffer, cursor, state, command, style, parser, and input operations
  - All new modules have comprehensive test coverage
  - Improved code organization and maintainability
  - Reduced complexity in `emulator.ex`
- **Plugin System Behaviors:**
  - Completed and documented all plugin system behavior modules
  - Each behavior module includes comprehensive documentation and clear callback specifications
  - Consistent patterns for error handling and state management
- **Color System Refactoring:**
  - Implemented centralized color system architecture
  - Created specialized modules for color management
  - Enhanced accessibility integration
  - Improved theme management
  - Added color palette management and utilities
- **API Improvements:**
  - Renamed `border/2` to `border_wrap/2` for better clarity and consistency
  - Updated macro versions to use `border_wrap` instead of `border`
  - Updated documentation to reflect the new function name
  - Updated table view to use the new `border_wrap` function
  - Maintained same functionality while improving API clarity
- **Plugin Lifecycle Testing:**
  - Added comprehensive test suite for plugin lifecycle events
  - Added configuration management tests
  - Added concurrent operations tests
  - Added plugin communication tests
  - Added error recovery tests
  - Enhanced test isolation and cleanup
  - Improved state management verification
  - Added resource cleanup validation

### Changed

- **Test Reliability:**
  - Replaced all `Process.sleep` calls with event-based synchronization
  - Enhanced plugin test fixtures with better state management
  - Improved error handling and reporting
  - Better resource cleanup in plugin lifecycle
  - Clear test boundaries for plugin operations
- **Documentation:**
  - Updated color system documentation
  - Enhanced theming guide
  - Improved accessibility color integration docs
  - Updated architecture documentation
  - Refined roadmap and next steps
  - Reorganized and harmonized all component system documentation (README, ARCHITECTURE.md, API reference, architecture guide) with improved cross-linking and unified lifecycle/terminology.
  - Consolidated large file and test helper file refactoring tracking into docs/changes/LARGE_FILES_FOR_REFACTOR.md

### Deprecated

- Old event system
- Legacy rendering approach
- Previous styling methods
- `Raxol.Terminal.CommandHistory` (Use `Raxol.Terminal.Commands.History` instead)

### Removed

- **PluginSystem:** Removed redundant `Raxol.Core.Runtime.Plugins.Commands` GenServer
- Removed redundant clipboard modules
- `Raxol.UI.Components.ScreenModes` module and associated tests/references
- Removed `:meck` direct usage from test files
- Deleted `test/core/runtime/plugins/meck_sanity_check_test.exs`

### Fixed

- **Test Infrastructure:**
  - Fixed Mox compilation errors and setup issues
  - Resolved test reliability issues across multiple test files
  - Improved test cleanup and resource management
  - Enhanced test synchronization and isolation
  - Fixed various test setup and teardown issues
- **Component System:**
  - Fixed various component test failures
  - Improved component state management
  - Enhanced event handling
  - Fixed rendering assertions
  - Corrected test setup issues
- **Terminal Emulation:**
  - Fixed state propagation issues
  - Corrected command parsing/execution logic
  - Improved cursor management
  - Enhanced screen updates
  - Fixed mode handling and SGR attributes
- **Accessibility:**
  - Fixed announcement handling
  - Corrected text scaling behavior
  - Improved theme integration
  - Enhanced high-contrast mode support

### Current Status (2025-05-10)

- **Test Suite:** `49 doctests, 1528 tests, 279 failures, 17 invalid, 21 skipped`
- **Documentation:** Updated to reflect new component system architecture
- **Next Steps:** Focus on test stabilization and OSC 4 handler implementation

### Upcoming Work

- **Test Suite Stabilization:**

  - Address remaining 279 test failures and 17 invalid tests
  - Complete plugin system error handling tests
  - Fix FileWatcher related failures
  - Complete SelectList implementation
  - Document skipped tests

- **Performance Optimization:**

  - Fix performance test failures (host_component_id undefined)
  - Optimize event processing
  - Improve concurrent operation handling
  - Implement proper performance metrics

- **Integration Testing:**

  - Fix remaining integration test failures
  - Enhance test coverage for edge cases
  - Improve test isolation and cleanup
  - Add more comprehensive event testing

- **Documentation:**

  - Re-implement robust anchor checking in pre-commit script
  - Create test writing guide
  - Update API documentation with new features
  - Add examples for new functionality
  - Document plugin system improvements

- **Code Quality:**
  - Investigate potential text wrapping off-by-one error
  - Continue refactoring large files
  - Identify and extract more common utilities
  - Improve error handling and logging
  - Enhance plugin system error reporting
