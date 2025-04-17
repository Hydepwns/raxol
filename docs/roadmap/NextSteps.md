---
title: Next Steps
description: Documentation of next steps in Raxol Terminal Emulator development
date: 2023-04-04
author: Raxol Team
section: roadmap
tags: [roadmap, next steps, planning]
---

# Next Steps for Raxol Framework Development

This document outlines the current status of the Raxol framework and provides clear direction for immediate next steps in development.

## Current Status Overview

### Features in Progress / Blocked

- **Runtime Stability:** Application **RUNS** successfully, `ex_termbox` initializes, NIF loads. Input works. `Ctrl+C` leads to **unclean exit** (BEAM break menu) after termination sequence. Dimension reporting workaround applied.
- **Runtime Rendering Pipeline:** Active, processes view elements, calculates cell diffs. Image plugin generates escape sequence. **VISUAL OUTPUT UNVERIFIED**. Needs interactive testing.
- **Dashboard Layout System**: Logic believed fixed. Saving confirmed working. Loading **NEEDS TESTING**. Visual verification pending.
- **Performance Monitoring & Cleanup**: (Lower Priority) Completing the performance scoring/alerting tools & resolving minor existing analysis warnings.
- **Plugin System Testing**: Image plugin sends escape sequence (**NEEDS VISUAL VERIFICATION**). Visualization plugin rendering **NEEDS IMPLEMENTATION & VISUAL VERIFICATION**. `HyperlinkPlugin` cross-platform OS interaction **NEEDS TESTING**.
- **Advanced Documentation**: (Lower Priority) Creating debugging guides and optimization case studies.
- **Screen Buffer Logic**: `ScreenBuffer.diff/2` and `update/2` implemented, integrated, and fixed.

## Tactical Next Steps

**CURRENT FOCUS:** Verify Visual Output & Investigate Unclean Exit

1. [x] **~~Investigate `termbox` Initialization Failure:~~** **FIXED** (Resolved `:nif_not_loaded` by recompiling `ex_termbox`).
2. [ ] **Run & Verify Rendering (Interactive):** Execute `mix run --no-halt` interactively.
   - Visually verify if _any_ TUI rendering appears (borders, text widgets, image).
   - Check logs (`[GridContainer.calculate_widget_bounds]` debug logs) for correct bounds calculations.
   - Address previously observed runtime warnings (`Unhandled view element type`, `Skipping invalid cell change`) if they appear.
   - **Note:** Confirm if the ImagePlugin's escape sequence actually displays the image.
3. [ ] **Investigate Unclean Exit:** Determine why `Ctrl+C` leads to the BEAM break menu instead of a clean exit to the shell.
   - _Next Test:_ Add logging in `RuntimeDebug.terminate/2`; review supervision & `ex_termbox` shutdown interaction.

**FURTHER NEXT STEPS (Post-Visual Verification & Clean Exit):** Address Plugins, Layout, Hacks.

4. [ ] **Test Plugin Functionality:**
   - Test `HyperlinkPlugin.open_url/1` on different operating systems.
5. [ ] **Test Layout Persistence:**
   - Verify `Dashboard.save_layout/1` saves the correct data.
   - Verify `Dashboard.load_layout/0` loads the saved layout correctly.
6. [ ] **Implement & Refine Rendering Logic:** Enhance `VisualizationPlugin` TUI rendering (Chart and TreeMap) for better accuracy, layout, and aesthetics.
7. [ ] **Address Type Warnings:** Fix compiler warnings for type mismatches in `Runtime` event handling.
8. [ ] **Investigate `ex_termbox` Dimension Issue:** Research the root cause of the incorrect dimension reporting (remove hardcoding).
9. [ ] **Run Static Analysis (Lower Priority):** Run `mix dialyzer` and `mix credo`.

## Immediate Development Priorities (Post-Crash-Fix & Visualization Rendering)

### 1. Dashboard Layout System Refinements

- [ ] Widget Configuration Panel
- [ ] Data Source Connection / Real Configuration
- [ ] Real-time Data Updating
- [ ] Layout Persistence Configuration
- [ ] Accessibility Review
- [ ] User Customization (Add/Remove Widgets)

### 2. Performance Tools Finalization (New Tooling)

Complete the remaining performance tools to ensure robust monitoring. (Note: This focuses on building _new_ tools, separate from fixing existing analysis warnings.)

- [ ] Responsiveness scoring system
  - [ ] Define metrics for input responsiveness
  - [ ] Create scoring algorithm
  - [ ] Visualization of responsiveness data
- [ ] Performance regression alerting
  - [ ] Threshold configuration
  - [ ] Notification system
  - [ ] Integration with CI/CD pipeline
- [ ] Animation performance analysis
  - [ ] Frame rate monitoring for animations
  - [ ] Animation performance optimization tools
  - [ ] Animation bottleneck identification

### 3. Advanced Animation System

Begin implementation of more advanced animation capabilities:

- [ ] Physics-based animations
  - [ ] Spring physics implementation
  - [ ] Inertia effects
  - [ ] Bounce and elasticity controls
- [ ] Gesture-driven interactions
  - [ ] Drag interactions with physics
  - [ ] Swipe gesture recognition
  - [ ] Multi-touch gesture support
- [ ] Animation sequencing
  - [ ] Timeline-based animation system
  - [ ] Keyframe animation support
  - [ ] Animation grouping and coordination

### 4. AI Integration Development

Continue developing AI capabilities:

- [ ] Content generation
  - [ ] Component template generation
  - [ ] Placeholder content generation
  - [ ] Documentation generation assistance
- [ ] UI design suggestions
  - [ ] Layout recommendations
  - [ ] Color scheme optimization
  - [ ] Accessibility improvements

## Technical Implementation Plan

### Visualization Rendering Implementation (Ready after verification)

1. **Week X**: Research/Choose TUI rendering strategy (Contex integration? Custom drawing?).
2. **Week X**: Implement `VisualizationPlugin.render_chart_to_cells/3`.
3. **Week X**: Implement `VisualizationPlugin.render_treemap_to_cells/3`.
4. **Week Y**: Test rendering, fix layout/clipping issues, test hyperlink interaction.

### Dashboard Layout System Refinements (Next)

1. **Week 1-2**: Create responsive grid layout foundation

   - Implement grid container component
   - Add responsive breakpoint system
   - Create layout configuration API

2. **Week 3-4**: Develop widget container implementation

   - Build draggable functionality
   - Implement resize controls
   - Create widget configuration panel

3. **Week 5-6**: Build dashboard persistence and configuration

   - Implement saving/loading system
   - Create default templates
   - Develop user configuration UI

4. **Week 7-8**: Visualization component integration
   - [x] Create specialized widget types for charts and TreeMaps (`ChartWidget`, `TreeMapWidget`)
   - [ ] Build data binding / configuration system (TODO)
   - [ ] Implement real-time updates (TODO)

### Testing Strategy

- Create specific tests for dashboard layout responsiveness
- Test dragging and resizing with various screen sizes
- Validate accessibility of the dashboard system
- Benchmark performance with multiple widgets

## Development Guide for Dashboard System

When implementing the dashboard system, follow these principles:

1. **Composability**: Widgets should be composable and follow consistent patterns
2. **Accessibility**: Ensure all dashboard interactions work with keyboard and screen readers
3. **Performance**: Monitor and optimize for performance with many widgets
4. **Flexibility**: Support various layouts and configurations
5. **Persistence**: Save and restore dashboard state reliably

## Contribution Areas

For developers interested in contributing, these are areas where help would be valuable:

1. **Dashboard Widget Types**: Creating additional specialized widget types
2. **Performance Optimization**: Improving dashboard rendering performance
3. **Animation System**: Implementing physics-based animations
4. **Documentation**: Creating guides for dashboard creation
5. **Testing**: Developing comprehensive tests for layout system

## Next Team Sync Focus

1. Review results of interactive visual verification.
2. Discuss findings from unclean exit investigation.
3. Plan next steps based on verification (implement visualization vs. debug rendering/exit issues).

## Resources and References

- Visualization Plugin: `VisualizationPlugin`
