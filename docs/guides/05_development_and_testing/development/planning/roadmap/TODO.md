---
title: TODO List
description: List of pending tasks and improvements for Raxol Terminal Emulator
date: 2025-05-10
author: Raxol Team
section: roadmap
tags: [roadmap, todo, tasks]
---

# Raxol Project Roadmap

## Documentation (Ongoing)

- [x] Task 2.1-2.6: Complete Comprehensive Guides (Plugin Dev, Theming, VS Code Ext).
- [x] Task 4.1-4.3: Review/Improve ExDoc (`@moduledoc`, `@doc`, `@spec`) for key public modules.
- [x] Task 4.4: Test ExDoc Generation (`mix docs`).
- [x] Improve README Example.
- [x] **Component System Documentation:**
  - [x] Comprehensive API, lifecycle, and architecture documentation is now harmonized and cross-linked across README, ARCHITECTURE.md, API reference, and architecture guide.
  - [x] Add component lifecycle documentation
  - [x] Add component composition patterns guide
  - [x] Add testing patterns guide
  - [x] Add style guide for components
  - [x] Update component README with API reference links
- [x] **Testing Framework Documentation:**
  - [x] Document test helper modules
  - [x] Add examples for event-based testing
  - [x] Add performance testing guide
  - [x] Add troubleshooting section
  - [x] Update best practices
- [ ] **Pre-commit Script Maintenance (`scripts/pre_commit_check.exs`):**
  - [x] Improve file discovery to include hidden directories (e.g., `.github/`) and normalize paths.
  - [x] Explicitly include key project READMEs in the known file set.
  - [x] Temporarily disable anchor checking (`#anchor-links`) due to parsing complexities. File existence checks are active.
  - [ ] **Re-implement Robust Anchor Checking:** Develop a reliable method for parsing and validating anchor links within Markdown files for the pre-commit script.
- [x] Continue refactoring large files (see docs/changes/LARGE_FILES_FOR_REFACTOR.md for tracking and guidelines)
- [x] Track large or growing test helper files in the same document

## High Priority

- [x] Fix Manager.Behaviour/mock issue in file watcher tests to unblock test suite.
- [ ] Re-run test suite and update failure/skipped/invalid counts.
- [ ] Fix Test Failures: Address remaining test failures (count will be updated after next successful run).

## Medium Priority

- [ ] **Component Enhancements:**
  - [x] Implement `Table` features: pagination buttons, filtering, sorting.
  - [x] Implement `FocusRing` styling based on state/effects.
  - [x] Enhance `SelectList`: stateful scroll offset, robust focus management, search/filtering.
  - [x] Complete component system documentation
- [ ] **Performance Optimization:**
  - [ ] Fix performance test failures (host_component_id undefined)
  - [ ] Optimize event processing
  - [ ] Improve concurrent operation handling
  - [ ] Implement proper performance metrics

## Low Priority

- [ ] **Investigate/Fix Potential Text Wrapping Off-by-one Error:** (`lib/raxol/components/input/text_wrapping.ex`).
- [ ] **Extend System Interaction Adapter Pattern:** After achieving platform stability, systematically identify and refactor other relevant modules to use the System Interaction Adapter pattern.

## Current Test Suite Status (2025-05-10)

- **Overall:** File watcher test compilation error resolved. Basic state initialization implemented. Next step is to run test suite and address remaining failures.

## Test Suite Remediation Action Plan (2025-05-10)

### Test Categories and Priorities

1. **Core/Terminal Tests (Highest Priority)**

   - [x] Fix `integration_test.exs` failures (322, 246, 146, 13)
   - [x] Address `table_test.exs` failures (98, 86, 116)
   - [x] Fix assertion failures in core renderer tests
   - [x] Implement missing `View.row/1` and `View.flex/2` functions
   - [x] Fix `FileWatcher` compilation error
   - [ ] Address remaining `FileWatcher` runtime failures

2. **Plugin System Tests**

   - [x] Fix plugin lifecycle test issues
   - [x] Address plugin command registration tests
   - [x] Fix plugin state management tests
   - [x] Implement proper cleanup in plugin tests
   - [ ] Add comprehensive plugin error handling tests
   - [ ] Enhance plugin dependency resolution tests

3. **Component Tests**

   - [x] Fix `Table` component implementation
   - [ ] Fix `SelectList` component implementation
   - [x] Address table cell alignment tests
   - [ ] Fix component responsiveness tests
   - [ ] Implement missing component lifecycle hooks

4. **Color System Tests**

   - [x] Fix theme consistency tests
   - [x] Address color palette tests
   - [x] Fix accessibility color tests
   - [x] Implement OSC 4 handler tests

5. **Integration/Performance Tests**
   - [ ] Fix performance test failures
   - [ ] Address concurrent operation tests
   - [ ] Fix event processing tests
   - [ ] Implement proper performance metrics

### Detailed Action Steps

1. **Triage & Categorize Failures:**

   - [x] Run `mix test` and collect all failures/skipped/invalid tests
   - [x] Categorize by subsystem (core, terminal, plugin, component, color system, etc.)
   - [x] Create detailed failure report with stack traces
   - [x] Identify patterns in failures (e.g., timing issues, missing implementations)

2. **Prioritize by Subsystem:**

   - [x] Address in this order: Core/Terminal > Plugin > Component > Color > Integration/Performance
   - [x] Create dependency graph of failing tests
   - [x] Identify blocking issues that prevent other fixes
   - [x] Set up test isolation for each subsystem

3. **Review & Update Failing/Skipped/Invalid Tests:**

   - [x] For each category, review test files and errors
   - [x] Update tests to use new APIs and correct signatures
   - [x] Refactor deprecated usage as needed
   - [x] Add proper test documentation
   - [x] Implement missing test helpers

4. **Fix Code & Tests:**

   - [x] Fix implementation bugs and update code for new patterns
   - [x] Add/adjust mocks for system adapters (Mox)
   - [x] Implement missing functions and behaviours
   - [x] Fix timing and synchronization issues
   - [x] Add proper error handling

5. **Document Skipped/Invalid Tests:**

   - [ ] For each skipped/invalid test, document the reason
   - [ ] Add comments in test files
   - [ ] Create tracking document for skipped tests
   - [ ] Plan for future implementation of skipped features
   - [ ] Update test documentation

6. **Re-run & Track Progress:**

   - [x] Re-run `mix test` after each batch of fixes
   - [x] Track failures/invalid/skipped counts
   - [x] Watch for regressions
   - [x] Update progress in this document
   - [x] Create test coverage report

7. **Update Helpers & Documentation:**

   - [x] Update test helpers and documentation
   - [x] Ensure all new/updated code is covered by tests
   - [x] Add examples to documentation
   - [x] Update API documentation
   - [x] Create test writing guide

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
- [x] Terminal buffer management refactoring completed:
  - [x] Split into specialized modules
  - [x] Added comprehensive tests
  - [x] Improved code organization
  - [x] Enhanced error handling
  - [x] Added clear interfaces
  - [x] Added documentation
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
- [x] Color system improvements:
  - [x] Implemented OSC 4 handler with comprehensive color format support
  - [x] Added color palette tests
  - [x] Fixed theme consistency tests
  - [x] Enhanced accessibility color tests
- [x] Editor implementation completed:
  - [x] Added line operations (insert/delete)
  - [x] Added character operations (insert/delete/erase)
  - [x] Added screen operations (clear screen/line/region)
  - [x] Added scrollback management
  - [x] Added comprehensive documentation
- [ ] Performance test failures (host_component_id undefined) in progress
- [ ] Plugin system test failures under investigation
- [ ] Integration/Performance test failures in queue
