---
title: Next Steps
description: Documentation of next steps in Raxol Terminal Emulator development
date: 2024-06-05
author: Raxol Team
section: roadmap
tags: [roadmap, next steps, planning]
---

# Next Steps for Raxol Development

## Current Status Overview

The project has completed its foundational phases (1-3) and significant parts of Phase 4.
Key recent accomplishments include:

- **Major Codebase Reorganization:** Completed according to plan.
- **Core Runtime Implementation:** Functional runtime loop, input processing, rendering pipeline (theming, borders).
- **Plugin System Enhancements:** Implemented dependency sorting, command handling/delegation, basic reloading, event filtering.
- **Command Execution Flow:** Verified basic command handling (e.g., `:quit`).
- **Compiler Cleanliness:** Project compiles cleanly without warnings or errors.
- **VS Code Extension Integration:** Core communication bridge, rendering, and input handling functional.
- **Dashboard & Visualization:** Layout system, core visualizations, and persistence implemented.
- **Testing Framework:** Comprehensive framework and tooling in place.
- **Theme System:** Core functionality, API, and persistence implemented.

**Immediate Focus:**

- Ensuring all examples are 100% functional.
- Writing comprehensive tests for recently added features (Runtime, Dispatcher, Renderer, PluginManager).
- Refining the Plugin System (Command Registry details, Reloading robustness).
- Implementing core command handlers (e.g., clipboard, notify).
- Completing the features outlined in `FeaturesToEmulate.md`.
- Continuing native terminal environment testing and TUI enhancements.
- Performance analysis and optimization.
- Documentation expansion.

## Tactical Next Steps

1.  **Ensure Functional Examples:** Review and fix all examples in `@examples` directory.
2.  **Write More Tests:**
    - Add tests for `PluginManager` (discovery, load order, command delegation, reload).
    - Add tests for `Runtime` main loop and `Dispatcher` interactions.
    - Add tests for `Renderer` edge cases (e.g., zero-width borders).
3.  **Refine Plugin System:**
    - Enhance `CommandRegistry` & `PluginManager` to handle command namespaces/arity properly.
    - Improve robustness of `reload_plugin_from_disk`.
4.  **Implement Core Commands:** Create plugins or core logic to handle `:clipboard_write`, `:clipboard_read`, `:notify` commands.
5.  **Complete `FeaturesToEmulate.md`:**
    - Refine `Table` component rendering.
    - Implement advanced command parsing features (Artificery-inspired).
    - Implement help text generation.
    - Enhance Burrito release integration.
6.  **Native Terminal Environment Testing & TUI Enhancements:**
    - Continue verifying TUI rendering, themes, layout management.
    - Test cross-platform compatibility for core features.
    - Test visualization components in terminal mode.
    - Ensure proper window resizing and event handling.
7.  **Performance Optimization:**
    - Profile visualization performance with large datasets.
    - Benchmark performance metrics in both VS Code and native terminal environments.
    - Implement further caching for visualization calculations.
    - Investigate reported performance degradation with complex dashboards.
    - Investigate memory usage patterns with large datasets.
8.  **Documentation Expansion:**
    - Create comprehensive user guides.
    - Update API documentation reflecting refactoring and new features.
    - Create tutorials for common workflows (Dashboard setup, Plugin usage).
    - Document theme customization process.

## Immediate Development Priorities

| Task                          | Description                                                        | Status      |
| ----------------------------- | ------------------------------------------------------------------ | ----------- |
| Functional Examples           | Review and fix all examples                                        | ToDo        |
| Write Tests                   | Add tests for Runtime, Dispatcher, Renderer, PluginManager         | ToDo        |
| Refine Plugin System          | Improve Command Registry (namespace/arity), Reloading robustness   | ToDo        |
| Implement Core Commands       | Handle clipboard, notify, etc.                                     | ToDo        |
| Complete FeaturesToEmulate.md | Refine Table, Add Command Parsing, Help Text, Release Integration  | ToDo        |
| Native Terminal Testing       | Continue testing & TUI enhancements in native terminal             | In Progress |
| Performance Analysis & Opt.   | Profile, benchmark, implement caching, investigate reported issues | In Progress |
| Documentation Updates         | Create user guides, update API docs                                | In Progress |
| Cross-Platform Compatibility  | Complete systematic testing across platforms                       | In Progress |

## Technical Implementation Plan

### Timeline for Next ~4 Weeks

| Week   | Focus                                 | Tasks                                                                                                                                                                           |
| ------ | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Week 1 | Examples & Tests                      | - Review/Fix all examples in `examples/` <br>- Start writing tests for PluginManager & Runtime/Dispatcher<br>- Begin refining CommandRegistry for namespace/arity               |
| Week 2 | Tests & Core Commands                 | - Continue writing tests (Renderer)<br>- Implement core command handlers (Clipboard, Notify) via plugins<br>- Start refining Table component rendering (`FeaturesToEmulate.md`) |
| Week 3 | Plugin Refinement & FeaturesToEmulate | - Improve plugin reload robustness<br>- Implement advanced command parsing features & help text generation<br>- Continue native terminal testing                                |
| Week 4 | Performance & Documentation           | - Continue performance optimizations (profiling, caching)<br>- Start writing user guides/tutorials<br>- Continue cross-platform testing & native terminal enhancements          |

## Additional Visualization Types

After completing the current priorities, we plan to implement additional visualization types:

1. **Line Charts**

   - Time series data representation
   - Multi-line comparison
   - Customizable line styles and markers

2. **Scatter Plots**

   - Data point distribution visualization
   - Correlation analysis
   - Customizable point styles and sizes

3. **Heatmaps**
   - Density visualization
   - Color-coded data representation
   - Configurable color schemes

## Testing Strategy Updates

### Test Categories for Native Terminal

1. **Environment Specific Tests**

   - Terminal initialization and cleanup
   - Window resizing and content adjustment
   - Keyboard navigation and shortcuts
   - Terminal-specific features (cursor styles, etc.)
   - Theme display and switching in terminal mode

2. **Performance Benchmarks**
   - Rendering speed with various terminal emulators
   - Memory usage patterns
   - CPU utilization during complex operations

### Test Automation

- Create automated test scripts for terminal environment
- Implement CI pipeline for terminal-specific tests
- Add performance regression detection

### GitHub Actions Testing

- Using `act` for local testing and debugging GitHub Actions workflows
- Docker images optimized for ARM MacOS developers (via Orbstack)
- Environment parity between local dev and CI environments
- Testing across multiple Erlang/Elixir versions and platforms
- Robust database setup for both Linux (via services) and macOS (local install)

## Contribution Areas

For developers interested in contributing to Raxol, here are key areas where help is needed:

1. **Additional Visualization Types**

   - Implementation of new chart types
   - Data transformation utilities
   - Interactive visualization elements

2. **Performance Optimization**

   - Rendering pipeline improvements
   - Memory usage optimization
   - Caching strategies for visualization data

3. **Theme Systems Enhancements**

   - Additional theme presets
   - Theme customization improvements
   - Accessibility-focused themes

4. **Documentation**

   - User guide creation
   - API documentation updates
   - Tutorial development

5. **Accessibility Enhancements**

   - Screen reader compatibility
   - Keyboard navigation improvements
   - Color contrast adjustments

6. **Testing Framework**
   - Additional mock components
   - Visual testing enhancements
   - Performance testing utilities

## Resources and References

- Visualization Plugin: `VisualizationPlugin`
- Dashboard Layout: `Dashboard.ex`, `GridContainer.ex`, `WidgetContainer.ex`
- Testing Framework: `test_plan.md`, `scripts/vs_code_test.sh`, `scripts/native_terminal_test.sh`, `ButtonHelpers.ex`
- Theme System Implementation: `ThemeManager.ts`, `ThemeSelector.ts`, `theme_config.ex`, `ThemeConfigPage.ts`
- Button Component Implementation: `button.ex`, `button_test.exs`
- Project Structure: See updated README.md
- CI/CD: `.github/workflows/`, `docker/`, `scripts/run-local-actions.sh`

## Future Roadmap

After completing the current priorities, we'll focus on:

1. **Advanced Visualization Interactive Features**

   - Data filtering and selection
   - Drill-down capabilities
   - Customizable tooltips and legends

2. **Real-time Collaboration Features**

   - Shared dashboard sessions
   - Collaborative editing
   - User presence indicators

3. **AI-assisted Configuration**
   - Smart layout suggestions
   - Data visualization recommendations
   - Automated dashboard generation
