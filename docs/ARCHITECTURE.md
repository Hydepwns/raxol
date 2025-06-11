---
title: Raxol Architecture
description: Overview of the Raxol system architecture
date: 2025-05-10
author: Raxol Team
section: documentation
tags: [architecture, documentation, design]
---

# Raxol Architecture

## System Overview

Raxol uses a layered architecture with clear separation of concerns:

```bash
┌───────────────┐
│ Application   │
├───────────────┤
│ View          │
├───────────────┤
│ Components    │
├───────────────┤
│ Runtime/Render│
├───────────────┤
│ Terminal      │
└───────────────┘
```

### Detailed Architecture Diagram

```mermaid
graph TB
    subgraph Application["Application Layer"]
        App[Application]
        View[View System]
        State[State Management]
    end

    subgraph Components["Component Layer"]
        Basic[Basic Components]
        Input[Input Components]
        Layout[Layout Components]
        Advanced[Advanced Components]
    end

    subgraph Runtime["Runtime Layer"]
        Events[Event System]
        Plugins[Plugin System]
        Render[Renderer]
        Lifecycle[Lifecycle Manager]
    end

    subgraph Terminal["Terminal Layer"]
        Buffer[Buffer Manager]
        Cursor[Cursor Manager]
        Command[Command Processor]
        IO[I/O Manager]
    end

    %% Application Layer Connections
    App --> View
    View --> State
    State --> Events

    %% Component Layer Connections
    View --> Basic
    View --> Input
    View --> Layout
    View --> Advanced
    Basic --> Render
    Input --> Render
    Layout --> Render
    Advanced --> Render

    %% Runtime Layer Connections
    Events --> Plugins
    Events --> Lifecycle
    Render --> Buffer
    Lifecycle --> Plugins

    %% Terminal Layer Connections
    Buffer --> Cursor
    Buffer --> Command
    Command --> IO
    IO --> Buffer

    %% Style
    classDef layer fill:#f9f,stroke:#333,stroke-width:2px
    classDef component fill:#bbf,stroke:#333,stroke-width:1px
    class Application,Components,Runtime,Terminal layer
    class App,View,State,Basic,Input,Layout,Advanced,Events,Plugins,Render,Lifecycle,Buffer,Cursor,Command,IO component
```

## Core Subsystems

### Terminal Layer

- **Purpose:** Terminal I/O, state, and rendering
- **Key Components:**
  - Buffer Management (State, Cursor, Damage, Memory, Scrollback)
  - Command Processing (CSI, OSC, DCS handlers)
  - Input/Output Management
  - Screen Buffer Optimization
- **Performance:** < 1ms event processing, < 2ms screen updates

### Runtime Layer

- **Purpose:** Application lifecycle and state management
- **Features:**
  - Event dispatch and handling
  - Plugin management
  - State synchronization
  - Performance monitoring
- **Performance:** < 5ms concurrent operations

### Component Layer

- **Purpose:** UI components and layout management
- **Features:**
  - Declarative View DSL
  - Component lifecycle hooks
  - Theme and style management
  - Layout system
- **Components:**
  - Basic: Text, Button, Panel
  - Input: TextInput, MultiLineInput, SelectList
  - Layout: Row, Column, Grid
  - Advanced: Table, Scrollbar, Progress

### Plugin System

- **Purpose:** Extensibility and modularity
- **Features:**
  - Hot-reloadable plugins
  - Dependency resolution (Tarjan's algorithm)
  - Lifecycle management
  - Event handling
  - Error recovery

```mermaid
graph TB
    subgraph PluginSystem["Plugin System"]
        Registry[Plugin Registry]
        Loader[Plugin Loader]
        Resolver[Dependency Resolver]
        Lifecycle[Lifecycle Manager]
        Events[Event Handler]
    end

    subgraph Plugins["Plugins"]
        P1[Plugin 1]
        P2[Plugin 2]
        P3[Plugin 3]
    end

    subgraph Dependencies["Dependencies"]
        D1[Dependency 1]
        D2[Dependency 2]
    end

    %% Plugin System Flow
    Registry --> Loader
    Loader --> Resolver
    Resolver --> Lifecycle
    Lifecycle --> Events

    %% Plugin Connections
    P1 --> D1
    P2 --> D1
    P2 --> D2
    P3 --> D2

    %% Style
    classDef system fill:#f9f,stroke:#333,stroke-width:2px
    classDef plugin fill:#bbf,stroke:#333,stroke-width:1px
    classDef dep fill:#bfb,stroke:#333,stroke-width:1px
    class PluginSystem system
    class P1,P2,P3 plugin
    class D1,D2 dep
```

### Component Lifecycle

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

    state update {
        [*] --> process_event
        process_event --> update_state
        update_state --> schedule_render
        schedule_render --> [*]
    }

    state render {
        [*] --> diff
        diff --> apply_changes
        apply_changes --> [*]
    }
```

## Event & Rendering Pipeline

```bash
[Terminal Input/Event]
        ↓
[Terminal Driver] → [Event Struct]
        ↓
[Event Dispatcher]
        ↓
[Application.handle_event]
        ↓
[State Update]
        ↓
[View Render]
        ↓
[Terminal Buffer]
        ↓
[Terminal Output]
```

### Pipeline Flow Diagram

```mermaid
sequenceDiagram
    participant TI as Terminal Input
    participant TD as Terminal Driver
    participant ED as Event Dispatcher
    participant App as Application
    participant State as State
    participant View as View
    participant TB as Terminal Buffer
    participant TO as Terminal Output

    TI->>TD: Raw Input
    TD->>ED: Event Struct
    ED->>App: handle_event
    App->>State: Update
    State->>View: Render
    View->>TB: Update Buffer
    TB->>TO: Flush Output

    Note over TI,TO: Performance Requirements:<br/>Event Processing: < 1ms<br/>Screen Updates: < 2ms<br/>Concurrent Ops: < 5ms
```

## Performance Requirements

- **Event Processing:** < 1ms average, < 2ms 95th percentile
- **Screen Updates:** < 2ms average, < 5ms 95th percentile
- **Concurrent Operations:** < 5ms average, < 10ms 95th percentile

## Testing Infrastructure

- **Event-based synchronization** for async operations
- **Custom assertion helpers** for plugin/component lifecycle
- **Systematic use of Mox** for mocking
- **Test isolation** via unique state tracking
- **Performance testing** with defined requirements
- **Comprehensive coverage:** 1528 tests, 49 doctests

```mermaid
graph TB
    subgraph TestInfra["Testing Infrastructure"]
        Unit[Unit Tests]
        Integration[Integration Tests]
        Performance[Performance Tests]
        Mocks[Mock System]
        Helpers[Test Helpers]
    end

    subgraph Coverage["Test Coverage"]
        Components[Component Tests]
        Plugins[Plugin Tests]
        Terminal[Terminal Tests]
        Runtime[Runtime Tests]
    end

    subgraph Performance["Performance Metrics"]
        Events[Event Processing]
        Screen[Screen Updates]
        Concurrent[Concurrent Ops]
    end

    %% Test Infrastructure Connections
    Unit --> Mocks
    Integration --> Mocks
    Performance --> Helpers
    Mocks --> Helpers

    %% Coverage Connections
    Components --> Unit
    Plugins --> Unit
    Terminal --> Integration
    Runtime --> Integration

    %% Performance Connections
    Events --> Performance
    Screen --> Performance
    Concurrent --> Performance

    %% Style
    classDef infra fill:#f9f,stroke:#333,stroke-width:2px
    classDef coverage fill:#bbf,stroke:#333,stroke-width:1px
    classDef metrics fill:#bfb,stroke:#333,stroke-width:1px
    class TestInfra infra
    class Components,Plugins,Terminal,Runtime coverage
    class Events,Screen,Concurrent metrics
```

## Current Status (2025-05-10)

- **Test Suite:** 49 doctests, 1528 tests, 279 failures, 17 invalid, 21 skipped
- **Terminal subsystem refactoring complete**
- **Plugin system modularization complete**
- **Color system refactoring complete**
- **Performance infrastructure in place**

## Next Steps

1. Address remaining test failures
2. Complete OSC 4 handler implementation
3. Implement robust anchor checking
4. Document test writing guide
5. Continue code quality improvements

## Design Principles

- **Elm-style update/view separation**
- **NIF terminal I/O** (`rrex_termbox`)
- **Reusable, stateful components**
- **Modular, extensible plugins**
- **Adapter pattern for system/test**
- **Event-based async testing**
- **Comprehensive test infrastructure**
- **Centralized color system**

## References

- [Component Guide](../examples/guides/03_components_and_layout/components/README.md)
- [Plugin Development](../examples/guides/04_extending_raxol/plugin_development.md)
- [Testing Guide](../examples/guides/05_development_and_testing/testing.md)
- [Migration Guide](MIGRATION_GUIDE.md)
