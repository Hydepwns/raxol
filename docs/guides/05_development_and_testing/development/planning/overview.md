---
title: Raxol Planning Overview
description: Overview of planning and development for the Raxol TUI Framework
date: 2024-07-18 # Updated date
author: Raxol Team
section: planning
tags: [planning, overview, development, roadmap, future]
---

# Raxol: A Comprehensive TUI Framework for Elixir

This document outlines the strategic vision and development plan for Raxol, a comprehensive terminal application toolkit for Elixir, inspired by the capabilities of Charm.sh and built upon a refined Elm-style architecture. It aims to provide a robust ecosystem for building rich, interactive terminal UIs, potentially integrated with distribution via Burrito.

## Core Raxol Features (Present & Future)

### Modular Ecosystem

Raxol is structured as a modular system, allowing developers to leverage different parts as needed:

1. **Raxol Core (`lib/raxol/core/`)**
   - Refined Elm Architecture implementation (Application behaviour, Dispatcher). _(Implemented)_
   - Optimized rendering engine (`Core.Runtime.Rendering`). _(Basic pipeline functional, ongoing performance improvements)_
   - Efficient event handling (`Core.Runtime.Events`). _(Implemented)_
   - BEAM-leveraged concurrency model (Supervision, process isolation). _(Implemented)_
   - _Future:_ Framerate-based rendering for smoother animations.
2. **Style System (`lib/raxol/ui/theming/`, `lib/raxol/core/color_system/`)**
   - Declarative styling library integrated with `View.Elements`. _(Implemented)_
   - Theme-aware, comprehensive color support (`ColorSystem`). _(Implemented, supports ANSI/TrueColor via Terminal Driver)_
   - Box model (content, padding, border, margin) via `LayoutEngine` and `Renderer`. _(Implemented)_
   - Flexible layout system (Flexbox-inspired) via `LayoutEngine`. _(Implemented)_
   - Border styling (`Renderer`). _(Basic styles implemented, more planned)_
   - _Future:_ Full support for adaptive background detection, extended border styles (rounded, thick, double).
3. **Component Library (`lib/raxol/ui/components/`)**
   - Suite of pre-built, customizable components using `Base.Component` behaviour. _(Implemented, growing suite)_
   - Existing Components: Text inputs (single, multi-line), Selection (select*list, dropdown), Progress (spinner, progress_bar), Data display (table), etc.*(See `docs/guides/components/README.md`)\_
   - Focus management system (`Core.FocusManager`). _(Implemented)_
   - Standardized component API (`Base.Component`). _(Implemented)_
   - _Future:_ Dedicated navigation components (tabs, pagination), password input variant, multi-select enhancements.
4. **Form System (Future Goal)**
   - _Goal:_ Build a form framework inspired by `huh?`.
   - _Goal:_ Implement field types (Input, Text, Select, MultiSelect), validation, accessibility features, data binding.

## Advanced Features & Ecosystem Goals (Future Work)

This section outlines features and tools planned for future development, either as integrated parts of the Raxol library or as complementary tools within the Raxol ecosystem.

### Integrated Library Features

1. **Animation System**
   - _Goal:_ Develop physics-based animation capabilities (`Harmonica` equivalent).
   - _Goal:_ Create easing functions and a frame-based controller, respecting reduced motion.
2. **Markdown Rendering**
   - _Goal:_ Build a terminal-optimized markdown display component (`Glow` equivalent).
   - _Goal:_ Add syntax highlighting and theming options.

### Potential Ecosystem Tools

1. **CLI Enhancement Tools**
   - _Goal:_ Develop standalone utilities or library functions for enhancing shell scripts (`Gum` equivalent).
   - _Goal:_ Include input collectors, selection interfaces, prompts, progress indicators.
2. **Terminal Recording**
   - _Goal:_ Create a tool for recording terminal sessions as GIFs (`VHS` equivalent).
   - _Goal:_ Implement programmable input simulation and timing controls.

## Burrito Integration (Exploratory / Future)

### Packaging and Distribution

- **Goal:** Explore seamless Burrito integration for easy application packaging and distribution.
- **Goal:** Simplify configuration and aim for cross-platform builds (Linux, macOS, Windows).
- **Considerations:** Address potential startup time issues, explore optimizations (lazy-loading, binary size), and manage native dependencies/NIFs.

## High-Level Roadmap Phases

- **Phase 1: Foundation** _(Largely Complete)_
  - Refactor core architecture.
  - Develop basic styling system.
  - Create essential UI components.
- **Phase 2: Feature Expansion** _(In Progress)_
  - Enhance styling system (color depth, borders).
  - Expand component library (add missing types, refine existing).
  - Improve rendering performance and efficiency.
  - Solidify core APIs and documentation.
- **Phase 3: Advanced Capabilities** _(Future)_
  - Implement Animation System.
  - Implement Markdown Rendering.
  - Begin work on Form System.
  - Explore CLI Enhancement Tools & Terminal Recording concepts.
- **Phase 4: Polish & Ecosystem** _(Future)_
  - Performance optimization and benchmarking.
  - Comprehensive cross-platform testing.
  - Extensive documentation, tutorials, and examples.
  - Showcase applications.
  - Mature Burrito integration (if pursued).

## Development Approach

### Community-Driven Design

1. **Collaborative Architecture:** Engage with the Elixir community, use RFCs for major features, establish consistent design patterns.
2. **Testing Strategy:** Comprehensive unit/integration tests, explore visual regression testing.
3. **Documentation:** Aim for clear, concise, and practical guides, API docs, and examples.

## Technical Considerations

### Leveraging Elixir's Strengths

1. **Concurrency Model:** Utilize processes, supervision trees, message passing.
2. **Integration:** Maintain compatibility, explore Phoenix LiveView bridges, consider Nerves support.
3. **Addressing Limitations:** Develop strategies for startup time (if using Burrito), optimize rendering, consider cross-language interop if needed.

## Conclusion

Raxol aims to be a premier TUI framework in the Elixir ecosystem, offering a powerful and flexible toolkit inspired by best-in-class solutions. By combining a solid architectural foundation with a rich feature set and potentially seamless distribution, Raxol will empower developers to create sophisticated and delightful terminal applications.
