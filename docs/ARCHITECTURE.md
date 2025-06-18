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

Raxol is a sophisticated terminal user interface toolkit that provides a comprehensive set of features for building interactive terminal applications. The system uses a layered architecture with clear separation of concerns:

```mermaid
graph TB
    subgraph Layers["System Layers"]
        App[Application Layer]
        View[View Layer]
        Runtime[Runtime Layer]
        Terminal[Terminal Layer]
    end

    App --> View
    View --> Runtime
    Runtime --> Terminal

    classDef layer fill:#22223b,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:16px,padding:8px;
    class App,View,Runtime,Terminal layer;
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
        UI[UI Composition]
        Style[Styling System]
        UI --> Style
    end

    subgraph Runtime["Runtime Layer"]
        direction TB
        Events[Event System]
        Render[Renderer]
        Events --> Render
    end

    subgraph Terminal["Terminal Layer"]
        direction TB
        IO[I/O Management]
        Buffer[Buffer System]
        IO --> Buffer
    end

    classDef layer fill:#22223b,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class App,View,Runtime,Terminal layer;
```

## Core Subsystems

### Terminal Layer

```mermaid
graph TB
    subgraph Terminal["Terminal Layer"]
        Buffer[Buffer Manager]
        Cursor[Cursor Manager]
        IO[I/O Manager]
        Format[Text Formatter]
    end

    Buffer --> Cursor
    Buffer --> Format
    IO --> Buffer

    classDef component fill:#4a4e69,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class Buffer,Cursor,IO,Format component;
```

### Runtime Layer

```mermaid
graph TB
    subgraph Runtime["Runtime Layer"]
        Events[Event System]
        Plugins[Plugin System]
        Render[Renderer]
        Lifecycle[Lifecycle Manager]
    end

    Events --> Plugins
    Events --> Lifecycle
    Lifecycle --> Render

    classDef component fill:#4a4e69,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class Events,Plugins,Render,Lifecycle component;
```

### Component Layer

```mermaid
graph TB
    subgraph Components["Component Layer"]
        Basic[Basic Components]
        Input[Input Components]
        Layout[Layout Components]
        Advanced[Advanced Components]
    end

    Basic --> Render
    Input --> Render
    Layout --> Render
    Advanced --> Render

    classDef component fill:#4a4e69,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class Basic,Input,Layout,Advanced component;
```

### Plugin System

```mermaid
graph TB
    subgraph PluginSystem["Plugin System"]
        Registry[Plugin Registry]
        Loader[Plugin Loader]
        Lifecycle[Lifecycle Manager]
    end

    Registry --> Loader
    Loader --> Lifecycle

    classDef component fill:#4a4e69,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class Registry,Loader,Lifecycle component;
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
```

## Event & Rendering Pipeline

```mermaid
sequenceDiagram
    participant TI as Terminal Input
    participant ED as Event Dispatcher
    participant App as Application
    participant View as View
    participant TB as Terminal Buffer

    TI->>ED: Raw Input
    ED->>App: handle_event
    App->>View: Update
    View->>TB: Render
```

## Performance Requirements

- **Event Processing:** < 1ms average, < 2ms 95th percentile
- **Screen Updates:** < 2ms average, < 5ms 95th percentile
- **Concurrent Operations:** < 5ms average, < 10ms 95th percentile

## Testing Infrastructure

```mermaid
graph TB
    subgraph Testing["Testing Infrastructure"]
        Unit[Unit Tests]
        Integration[Integration Tests]
        Performance[Performance Tests]
    end

    subgraph Coverage["Test Coverage"]
        Components[Component Tests]
        Plugins[Plugin Tests]
        Terminal[Terminal Tests]
    end

    Unit --> Components
    Integration --> Plugins
    Integration --> Terminal
    Performance --> Testing

    classDef test fill:#4a4e69,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class Unit,Integration,Performance,Components,Plugins,Terminal test;
```

## Design Principles

- **Elm-style update/view separation**: e.g. `Raxol.UI.Components.Base.Component`
- **NIF terminal I/O** (hosted in `priv/static/@static/termbox2_nif`): we maintain a [fork of this ourselves](https://github.com/Hydepwns/termbox2_nif)
- **Reusable, stateful components**: e.g. `Raxol.UI.Components.Base.Component`
- **Modular, extensible plugins**: e.g. `Raxol.Core.Runtime.Plugins.Plugin`
- **Adapter pattern for system/test**: e.g. `Raxol.Core.Runtime.System.Adapter`
- **Event-based async testing**: e.g. `Raxol.Core.Runtime.Events.Event`
- **Comprehensive test infrastructure**: e.g. `Raxol.Core.Runtime.Testing.Test`
- **Centralized color system**: e.g. `Raxol.Core.ColorSystem`

## References

- [Component Guide](../examples/guides/03_components_and_layout/components/README.md)
- [Plugin Development](../examples/guides/04_extending_raxol/plugin_development.md)
- [Testing Guide](../examples/guides/05_development_and_testing/testing.md)
