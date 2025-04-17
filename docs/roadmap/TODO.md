---
title: TODO List
description: List of pending tasks and improvements for Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: roadmap
tags: [roadmap, todo, tasks]
---

# Raxol Project Roadmap

## In Progress 🚧

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
  - [ ] **Next Steps: Implement User Input & Resize Handling**
    - [ ] Enhance `user_input` message handling in `Runtime.ex` to convert WebView key events to app events.
    - [ ] Map key codes and modifiers from VS Code WebView to app format.
    - [ ] Complete `resize_panel` message handling to update dimensions.
    - [ ] Test both features in VS Code extension mode and native terminal mode.
- **Architecture & Setup (Supporting)**
  - [x] Set up initial extension project structure (verified `package.json`, `extensions/vscode/src/extension.ts`).
  - [x] Plan detailed architecture for Webview <-> Elixir interaction. (**Protocol defined**)
  - [ ] Research frontend technologies (React, Vue, Svelte, etc.) for Webview UI (Decision Deferred).

### Runtime Stability (Supporting Extension & Core)

- [x] **Fix ExTermbox initialization failure:** Implemented fallback mode that avoids using ExTermbox in VS Code extension mode.
- [x] **Address Database Connection Issues:** ~~Investigate and fix the Postgrex errors that appear after application crash.~~ Fixed by implementing robust connection management with retry logic, improved error handling, and diagnostic tools.
- [ ] **Investigate BEAM hang after clean GenServer termination (Ctrl+C):** Determine why BEAM VM hangs. Critical for backend process management. **Confirmed occurs in stdio mode.** Native terminal test pending. Hypothesis: Incorrect `ExTermbox.Bindings.shutdown()` call in `Runtime.terminate` when in stdio mode.
- [ ] **Verify TUI Rendering (Native Terminal):** Check visual output interactively in a native terminal to confirm core logic. **NEEDS VISUAL VERIFICATION**. Note BEAM hang on exit.
- [ ] **Investigate `ex_termbox` Dimension Reporting:** Root cause of incorrect height/width reporting still needs investigation. (Workaround applied).
- [x] **~~Debug `termbox` Initialization Failure (`{:failed_to_init_termbox, -2}`)~~**: **FIXED** (Implemented fallback mode for VS Code extension, avoiding ExTermbox initialization).
- [ ] **Verify Infinite Loop Fix:** Status unknown, previously blocked by other errors. Needs verification once app runs.

### Runtime Rendering Pipeline (TUI - Lower Priority)

- [ ] **Verify `Unhandled view element type` Status:** Needs verification via logging (**UNKNOWN, Pending Visual Verification**).
- [ ] **Verify `Skipping invalid cell change` Status:** Needs verification via logging (**UNKNOWN, Pending Visual Verification**).

### Dashboard Layout System Refinements (TUI - Lower Priority)

- [x] **~~Investigate `GridContainer` Calculation:~~** **FIXED** (using rounding + fixed Runtime crash loop).
- [ ] **Refine Chart/TreeMap TUI Rendering:** Improve accuracy, layout, labeling, and aesthetics of `VisualizationPlugin` (**NEEDS VISUAL VERIFICATION / IMPLEMENTATION**).
- [ ] **Test Layout Persistence:** Verify `save_layout/1` and `load_layout/0` work correctly. (**NEEDS TESTING (App Runs)**)

### Plugin System Enhancements (TUI - Lower Priority)

- [ ] **ImagePlugin Stability/Visual Testing:** Verify image (`assets/static/images/logo.png`) rendering visually (**NEEDS VISUAL VERIFICATION (Escape Sequence Sent)**).
- [ ] **Hyperlink OS Interaction Testing:** Verify/test `HyperlinkPlugin.open_url/1` across different OSes. (**NEEDS TESTING (App Runs)**)
- [ ] **Investigate alternative rendering mechanisms if needed (ImagePlugin).**

### Performance Optimization (Lower Priority)

- [ ] **Responsiveness Scoring System:** Define metrics, create algorithm, visualize data.
- [ ] **Performance Regression Alerting:** Configure thresholds, notification system, CI integration.
- [ ] **Animation Performance Analysis:** Monitor frame rates, identify bottlenecks.
- [ ] **Asset Optimization:** Optimize large font files in `priv/static/fonts` directory.

### Codebase Organization (Completed) ✅

- [x] **Consolidate Example Directories:** Merged `/src/examples` into `/examples/typescript` to have examples in a single location.
- [x] **Frontend & Backend Separation:** Created a dedicated `/frontend` directory for JavaScript/TypeScript configuration files.
- [x] **Normalize Extension Structure:** Cleaned up the nested directory structure in `/extensions/vscode`.
- [x] **Improve Security Management:** Created `.secrets.example` file and better .gitignore patterns.
- [x] **Update Documentation:** Added project structure section to README.md.

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

- **RUNTIME:** **BEAM VM hangs (break menu)** on `Ctrl+C`. Confirmed in stdio mode. **CURRENT BLOCKER for usability/extension development.** Native terminal test pending. **Incorrect Termbox cleanup in `terminate` might be related.**
- **RUNTIME:** **Backend processing of `userInput` and `resize_panel` payloads is basic (logging only)**. Needs implementation.
- **RUNTIME:** **`ex_termbox` reporting incorrect terminal dimensions:** Underlying issue masked by hardcoding workaround. Needs future investigation.
- **RUNTIME:** Potential infinite loop **needs verification** (seems unlikely now, but verify visually).
- **RUNTIME:** Status of other runtime warnings (`Unhandled view element type`, `Skipping invalid cell change`) **unknown (Pending Visual Verification)**.
- **RUNTIME:** Numerous compiler warnings remain (type mismatches, unused vars, clause matching - see logs). **Major init compilation errors fixed.**
- ~~**DATABASE:** Postgrex errors occur after application crash.~~ **FIXED** by implementing robust connection handling.
- **VISUALIZATION:** TUI Charts/TreeMaps rendering **needs implementation and visual verification**.
- **IMAGE:** Image rendering (`assets/static/images/logo.png`) **needs visual verification** (escape sequence sent, but result unknown).
- **LAYOUT:** Layout saving confirmed working. Layout loading (`~/.raxol/dashboard_layout.bin`) **needs testing**.
- **TESTING:** `HyperlinkPlugin.open_url/1` needs cross-platform **testing**.
- **DIALYZER:** ~86 warnings remain.

## Completed

- [x] Fix VS Code extension bridge compilation issues
- [x] Implement VS Code extension activation
- [x] Fix backend startup in VS Code extension mode
- [x] Implement stdio message handling
- [x] Fix JSON message formatting
- [x] Implement basic UI updates through StdioInterface
- [x] Fix database connection system with robust error handling
- [x] Improve codebase organization and structure
- [x] Consolidate example directories
- [x] Create dedicated frontend directory
- [x] Normalize extension directory structure

## Backlog

- [ ] Implement full-text search
- [ ] Add support for custom themes
- [ ] Improve performance of large dataset rendering
- [ ] Add keyboard shortcut customization
- [ ] Implement plugin system extension points
- [ ] Create comprehensive user documentation
- [ ] Set up continuous integration pipeline
- [ ] Create installer packages for different platforms
