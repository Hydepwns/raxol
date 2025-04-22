---
title: TODO List
description: List of pending tasks and improvements for Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: roadmap
tags: [roadmap, todo, tasks]
---

# Raxol Project Roadmap

## Completed

- [x] Setup backend Elixir application structure including folder organization
- [x] Setup VS Code extension project structure with TypeScript
- [x] Implement basic process manager for terminal I/O (StdioInterface)
- [x] Set up terminal rendering and window/panel management with ExTermbox
- [x] Create debug logging system with runtime toggling
- [x] Implement environment-based configuration with appropriate defaults
- [x] Fix ExTermbox initialization failure with fallback mode
- [x] Fix database connection issues with robust error handling
- [x] Fix JSON communication issues through StdioInterface
- [x] Fix BEAM hang after clean GenServer termination
- [x] Create comprehensive testing framework with clear success/failure criteria
- [x] Implement user input handling & key events system
- [x] Create generic widget system for dashboard layouts
- [x] Implement bar chart visualization with appropriate scaling
- [x] Create treemap visualization with hierarchical layout
- [x] Implement dynamic data fetching for visualization components
- [x] Create size-adaptive test data for different terminal dimensions
- [x] Implement dashboard layout system with resizable widgets
- [x] Integrate visualization components with dashboard widgets
- [x] Add responsive visualization rendering in different widget sizes
- [x] Implement layout persistence with validation and error handling
- [x] Create automatic layout saving after significant changes
- [x] Create comprehensive test suite for dashboard layout system
- [x] Implement editor bridge to VS Code extension
- [x] Complete visualization testing in both environments
- [x] Implement TUI rendering enhancements for better display quality
- [x] Create layout persistence system with auto-recovery
- [x] Implement custom theme support with configurability (API documentation created)

## In Progress

- [ ] Enhance TUI rendering in native terminal with advanced styling
- [ ] Verify and fix `ex_termbox` dimension reporting inconsistencies
- [ ] Benchmark performance with complex dashboards
- [ ] Profile visualization rendering with large datasets
- [ ] Implement caching for visualization calculations
- [ ] Complete cross-platform testing
- [ ] Create comprehensive user documentation and guides
- [ ] Test native terminal environment functionality
- [ ] Benchmark performance metrics in both environments

## Backlog

- [ ] Implement additional visualization types (line charts, scatter plots)
- [ ] Add data filtering and selection capabilities to visualizations
- [ ] Create drill-down functionality for interactive visualizations
- [ ] Implement customizable tooltips and legends
- [ ] Add asset optimization for improved load times
- [ ] Enhance accessibility with screen reader support
- [ ] Create user-friendly dashboard customization interface
- [ ] Implement real-time collaborative features
- [ ] Add dashboard sharing and export functionality
- [ ] Implement AI-assisted dashboard configuration
- [ ] Add multi-language support for UI elements
- [ ] Add visual demo (screenshot/GIF) to README.md
- [ ] Resolve stubbed/incomplete Web Authentication & LiveView features in `lib/raxol_web/` (implement or remove)
- [ ] Address numerous code-level TODO comments (Terminal emulation details, component implementations, error handling, etc.)

## Issues to Investigate

- [ ] `ex_termbox` dimension reporting inconsistencies
- [ ] Performance degradation with multiple complex visualizations
- [ ] Memory usage patterns with large datasets
- [ ] Cross-platform compatibility issues
- [ ] Component: Text wrapping off-by-one issue (`text_wrapping.ex`)

## Testing Needs

- [ ] Test native terminal environment functionality
- [ ] Validate visualization rendering in different scenarios
- [ ] Test cross-platform compatibility
- [ ] Benchmark performance metrics

### IDE Integration (VS Code / Cursor)

- **Implement Backend Communication Bridge (TOP PRIORITY)**
  - [x] Define Communication Protocol (JSON over stdio): Specify message types (`initialize`, `ui_update`, `user_input`, etc.) and formats. (`docs/protocols/ExtensionBackendProtocol.md`)
  - [x] Implement Backend Process Management (`extensions/vscode/src/backendManager.ts`): Spawn/manage Elixir child process, handle stdio communication (send/receive JSON).
  - [x] Implement Basic Webview Panel (`extensions/vscode/src/raxolPanelManager.ts`): Create panel, load HTML/CSS/JS from `media/`, implement message relay (Webview <-> Extension <-> Backend).
  - [x] Implement Basic Webview Rendering/Input/Resize (`media/main.js`): Handle `ui_update`, `userInput`, `resize` messages.
  - [x] Implement Backend Stdio Communication Handling (`lib/raxol/stdio_interface.ex`, `lib/raxol/runtime.ex`): Conditionally use `StdioInterface` for JSON over stdio or `ex_termbox` for TTY.
  - [x] Fixed `Runtime.ex` compilation errors (init logic, TTY check, PluginManager start)
  - [x] Implement Cross-Component Logging: Added detailed logging in Extension (TS) and Backend (Elixir) for message tracing.
  - [x] **Verify Initial Connection Flow & Message Handling (via Logs):** TESTED - SUCCESSFUL. Backend successfully starts and communicates with the extension after implementing fixes.
  - [x] **Fix ExTermbox Initialization Issue:**
    - [x] Reviewed `RuntimeDebug.init` and `Runtime.init` to understand ExTermbox initialization.
    - [x] Added more detailed logging around ExTermbox initialization calls.
    - [x] Created a fallback mode that allows the application to continue without ExTermbox in the VS Code extension path.
    - [x] Set default dimensions when ExTermbox fails to initialize or returns errors.
  - [x] **Fix JSON Communication Format:**
    - [x] Implemented proper JSON formatting for messages sent from backend to extension.
    - [x] Added JSON markers to distinguish between JSON messages and log output.
    - [x] Added helper to wrap log messages in proper JSON format.
    - [x] Updated `BackendManager.ts` to handle both structured JSON and plain logs.
  - [x] **Implement VS Code Rendering Path:**
    - [x] Implemented a fallback render method that sends UI updates via StdioInterface.
    - [x] Converted complex cell data to a transport-friendly format.
    - [x] Added support for dimensions, cursor position, and cell attributes.
  - [x] **Implement User Input & Resize Handling**
    - [x] Enhance `user_input` message handling in `Runtime.ex` to convert WebView key events to app events.
    - [x] Map key codes and modifiers from VS Code WebView to app format.
    - [x] Complete `resize_panel` message handling to update dimensions.
    - [x] Create test scripts for both VS Code extension and native terminal environments.
    - [x] Run tests in both environments to verify functionality.
- **Architecture & Setup (Supporting)**
  - [x] Set up initial extension project structure (verified `package.json`, `extensions/vscode/src/extension.ts`).
  - [x] Plan detailed architecture for Webview <-> Elixir interaction. (**Protocol defined**)
  - [ ] Research frontend technologies (React, Vue, Svelte, etc.) for Webview UI (Decision Deferred).

### Comprehensive Testing Framework (NEW) ✅

- [x] **Design Testing Framework:**
  - [x] Create comprehensive test plan with clear success/failure criteria
  - [x] Define test categories for basic functionality, visualization, layout, edge cases, etc.
  - [x] Implement test results template for standardized reporting
- [x] **Implement Test Tooling:**
  - [x] Add performance monitoring functions to RuntimeDebug
  - [x] Create VS Code extension test script with automatic results generation
  - [x] Create native terminal test script with resource monitoring
  - [x] Implement visualization test data for edge cases
  - [x] Create test script for visualization components
- [x] **Test Data Preparation:**
  - [x] Create test data for empty sets
  - [x] Create test data for very large datasets
  - [x] Create test data for unicode/emoji
  - [x] Create test data for extreme values (negative, large, small)
  - [x] Create size-adaptive test data for different terminal dimensions

### Performance Optimization (Higher Priority)

- [ ] **Profile Visualization Performance:** Measure rendering time with multiple complex visualizations.
- [ ] **Implement Caching for Visualization Calculations:** Cache processed visualization data to avoid redundant calculations.
- [ ] **Optimize Large Dataset Rendering:** Improve performance when rendering large datasets in both VS Code and native terminal modes.
- [ ] **Responsiveness Scoring System:** Define metrics, create algorithm, visualize data.
- [ ] **Performance Regression Alerting:** Configure thresholds, notification system, CI integration.
- [ ] **Animation Performance Analysis:** Monitor frame rates, identify bottlenecks.
- [ ] **Asset Optimization:** Optimize large font files in `priv/static/fonts` directory.

### Plugin System Enhancements (TUI - Lower Priority)

- [ ] **ImagePlugin Stability/Visual Testing:** Verify image (`assets/static/images/logo.png`) rendering visually (**NEEDS VISUAL VERIFICATION (Escape Sequence Sent)**).
- [ ] **Hyperlink OS Interaction Testing:** Verify/test `HyperlinkPlugin.open_url/1` across different OSes. (**NEEDS TESTING (App Runs)**)
- [ ] **Investigate alternative rendering mechanisms if needed (ImagePlugin).**

### Documentation (Lower Priority)

- [ ] API documentation updates (reflect widget refactoring, new plugin).
- [ ] Performance tuning guidelines.
- [ ] Component lifecycle documentation.
- [ ] Event system best practices.
- [ ] Integration examples and tutorials (Dashboard, Plugins).
- [ ] Accessibility and internationalization integration guides.
- [x] Project structure documentation (added to README.md).

## Upcoming Features 🎯 (Adjust based on Extension Focus)

### Advanced Animation System (Webview Focused)

- Physics-based animations (within Webview)
- Gesture-driven interactions (within Webview)
- Animation sequencing and timelines
- Performance optimization for animations
- Accessibility improvements through AI

### Developer Experience Enhancement

- Comprehensive IDE support (via Extension)
- Advanced debugging tools (for Extension & Backend)
- Documentation improvements
- Code generation utilities

### UX Refinement Enhancements (Webview Focused)

- Touch screen gesture support (if applicable in Webview context)
- Advanced focus management patterns
- Shortcut customization interface
- Voice command integration

### Event System Enhancements (Core Backend)

- Event persistence layer
- Event replay functionality
- Advanced event filtering patterns
- Event transformation pipelines
- Custom event type definitions

### Developer Tools (Extension & Backend)

- Interactive event debugger (potentially integrated into Extension)
- Real-time event monitoring dashboard (potentially in Extension)
- Event flow visualization
- Performance profiling tools
- Metric visualization improvements
- Accessibility compliance checker

### Integration Features (Core Backend)

- External system connectors
- Event format adapters
- Protocol bridges
- Message queue integration
- WebSocket support (potentially for Extension communication?)
- Screen reader API integration

## Future Considerations 🔮

### Scalability

- Distributed event processing
- Cluster support
- Horizontal scaling capabilities
- Load balancing strategies
- Event partitioning
- AI-assisted accessibility adaptations

### Security

- Event encryption
- Access control system
- Audit logging
- Security compliance features
- Rate limiting
- Privacy considerations for user preferences

### Advanced Features

- Event sourcing patterns
- CQRS implementation
- Event versioning system
- Schema evolution
- Event replay with time travel
- Dynamic theme switching
- Advanced accessibility profiles

## Known Issues 🐞

- ~~**RUNTIME:** **BEAM VM hangs (break menu)** on `Ctrl+C`. Confirmed in stdio mode. **CURRENT BLOCKER for usability/extension development.** Native terminal test pending. **Incorrect Termbox cleanup in `terminate` might be related.**~~ **FIXED** by implementing more robust cleanup in terminate function with environment-specific handling.
- ~~**RUNTIME:** **Backend processing of `userInput` and `resize_panel` payloads is basic (logging only)**. Needs implementation.~~ **IMPLEMENTED** with proper event conversion, error handling, and quit key detection.
- **RUNTIME:** **`ex_termbox` reporting incorrect terminal dimensions:** Underlying issue masked by hardcoding workaround. Needs future investigation.
- **RUNTIME:** Potential infinite loop **needs verification** (seems unlikely now, but verify visually).
- **RUNTIME:** Status of other runtime warnings (`Unhandled view element type`, `Skipping invalid cell change`) **unknown (Pending Visual Verification)**.
- **RUNTIME:** Numerous compiler warnings remain (type mismatches, unused vars, clause matching - see logs). **Major init compilation errors fixed.**
- ~~**DATABASE:** Postgrex errors occur after application crash.~~ **FIXED** by implementing robust connection handling.
- ~~**VISUALIZATION:** TUI Charts/TreeMaps rendering **needs implementation and visual verification**.~~ **IMPLEMENTED and TESTED** with improved bar chart rendering (with labels and values) and proper treemap layout rendering.
- **IMAGE:** Image rendering (`assets/static/images/logo.png`) **needs visual verification** (escape sequence sent, but result unknown).
- ~~**LAYOUT:** Layout saving confirmed working. Layout loading (`~/.raxol/dashboard_layout.bin`) **needs testing**.~~ **IMPLEMENTED and TESTED** with comprehensive layout persistence tests.
