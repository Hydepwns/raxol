---
title: Next Steps
description: Documentation of next steps in Raxol Terminal Emulator development
date: 2023-04-04
author: Raxol Team
section: roadmap
tags: [roadmap, next steps, planning]
---

# Next Steps for Raxol

## Current Status Overview

The application is nearing a stable prototype stage with several key components working:

- The application compiles with warnings
- The backend starts successfully in VS Code extension mode
- Communication between the extension and backend is established
- The database system is now fixed with robust connection management and diagnostics
- Basic UI views are rendering
- Core functionality is in place for navigation and data visualization

## Tactical Next Steps

1. **Resolve Startup Issues**

   - Verify extension startup sequence and messaging
   - Debug dashboard application launch
   - Fix UI view initialization

2. **Fix UI Rendering**

   - Address layout loading issues
   - Implement proper resize panel handling
   - Ensure correct terminal dimensions are reported by ExTermbox

3. **Performance and Stability Improvements**

   - Investigate and fix BEAM VM hang on exit in stdio mode
   - Optimize rendering for large datasets
   - Implement proper error handling for all user input

4. **Feature Completeness**

   - Complete dashboard integration
   - Implement full search capabilities
   - Finish charts and tree maps rendering

5. **Polish**
   - Fix remaining compiler warnings
   - Address Dialyzer warnings
   - Complete documentation

## Immediate Development Priorities (Post-Bridge Verification)

### 1. Implement User Input & Resize Handling

- [ ] Enhance `user_input` message handling in `Runtime.ex` to convert WebView key events to app events.
- [ ] Map key codes and modifiers from VS Code WebView to the format expected by the application.
- [ ] Complete the `resize_panel` message handling in `Runtime.ex` to properly update dimensions.
- [ ] Test both features in VS Code extension mode and native terminal mode.

### 2. Test Native Terminal Mode

- [ ] Run the backend directly in a native terminal to verify ExTermbox initialization and operation.
- [ ] Test user input, rendering, and layout calculations in a native terminal.
- [ ] Investigate BEAM VM hang on exit in stdio mode.
- [x] ~~Address database connection issues if they persist in native terminal mode.~~ **FIXED** by implementing robust database connection management that works in all environments.

### 3. Refine Webview Rendering

- [ ] Enhance Webview rendering (`media/main.js`) based on `ui_update` (colors, attributes, better cursor).
- [ ] Improve key mapping in `media/main.js` for special keys.
- [ ] Consider implementing a more sophisticated rendering approach (canvas or DOM-based).

## Technical Implementation Plan

### Fix ExTermbox Initialization & JSON Communication Issues

1. **Week 1**: Investigate ExTermbox initialization failures

   - Review ExTermbox binding code and initialization process
   - Add detailed logging around initialization
   - Test in different environments (VS Code, native terminal)
   - Create fallback mode for VS Code extension

2. **Week 1-2**: Implement proper JSON communication
   - Fix JSON formatting in `StdioInterface`
   - Update `BackendManager` to handle log output vs. JSON
   - Add JSON envelope for log messages if needed
   - Test basic message flow once initialization is fixed

### Database Connection Management (Completed)

1. **Week 1**: Implement robust connection management

   - Create ConnectionManager with retry logic
   - Implement error classification for Postgres errors
   - Add health checks for database connections
   - Create diagnostic tools

2. **Week 2**: Enhance database interfaces
   - Create safe Database module with retry capabilities
   - Improve Repo configuration and logging
   - Add documentation for database operations
   - Test connection recovery in various scenarios

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

1. Review results of **ExTermbox initialization failure investigation** (error code -2).
2. Discuss findings from JSON communication issues and potential solutions.
3. Evaluate options for creating a simplified version for initial testing.
4. Plan next steps based on investigation results.

## Resources and References

- Visualization Plugin: `VisualizationPlugin`
- VS Code Extension APIs: [Link to relevant VS Code docs, e.g., Webviews]

## Future Exploration
