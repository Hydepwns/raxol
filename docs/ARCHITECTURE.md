# Raxol Architecture

This document provides an overview of the Raxol architecture after the completed reorganization. It explains the core components, their responsibilities, and how they interact.

_Last updated: 2025-04-26_

## Overview

Raxol is organized into several logical subsystems:

1. **Core** - Fundamental runtime and system services
2. **UI** - Component model and rendering
3. **Terminal** - Terminal emulation and ANSI processing
4. **View** - View definition and templating

## Directory Structure

```bash
lib/raxol/
├── core/                  # Core runtime and system services
│   ├── events/            # Event handling system
│   ├── runtime/           # Application runtime
│   │   ├── events/        # Event handling
│   │   ├── plugins/       # Plugin system
│   │   └── rendering/     # Rendering system
│   └── ...
├── ui/                    # UI component system
│   ├── components/        # Built-in components
│   │   ├── base/          # Base component behavior
│   │   ├── display/       # Display components (Progress, etc.)
│   │   └── input/         # Input components (Button, TextField, etc.)
│   ├── layout/            # Layout system (panels, grid, containers)
│   ├── theming/           # Theming system
│   └── ...
├── terminal/              # Terminal emulation
│   ├── ansi/              # ANSI escape sequence handling
│   ├── commands/          # Terminal commands
│   └── ...
└── view/                  # View definition and templating
    ├── elements.ex        # Basic UI elements
    ├── layout.ex          # Layout functions
    └── ...
```

## Core Subsystems

### Runtime System

The runtime system manages the application lifecycle and provides core services:
_(Note: The core runtime loop, basic event handling (keyboard, resize), and rendering pipeline are now functional under supervision.)_

- **Lifecycle Management**: Application startup, updates, and shutdown
- **Event Handling**: Processing keyboard, mouse, and system events
- **Rendering**: Scheduling and executing UI rendering
- **Plugin System**: Loading and managing plugins

### Component System

The component system provides a framework for building interactive UIs:

- **Base Component Behavior**: Defines the lifecycle and behavior of components
- **Input Components**: Button, Checkbox, TextField, and other interactive elements
- **Display Components**: Progress bars, charts, and other display elements
- **Layout Components**: Panel, row, column, and grid layouts

### Theming System

The theming system allows for consistent styling across the application:

- **Theme Definition**: Defines colors, styles, and attributes for different UI elements
- **Theme Application**: Applies themes to components
- **Color Management**: Handles color conversions and mappings

## Key Modules

| Module                               | Description                                |
| ------------------------------------ | ------------------------------------------ |
| `Raxol.Core.Runtime`                 | Main runtime engine for Raxol applications |
| `Raxol.Core.Runtime.Plugins`         | Plugin system for extending Raxol          |
| `Raxol.UI.Components.Base.Component` | Base behavior for UI components            |
| `Raxol.UI.Layout.Engine`             | Layout engine for positioning elements     |
| `Raxol.UI.Theming.Theme`             | Theme management and application           |
| `Raxol.Terminal.Commands`            | Terminal command execution facade          |
| `Raxol.View.Elements`                | Basic UI element definitions               |

## Plugin System

The plugin system allows extending Raxol with custom functionality:

- **Plugin Registration**: Plugins register with the system at startup
- **Lifecycle Events**: Plugins can hook into application lifecycle events
- **Command Registration**: Plugins can add custom commands
- **Event Handling**: Plugins can intercept and modify events

## Examples

The `/examples` directory contains sample applications that demonstrate different aspects of the Raxol framework:

- Basic rendering and layouts
- Component usage and interaction
- Theming and styling
- Plugin development
- Advanced terminal features

### Architecture Demo

The `examples/showcase/architecture_demo.exs` file provides a comprehensive demonstration of the reorganized architecture, showing how the various subsystems interact in a complete application. This example showcases:

- Core runtime initialization
- Event handling
- Component lifecycle
- Plugin integration
- Theming application
- Layout management

## Historical Notes

This architecture is the result of a comprehensive reorganization project that addressed:

1. Large monolithic modules (some exceeding 1000 lines)
2. Organizational inconsistencies
3. Ambiguous naming conventions
4. Scattered related functionality

The reorganization improved maintainability, created a consistent structure, clarified component responsibilities, reduced duplication, and enhanced code discoverability.
