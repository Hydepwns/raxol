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

### Runtime Stability

- [x] **~~Debug `termbox` Initialization Failure (`{:failed_to_init_termbox, -2}`)~~**: **FIXED** (Resolved `:nif_not_loaded` by recompiling `ex_termbox`).
- [ ] **Investigate `ex_termbox` Dimension Reporting:** Root cause of incorrect height/width reporting still needs investigation. (Workaround applied).
- [ ] **Investigate Unclean Exit (BEAM Break Menu on Ctrl+C):** Determine why termination isn't clean.
- [ ] **Verify Infinite Loop Fix:** Status unknown, previously blocked by other errors. Needs verification once app runs.

### Runtime Rendering Pipeline

- [ ] **Verify TUI Rendering:** Check visual output interactively. **NEEDS VISUAL VERIFICATION**. Note unclean exit.
- [ ] **Verify `Unhandled view element type` Status:** Needs verification via logging (**UNKNOWN, Pending Visual Verification**).
- [ ] **Verify `Skipping invalid cell change` Status:** Needs verification via logging (**UNKNOWN, Pending Visual Verification**).

### Dashboard Layout System Refinements

- [x] **~~Investigate `GridContainer` Calculation:~~** **FIXED** (using rounding + fixed Runtime crash loop).
- [ ] **Refine Chart/TreeMap TUI Rendering:** Improve accuracy, layout, labeling, and aesthetics of `VisualizationPlugin` (**NEEDS VISUAL VERIFICATION / IMPLEMENTATION**).
- [ ] **Test Layout Persistence:** Verify `save_layout/1` and `load_layout/0` work correctly. (**NEEDS TESTING (App Runs)**)

### Plugin System Enhancements

- [ ] **ImagePlugin Stability/Visual Testing:** Verify image (`assets/static/images/logo.png`) rendering visually (**NEEDS VISUAL VERIFICATION (Escape Sequence Sent)**).
- [ ] **Hyperlink OS Interaction Testing:** Verify/test `HyperlinkPlugin.open_url/1` across different OSes. (**NEEDS TESTING (App Runs)**)
- [ ] **Investigate alternative rendering mechanisms if needed (ImagePlugin).**

### Performance Optimization

- [ ] **Responsiveness Scoring System:** Define metrics, create algorithm, visualize data.
- [ ] **Performance Regression Alerting:** Configure thresholds, notification system, CI integration.
- [ ] **Animation Performance Analysis:** Monitor frame rates, identify bottlenecks.

### Documentation

- [ ] API documentation updates (reflect widget refactoring, new plugin).
- [ ] Performance tuning guidelines.
- [ ] Component lifecycle documentation.
- [ ] Event system best practices.
- [ ] Integration examples and tutorials (Dashboard, Plugins).
- [ ] Accessibility and internationalization integration guides.

## Upcoming Features 🎯

### Advanced Animation System

- Physics-based animations
- Gesture-driven interactions
- Animation sequencing and timelines
- Performance optimization for animations

### AI Integration

- Content generation helpers
- UI design suggestions
- Data analysis and visualization recommendations
- Accessibility improvements through AI

### Developer Experience Enhancement

- Comprehensive IDE support
- Advanced debugging tools
- Documentation improvements
- Code generation utilities

### UX Refinement Enhancements

- Touch screen gesture support
- Advanced focus management patterns
- Shortcut customization interface
- Voice command integration

### Event System Enhancements

- Event persistence layer
- Event replay functionality
- Advanced event filtering patterns
- Event transformation pipelines
- Custom event type definitions

### Developer Tools

- Interactive event debugger
- Real-time event monitoring dashboard
- Event flow visualization
- Performance profiling tools
- Metric visualization improvements
- Accessibility compliance checker

### Integration Features

- External system connectors
- Event format adapters
- Protocol bridges
- Message queue integration
- WebSocket support
- Screen reader API integration

## Future Considerations 🔮

### Scalability

- Distributed event processing
- Cluster support
- Horizontal scaling capabilities
- Load balancing strategies
- Event partitioning

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
- AI-assisted accessibility adaptations

## Known Issues 🐞

- **RUNTIME:** **Unclean exit (BEAM break menu)** on `Ctrl+C` despite normal termination logic running. **CURRENT BLOCKER for usability.**
- **RUNTIME:** **Visual rendering output unconfirmed**. Need to verify if `change_cell`/`present` and image escape sequences produce output.
- **RUNTIME:** **`ex_termbox` reporting incorrect terminal dimensions:** Underlying issue masked by hardcoding workaround. Needs future investigation.
- **RUNTIME:** Potential infinite loop **needs verification** (seems unlikely now, but verify visually).
- **RUNTIME:** Status of other runtime warnings (`Unhandled view element type`, `Skipping invalid cell change`) **unknown (Pending Visual Verification)**.
- **RUNTIME:** Compiler warnings exist for type mismatches in `handle_event` return clauses and many undefined function calls (see logs).
- **VISUALIZATION:** TUI Charts/TreeMaps rendering **needs implementation and visual verification**.
- **IMAGE:** Image rendering (`assets/static/images/logo.png`) **needs visual verification** (escape sequence sent, but result unknown).
- **LAYOUT:** Layout saving confirmed working. Layout loading (`~/.raxol/dashboard_layout.bin`) **needs testing**.
- **TESTING:** `HyperlinkPlugin.open_url/1` needs cross-platform **testing**.
- **DIALYZER:** ~86 warnings remain.
