---
title: Raxol Architecture
description: Overview of the Raxol system architecture
date: 2025-01-27
author: Raxol Team
section: documentation
tags: [architecture, documentation, design]
---

# Raxol Architecture

## System Overview

Raxol is a sophisticated terminal user interface toolkit that provides a comprehensive set of features for building interactive terminal applications. The system uses a layered architecture with clear separation of concerns and has been recently enhanced with improved terminal subsystems, core metrics, and UI components.

```mermaid
graph TB
    subgraph Layers["System Layers"]
        App[Application Layer]
        View[View Layer]
        Runtime[Runtime Layer]
        Terminal[Terminal Layer]
        UI[UI Components Layer]
    end

    App --> View
    View --> Runtime
    Runtime --> Terminal
    Runtime --> UI
    UI --> Terminal

    classDef layer fill:#22223b,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:16px,padding:8px;
    class App,View,Runtime,Terminal,UI layer;
```

### Layer Responsibilities

```mermaid
graph LR
    subgraph App["Application Layer"]
        direction TB
        Logic[Application Logic]
        State[State Management]
        Logic --> State
    end

    subgraph View["View Layer"]
        direction TB
        UIComp[UI Composition]
        Style[Styling & Theming System]
        UIComp --> Style
    end

    subgraph Runtime["Runtime Layer"]
        direction TB
        Events[Event System]
        Render[Renderer]
        Plugins[Plugin System]
        Lifecycle[Lifecycle Manager]
        Config[Configuration Manager]
        Metrics[Metrics System]
        UX[UX Refinement]
        Events --> Plugins
        Events --> Lifecycle
        Lifecycle --> Render
        Render --> Config
        Render --> Metrics
        Metrics --> UX
    end

    subgraph Terminal["Terminal Layer"]
        direction TB
        IO[I/O Management]
        Buffer[Unified Buffer System]
        Cursor[Cursor Manager]
        ANSI[ANSI State Machine]
        Commands[Command Handlers]
        Graphics[Sixel Graphics]
        IO --> Buffer
        Buffer --> Cursor
        Buffer --> ANSI
        ANSI --> Commands
        Commands --> Graphics
    end

    subgraph UI["UI Components Layer"]
        direction TB
        Basic["Enhanced Components (Button, MultiLineInput, PasswordField, SelectList, Progress)"]
        Layout[Layout Engine]
        Focus[Focus Management]
        Accessibility[Accessibility]
        Theming[Theming]
        Animation[Animation System]
        Basic --> Layout
        Layout --> Focus
        Focus --> Accessibility
        Accessibility --> Theming
        Theming --> Animation
    end

    classDef layer fill:#22223b,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class App,View,Runtime,Terminal,UI layer;
```

## Core Subsystems

### Enhanced Terminal Layer

The terminal layer has been significantly refactored with improved organization and specialized modules:

```mermaid
graph TB
    subgraph Terminal["Enhanced Terminal Layer"]
        Buffer[Unified Buffer Manager]
        Cursor[Cursor Manager]
        IO[I/O Manager]
        ANSI[ANSI State Machine]
        Commands[Command Handlers]
        Graphics[Sixel Graphics]
        Mouse[Mouse Tracking]
        Window[Window Management]
    end

    Buffer --> Cursor
    Buffer --> ANSI
    ANSI --> Commands
    Commands --> Graphics
    Commands --> Mouse
    Commands --> Window
    IO --> Buffer

    classDef component fill:#4a4e69,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class Buffer,Cursor,IO,ANSI,Commands,Graphics,Mouse,Window component;
```

### Enhanced Runtime Layer

The runtime layer now includes improved metrics, performance monitoring, and UX refinement:

```mermaid
graph TB
    subgraph Runtime["Enhanced Runtime Layer"]
        Events[Event System]
        Plugins[Plugin System]
        Render[Renderer]
        Lifecycle[Lifecycle Manager]
        Config[Configuration Manager]
        Metrics[Metrics System]
        Performance[Performance Monitor]
        UX[UX Refinement]
    end

    Events --> Plugins
    Events --> Lifecycle
    Lifecycle --> Render
    Render --> Config
    Render --> Metrics
    Metrics --> Performance
    Performance --> UX

    classDef component fill:#4a4e69,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class Events,Plugins,Render,Lifecycle,Config,Metrics,Performance,UX component;
```

### Enhanced UI Components Layer

The UI components layer has been updated with improved input components and layout engine:

```mermaid
graph TB
    subgraph UI["Enhanced UI Components Layer"]
        Basic["Enhanced Components (Button, MultiLineInput, PasswordField, SelectList, Progress)"]
        Layout[Layout Engine]
        Focus[Focus Management]
        Accessibility[Accessibility]
        Theming[Theming]
        Animation[Animation System]
        Clipboard[Clipboard Integration]
    end

    Basic --> Layout
    Layout --> Focus
    Focus --> Accessibility
    Accessibility --> Theming
    Theming --> Animation
    Basic --> Clipboard

    classDef component fill:#4a4e69,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class Basic,Layout,Focus,Accessibility,Theming,Animation,Clipboard component;
```

### Enhanced Plugin System

The plugin system maintains its robust architecture with improved dependency management:

```mermaid
graph TB
    subgraph PluginSystem["Enhanced Plugin System"]
        Registry[Plugin Registry]
        Loader[Plugin Loader]
        Lifecycle[Lifecycle Manager]
        Events[Plugin Events]
        Dependencies[Dependency Manager]
    end

    Registry --> Loader
    Loader --> Lifecycle
    Lifecycle --> Events
    Events --> Dependencies

    classDef component fill:#4a4e69,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class Registry,Loader,Lifecycle,Events,Dependencies component;
```

### Component Lifecycle

The component lifecycle remains consistent with improved error handling:

```mermaid
stateDiagram-v2
    [*] --> init
    init --> mount
    mount --> update
    update --> render
    render --> handle_event
    handle_event --> update
    update --> unmount
    unmount --> [*]
```

## Enhanced Event & Rendering Pipeline

```mermaid
sequenceDiagram
    participant TI as Terminal Input
    participant ANSI as ANSI State Machine
    participant ED as Event Dispatcher
    participant App as Application
    participant View as View
    participant UI as UI Components
    participant TB as Unified Buffer
    participant Metrics as Metrics System

    TI->>ANSI: Raw Input
    ANSI->>ED: Parsed Events
    ED->>App: handle_event
    App->>View: Update
    View->>UI: Compose
    UI->>TB: Render
    TB->>Metrics: Performance Data
```

## Performance Requirements

- **Event Processing:** < 1ms average, < 2ms 95th percentile
- **Screen Updates:** < 2ms average, < 5ms 95th percentile
- **Concurrent Operations:** < 5ms average, < 10ms 95th percentile
- **Terminal Operations:** < 0.5ms average, < 1ms 95th percentile

## Enhanced Testing Infrastructure

The testing infrastructure has been significantly improved with better organization and coverage:

```mermaid
graph TB
    subgraph Testing["Enhanced Testing Infrastructure"]
        Unit[Unit Tests]
        Integration[Integration Tests]
        Performance[Performance Tests]
        Terminal[Terminal Tests]
    end

    subgraph Coverage["Enhanced Test Coverage"]
        Components[Component Tests]
        Plugins[Plugin Tests]
        Buffer[Buffer Tests]
        ANSI[ANSI Tests]
        Commands[Command Tests]
        UI[UI Tests]
    end

    subgraph Support["Test Support"]
        Fixtures[Test Fixtures]
        Mocks[Mock Implementations]
        Helpers[Test Helpers]
    end

    Unit --> Components
    Integration --> Plugins
    Integration --> Terminal
    Performance --> Testing
    Terminal --> Buffer
    Terminal --> ANSI
    Terminal --> Commands
    UI --> Components
    Support --> Testing

    classDef test fill:#4a4e69,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class Unit,Integration,Performance,Terminal,Components,Plugins,Buffer,ANSI,Commands,UI,Fixtures,Mocks,Helpers test;
```

## Recent Architectural Improvements

### Terminal Subsystem Enhancements

- **Unified Buffer Management:** Improved buffer operations with specialized modules for different concerns
- **Enhanced ANSI Processing:** Better state machine for escape sequence handling
- **Improved Command Handlers:** Standardized error handling and result propagation
- **Sixel Graphics Support:** Enhanced graphics rendering capabilities
- **Window Management:** Better window state handling and manipulation

### Core System Improvements

- **Metrics System:** Enhanced aggregation and visualization capabilities
- **Performance Monitoring:** Improved system performance tracking
- **UX Refinement:** Better accessibility and user experience features
- **Color System:** Enhanced theme management and color handling

### UI Component Enhancements

- **Input Components:** Improved multi-line input, password fields, and select lists
- **Layout Engine:** Enhanced layout processing and container management
- **Rendering Pipeline:** Better rendering performance and reliability
- **Clipboard Integration:** Improved clipboard handling across components

## Design Principles

- **Elm-style update/view separation**: e.g. `Raxol.UI.Components.Base.Component`
- **NIF terminal I/O** (hosted in `priv/static/@static/termbox2_nif`): we maintain a [fork of this ourselves](https://github.com/Hydepwns/termbox2_nif)
- **Reusable, stateful components**: e.g. `Raxol.UI.Components.Base.Component`
- **Unified error handling**: Consistent error/result tuples across all subsystems
- **Performance-first design**: Optimized for low-latency terminal operations
- **Comprehensive testing**: Extensive test coverage with improved reliability

## References

- [Component Guide](../examples/guides/03_components_and_layout/components/README.md)
- [Plugin Development](../examples/guides/04_extending_raxol/plugin_development.md)
- [Testing Guide](../examples/guides/05_development_and_testing/testing.md)
