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

The project has completed its foundational phases (1-3), including core architecture refactoring, comprehensive component and styling systems, and performance maturity work. Phase 4 is well underway (~50% complete), with significant milestones achieved:

- **Major Codebase Reorganization:** Completed according to plan.
- **VS Code Extension Integration:** Core communication bridge, rendering, and input handling implemented and functional.
- **Dashboard & Visualization:** Layout system, core visualizations (bar, treemap), and persistence are implemented and tested.
- **Testing Framework:** Comprehensive framework and tooling are in place.
- **Theme System:** Core functionality, API, and persistence implemented.
- **Critical Bug Fixes:** Addressed major runtime, database, and integration issues.

**Immediate Focus:**

- Resolving remaining compiler warnings (currently addressing unused functions).
- Completing native terminal environment testing and TUI enhancements.
- Performance analysis and optimization (profiling, benchmarking, caching).
- Documentation expansion (user guides, API updates).
- Completing cross-platform testing.

## Tactical Next Steps

1.  **Address Compiler Warnings:** Continue cleanup based on `handoff_prompt.md`, focusing on unused functions first.
2.  **Complete Native Terminal Environment Testing:**
    - Verify TUI rendering, themes, and layout management.
    - Test cross-platform compatibility for core features.
    - Test visualization components in terminal mode.
    - Ensure proper window resizing and event handling.
3.  **Performance Optimization:**
    - Profile visualization performance with large datasets.
    - Benchmark performance metrics in both VS Code and native terminal environments.
    - Implement further caching for visualization calculations.
    - Investigate reported performance degradation with complex dashboards.
    - Investigate memory usage patterns with large datasets.
4.  **Fix Remaining Technical Issues:**
    - Visually verify ImagePlugin rendering.
    - Test HyperlinkPlugin across OSes.
    - Investigate `ex_termbox` dimension inconsistencies.
    - Verify potential infinite loop and other runtime warnings.
    - Address `text_wrapping.ex` off-by-one issue.
5.  **Documentation Expansion:**
    - Create comprehensive user guides.
    - Update API documentation reflecting refactoring and new features.
    - Create tutorials for common workflows (Dashboard setup, Plugin usage).
    - Document theme customization process.
6.  **Complete Cross-Platform Testing:** Systematically test all core features across supported platforms (Linux, macOS, Windows).

## Immediate Development Priorities

| Task                         | Description                                                            | Status                              |
| ---------------------------- | ---------------------------------------------------------------------- | ----------------------------------- |
| Compiler Warning Cleanup     | Address remaining warnings (focus: next type, e.g., deprecated)        | In Progress (Unused Functions Done) |
| Native Terminal Testing      | Complete testing & TUI enhancements in native terminal                 | In Progress                         |
| Performance Analysis & Opt.  | Profile, benchmark, implement caching, investigate reported issues     | In Progress                         |
| Documentation Updates        | Create user guides, update API docs                                    | In Progress                         |
| Cross-Platform Compatibility | Complete systematic testing across platforms                           | In Progress                         |
| Fix Known Technical Issues   | Address specific runtime, component, plugin issues listed in `TODO.md` | ToDo                                |
| GitHub Actions Improvements  | Ensure CI covers all platforms/scenarios effectively                   | Completed                           |

## Technical Implementation Plan

### Timeline for Next ~4 Weeks

| Week   | Focus                               | Tasks                                                                                                                                                                                       |
| ------ | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Week 1 | Compiler Warnings & Native Terminal | - Address unused function warnings (Done)<br>- Address next warning type (e.g., deprecated Logger)<br>- Continue native terminal testing (rendering, layout, themes)<br>- Document findings |
| Week 2 | Performance & Native Terminal       | - Profile/Benchmark visualizations<br>- Begin implementing caching<br>- Complete native terminal testing (visualizations, events)<br>- Start fixing minor known issues                      |
| Week 3 | Documentation & Cross-Platform      | - Start writing user guides<br>- Update key API docs<br>- Begin systematic cross-platform testing                                                                                           |
| Week 4 | Performance & Documentation         | - Continue performance optimizations (caching, investigate issues)<br>- Continue user guides & tutorials<br>- Continue cross-platform testing                                               |

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
