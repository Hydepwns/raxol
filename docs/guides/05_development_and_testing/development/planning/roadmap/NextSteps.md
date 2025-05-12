---
title: Next Steps
description: Immediate priorities and upcoming work for Raxol Terminal Emulator
date: 2025-05-10
author: Raxol Team
section: roadmap
tags: [roadmap, next-steps, priorities]
---

# Next Steps

## Immediate Priorities

1. **Test Suite Stabilization**

   - [x] Resolve compilation errors blocking test suite runs
   - [x] Fix Manager.Behaviour/mock issue in file watcher tests to unblock test suite
   - [ ] Re-run test suite and update failure/skipped/invalid counts
   - [ ] Address remaining test failures (count will be updated after next successful run)
   - [ ] Focus on Plugin System Tests:
     - [x] Fix plugin lifecycle management
     - [x] Resolve command registration issues
     - [x] Address plugin event handling tests
     - [ ] Address state management problems
     - [ ] Add comprehensive error handling tests
     - [x] Enhance dependency resolution tests
   - [x] Fix FileWatcher compilation error
   - [ ] Address remaining FileWatcher runtime failures
   - [x] Complete SelectList implementation
   - [x] Restore and fix Raxol.Terminal.DriverTestHelper (helper import, pattern match, and assertion issues resolved; test suite now proceeds past helper errors)
   - [x] Document skipped tests in `test_tracking` document
   - [x] Add unit and integration tests for terminal memory management (estimate_memory_usage/1)
   - [x] Prioritize unskipping tests that are blocked only by minor refactors or helper updates. (See prioritized table in test_tracking.md)

2. **Performance Optimization**

   - [ ] Fix performance test failures (host_component_id undefined)
   - [ ] Optimize event processing
   - [ ] Improve concurrent operation handling
   - [ ] Implement proper performance metrics

3. **Integration Testing**
   - [ ] Fix remaining integration test failures
   - [ ] Enhance test coverage for edge cases
   - [ ] Improve test isolation and cleanup
   - [ ] Add more comprehensive event testing

## Completed Tasks

1. **Plugin Lifecycle Testing**

   - [x] Added comprehensive test suite for plugin lifecycle events
   - [x] Added configuration management tests
   - [x] Added concurrent operations tests
   - [x] Added plugin communication tests
   - [x] Added error recovery tests
   - [x] Enhanced test isolation and cleanup
   - [x] Improved state management verification
   - [x] Added resource cleanup validation
   - [x] Restore and fix terminal driver test helper (import ExUnit, pattern match, assertion fixes)

2. **Terminal Buffer Management Refactoring**

   - [x] Split `manager.ex` into specialized modules:
     - [x] `State` - Buffer initialization and state management
     - [x] `Cursor` - Cursor position and movement
     - [x] `Damage` - Damaged regions tracking
     - [x] `Memory` - Memory usage and limits
     - [x] `Scrollback` - Scrollback buffer operations
     - [x] `Buffer` - Buffer operations and synchronization
     - [x] `Manager` - Main facade for coordination
   - [x] Improved code organization and maintainability
   - [x] Enhanced test coverage for each module
   - [x] Better error handling and state management
   - [x] Clearer interfaces between components
   - [x] Comprehensive documentation for all modules

3. **Plugin System Improvements**

   - [x] Enhanced dependency management:
     - [x] Added version requirement support
     - [x] Improved circular dependency detection
     - [x] Enhanced dependency resolution
   - [x] Improved command handling:
     - [x] Added command validation
     - [x] Enhanced error handling
     - [x] Improved timeout handling
   - [x] Enhanced plugin lifecycle:
     - [x] Improved state persistence during reloads
     - [x] Added comprehensive cleanup
     - [x] Enhanced error handling

4. **Color System Integration**

   - [x] Implemented OSC 4 handler with comprehensive color format support:
     - [x] RGB hex formats (rgb:RRRR/GGGG/BBBB, #RRGGBB, #RGB)
     - [x] RGB decimal format (rgb(r,g,b))
     - [x] RGB percentage format (rgb(r%,g%,b%))
   - [x] Added comprehensive color palette tests
   - [x] Fixed theme consistency tests
   - [x] Enhanced accessibility color tests

5. **Component System**

   - [x] Fixed Table component implementation:
     - [x] Pagination state management
     - [x] Sorting with proper type comparisons
     - [x] Event handling for keyboard navigation
     - [x] Row selection functionality
     - [x] Scroll position calculation
   - [x] Improved test framework:
     - [x] Added standardized test setup helpers
     - [x] Added common assertion helpers
     - [x] Added event testing helpers
     - [x] Added performance testing helpers
     - [x] Updated testing documentation

6. **Test Infrastructure**

   - [x] Fixed compilation errors in helpers and integration tests
   - [x] Resolved device handler and application issues
   - [x] Fixed plugin API and component integration helpers
   - [x] Improved test isolation and cleanup
   - [x] Enhanced test documentation

7. **Editor Implementation**

   - [x] Implemented line operations:
     - [x] Insert lines with proper shifting
     - [x] Delete lines with proper shifting
   - [x] Implemented character operations:
     - [x] Insert characters with proper shifting
     - [x] Delete characters with proper shifting
     - [x] Erase characters with proper style handling
   - [x] Implemented screen operations:
     - [x] Clear screen with multiple modes
     - [x] Clear line with multiple modes
     - [x] Clear rectangular regions
   - [x] Added scrollback management:
     - [x] Proper scrollback clearing
     - [x] Integration with screen operations
   - [x] Added comprehensive documentation:
     - [x] Detailed function documentation
     - [x] Type specifications
     - [x] Usage examples
     - [x] Edge case handling

8. **Memory Management Test Coverage**

   - [x] Added both unit and integration-style tests for `Raxol.Terminal.MemoryManager.estimate_memory_usage/1` using real and mock state structs.
   - [x] Ensured robust coverage for memory usage estimation in terminal state.

9. **Character Sets Aliasing Issues**

   - [x] Fix CharacterSets aliasing issues in terminal and test modules (completed 2025-05-10)
   - [x] All CharacterSets aliasing issues resolved; codebase now consistently uses Raxol.Terminal.CharacterSets

## Future Considerations

1. **Documentation**

   - [x] Re-implement robust anchor checking in pre-commit script
   - [x] Create test writing guide
   - [x] Component system API, lifecycle, and architecture documentation is now harmonized and cross-linked.
   - [ ] Add examples for new functionality
   - [ ] Document plugin system improvements

2. **Code Quality**

   - [ ] Investigate potential text wrapping off-by-one error
   - [ ] Continue refactoring large files (see docs/changes/LARGE_FILES_FOR_REFACTOR.md for tracking and guidelines)
   - [ ] Track large or growing test helper files in the same document
   - [ ] Identify and extract more common utilities
   - [ ] Improve error handling and logging
   - [ ] Enhance plugin system error reporting

3. **Feature Development**
   - [ ] Enhance plugin system capabilities
   - [ ] Improve component system flexibility
   - [ ] Add more terminal features
   - [ ] Optimize performance further

## Notes

- The test suite now compiles and runs successfully
- Focus is on fixing failing tests rather than compilation errors
- Terminal buffer management refactoring has significantly improved code organization
- Plugin system improvements have enhanced stability and reliability
- Color system implementation is complete and well-tested
- Component system improvements have significantly enhanced stability
- Editor implementation is complete with comprehensive functionality
- Next major focus is on performance optimization and remaining test failures
- Component system documentation is now unified, harmonized, and cross-linked across all major docs.
- All CharacterSets aliasing issues are resolved; no further action required for alias cleanup.

## Current Test Suite Status (2025-05-10)

- **Overall:** File watcher test compilation error resolved. Basic state initialization implemented. Next step is to run test suite and address remaining failures.
- **Next Steps:** Focus on resolving remaining runtime failures, then test stabilization and performance optimization

## Immediate Test Suite Remediation Checklist (2025-05-10)

1. **Triage & Categorize Failures:**

   - [x] Run `mix test` and collect all failures/skipped/invalid tests
   - [x] Categorize by subsystem (core, terminal, plugin, component, color system, etc.)
   - [x] Create detailed failure report with stack traces
   - [x] Identify patterns in failures (e.g., timing issues, missing implementations)
   - [x] Create dependency graph of failing tests

2. **Prioritize by Subsystem:**

   - [x] Address in this order: Core/Terminal > Plugin > Component > Color > Integration/Performance
   - [x] Create dependency graph of failing tests
   - [x] Identify blocking issues that prevent other fixes
   - [x] Set up test isolation for each subsystem
   - [x] Create test execution plan

   **Plugin System Tests**

   - [x] Fix plugin lifecycle test issues
   - [x] Address plugin command registration tests
   - [x] Address plugin event handling tests
   - [ ] Fix plugin state management tests
   - [ ] Implement proper cleanup in plugin tests
   - [ ] Add comprehensive plugin error handling tests
   - [x] Enhance plugin dependency resolution tests

3. **Review & Update Failing/Skipped/Invalid Tests:**

   - [x] For each category, review test files and errors
   - [x] Update tests to use new APIs and correct signatures
   - [x] Refactor deprecated usage as needed
   - [x] Add proper test documentation
   - [x] Implement missing test helpers
   - [x] Fix test isolation issues

4. **Fix Code & Tests:**

   - [x] Fix implementation bugs and update code for new patterns
   - [x] Add/adjust mocks for system adapters (Mox)
   - [x] Implement missing functions and behaviours
   - [x] Fix timing and synchronization issues
   - [x] Add proper error handling
   - [x] Fix test cleanup issues

5. **Document Skipped/Invalid Tests:**

   - [ ] For each skipped/invalid test, document the reason
   - [ ] Add comments in test files
   - [ ] Create tracking document for skipped tests
   - [ ] Plan for future implementation of skipped features
   - [ ] Update test documentation
   - [ ] Create test status report

6. **Re-run & Track Progress:**

   - [x] Re-run `mix test` after each batch of fixes
   - [x] Track failures/invalid/skipped counts
   - [x] Watch for regressions
   - [x] Update progress in this document
   - [x] Create test coverage report
   - [x] Monitor test execution time

7. **Update Helpers & Documentation:**

   - [x] Update test helpers and documentation
   - [x] Ensure all new/updated code is covered by tests
   - [x] Add examples to documentation
   - [x] Update API documentation
   - [x] Create test writing guide
   - [x] Add test troubleshooting guide

8. **Summarize & Hand Off:**
   - [ ] When failures are resolved, summarize fixes
   - [ ] Document lessons learned
   - [ ] Update this checklist
   - [ ] Create final test suite report
   - [ ] Plan for future test improvements
   - [ ] Create test maintenance guide

### Current Progress (2025-05-10)

- [x] Compilation errors in helpers and integration tests resolved
- [x] Device handler, application, plugin API, and component integration helpers fixed
- [x] Character set translation and handler issues fixed
- [x] Accessibility module compile error resolved
- [x] File watcher compilation error resolved and basic state initialization implemented
- [ ] `test/raxol/terminal/emulator_plugin_test.exs`: Starting work on pending state management, metadata, and error handling tests. (Lifecycle, event, command handler tests previously updated, details in CHANGELOG). Setup for conditional plugin reloading for persistence tests is complete. Next: implement state persistence/reload logic in the relevant test.
- [x] Plugin system improvements:
  - [x] Enhanced dependency management with version requirements
  - [x] Improved command registration and validation
  - [x] Added robust plugin lifecycle management
  - [x] Enhanced state persistence during reloads
  - [x] Added comprehensive error handling
- [x] Animation test suite updated and improved:
  - [x] Added event-based testing
  - [x] Improved test isolation
  - [x] Added performance testing
  - [x] Enhanced accessibility integration
  - [x] Added comprehensive easing tests
- [x] Table component test setup now starts renderer correctly; renderer-related test failures resolved
- [x] Table component implementation improved:
  - [x] Fixed pagination state management
  - [x] Improved sorting implementation
  - [x] Enhanced event handling
  - [x] Added row selection
  - [x] Fixed scroll position calculation
- [x] Test framework improvements:
  - [x] Added standardized test setup helpers
  - [x] Added common assertion helpers
  - [x] Added event testing helpers
  - [x] Added performance testing helpers
  - [x] Updated testing documentation
- [x] Integration test improvements:
  - [x] Fixed cursor position handling
  - [x] Updated component hierarchy tests
  - [x] Enhanced chart integration tests
  - [x] Improved border and padding tests
  - [x] Added grid layout tests
- [x] Editor implementation completed:
  - [x] Added line operations (insert/delete)
  - [x] Added character operations (insert/delete/erase)
  - [x] Added screen operations (clear screen/line/region)
  - [x] Added scrollback management
  - [x] Added comprehensive documentation
- [ ] Performance test failures (host_component_id undefined) in progress
- [ ] Plugin system test failures under investigation
- [ ] Integration/Performance test failures in queue
- [x] Fix SelectList component implementation
- All advanced SelectList features (custom rendering, filtering, navigation, empty state, case insensitivity) are now covered by real tests.

## Additional Notes

- [ ] Prioritize unskipping tests that are blocked only by minor refactors or helper updates (e.g., visual/snapshot tests, alignment/layout, missing helpers, minor API changes). Review and update these before tackling feature-blocked or obsolete tests.

## Mox Mock Definition Cleanup

- [x] Fixed all Mox compile errors due to duplicate LoaderMock/FileWatcherMock definitions
- [x] All plugin system tests now use global mocks defined in test_helper.exs

- [x] Enhanced dependency resolution tests (now all pass, including cycle detection and optional version mismatch handling).
- [x] Dependency manager's Tarjan resolver and optional dependency handling are now correct and fully tested.
