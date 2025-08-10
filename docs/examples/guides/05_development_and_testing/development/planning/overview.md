---
title: Raxol Planning Overview
description: Overview of planning and development for the Raxol TUI Framework
date: 2025-05-10
author: Raxol Team
section: planning
tags: [planning, overview, development, roadmap, future]
---

# Raxol: A Comprehensive TUI Framework for Elixir

_Raxol 0.8.0 is a full-stack terminal application framework with web interface support, plugin system, and enterprise features. Make sure you are using the latest version for the best experience!_

This document outlines the strategic vision and development plan for Raxol, a full-stack terminal application framework for Elixir. Built upon a component-based architecture, Raxol provides a comprehensive ecosystem for building sophisticated terminal applications that can run both locally and be accessed through web browsers, with support for plugins, real-time collaboration, and enterprise features.

## Core Raxol Features (Present & Future)

### Modular Ecosystem

Raxol is structured as a modular system, allowing developers to leverage different parts as needed:

1. **Raxol Core (`lib/raxol/core/`)**

   - Refined Elm Architecture implementation (Application behaviour, Dispatcher). _(Implemented)_
   - Optimized rendering engine (`Core.Runtime.Rendering`). _(Implemented with performance improvements)_
   - Efficient event handling (`Core.Runtime.Events`). _(Implemented with event-based testing)_
   - BEAM-leveraged concurrency model (Supervision, process isolation). _(Implemented)_
   - System Interaction Adapter pattern for testable system calls. _(Implemented)_
   - _Future:_ Framerate-based rendering for smoother animations.

2. **Style System (`lib/raxol/ui/theming/`, `lib/raxol/core/color_system/`)**

   - Declarative styling library integrated with `View.Elements`. _(Implemented)_
   - Theme-aware, comprehensive color support (`ColorSystem`). _(Implemented, supports ANSI/TrueColor via Terminal Driver)_
   - Box model (content, padding, border, margin) via `LayoutEngine` and `Renderer`. _(Implemented)_
   - Flexible layout system (Flexbox-inspired) via `LayoutEngine`. _(Implemented)_
   - Border styling (`Renderer`). _(Implemented)_
   - OSC 4 color palette management. _(Implemented)_
   - _Future:_ Full support for adaptive background detection, extended border styles.

3. **Component Library (`lib/raxol/ui/components/`)**

   - Suite of pre-built, customizable components using `Base.Component` behaviour. _(Implemented, growing suite)_
   - Existing Components: Text inputs (single, multi-line), Selection (select_list, dropdown), Progress (spinner, progress_bar), Data display (table), etc.
   - Focus management system (`Core.FocusManager`). _(Implemented)_
   - Standardized component API (`Base.Component`). _(Implemented)_
   - Comprehensive component testing infrastructure. _(Implemented)_
   - _Future:_ Dedicated navigation components (tabs, pagination), password input variant.

4. **Form System (Future Goal)**
   - _Goal:_ Build a form framework inspired by `huh?`.
   - _Goal:_ Implement field types (Input, Text, Select, MultiSelect), validation, accessibility features, data binding.

## Current Status and Priorities

### Immediate Priorities

1. **Test Suite Stabilization**

   - Address remaining test failures (279 failures, 17 invalid)
   - Document any tests that must remain skipped (21 skipped)
   - Focus on high-impact/core areas first

2. **Documentation**

   - Complete remaining ExDoc improvements
   - Update README examples
   - Implement robust anchor checking in pre-commit script

3. **Component System**
   - Complete remaining component enhancements
   - Improve test coverage
   - Document component APIs

### Recent Improvements

1. **Plugin System**

   - Successfully extracted functionality from `manager.ex` into specialized modules
   - Added tests for all newly extracted modules
   - Improved test isolation and reliability
   - Removed `Process.sleep` calls, improved cleanup, enhanced synchronization

2. **Terminal System**

   - Successfully completed terminal refactoring
   - Successfully refactored CSI command handling
   - Implemented DCS Sixel (`q`) handler
   - Transitioned from `:meck` to `Mox` for testing

3. **Component System**
   - Implemented `Table` features: pagination buttons, filtering, sorting
   - Implemented `FocusRing` styling based on state/effects
   - Enhanced `SelectList`: stateful scroll offset, robust focus management, search/filtering

## High-Level Roadmap Phases

- **Phase 1: Foundation** _(Complete)_

  - Refactored core architecture
  - Developed basic styling system
  - Created essential UI components
  - Implemented plugin system

- **Phase 2: Feature Expansion** _(In Progress)_

  - Enhanced styling system (color depth, borders)
  - Expanded component library
  - Improved rendering performance
  - Solidified core APIs and documentation
  - Implemented OSC 4 color palette management

- **Phase 3: Advanced Capabilities** _(Future)_

  - Implement Animation System
  - Implement Markdown Rendering
  - Begin work on Form System
  - Explore CLI Enhancement Tools & Terminal Recording concepts

- **Phase 4: Polish & Ecosystem** _(Future)_
  - Performance optimization and benchmarking
  - Comprehensive cross-platform testing
  - Extensive documentation, tutorials, and examples
  - Showcase applications
  - Mature Burrito integration (if pursued)

## Development Approach

### Community-Driven Design

1. **Collaborative Architecture:** Engage with the Elixir community, use RFCs for major features, establish consistent design patterns.
2. **Testing Strategy:** Comprehensive unit/integration tests, event-based synchronization, improved test isolation.
3. **Documentation:** Clear, concise, and practical guides, API docs, and examples.

## Technical Considerations

### Leveraging Elixir's Strengths

1. **Concurrency Model:** Utilize processes, supervision trees, message passing.
2. **Integration:** Maintain compatibility, explore Phoenix LiveView bridges, consider Nerves support.
3. **Addressing Limitations:** Develop strategies for startup time (if using Burrito), optimize rendering, consider cross-language interop if needed.

## Conclusion

Raxol aims to be a premier TUI framework in the Elixir ecosystem, offering a powerful and flexible toolkit inspired by best-in-class solutions. By combining a solid architectural foundation with a rich feature set and potentially seamless distribution, Raxol will empower developers to create sophisticated and delightful terminal applications.
