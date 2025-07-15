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

Raxol is a terminal user interface toolkit built on The Elm Architecture (TEA) that provides a comprehensive set of features for building interactive terminal applications. The system uses a layered architecture with clear separation of concerns.

```mermaid
graph TB
    App[Application Layer]
    View[View Layer]
    Runtime[Runtime Layer]
    Terminal[Terminal Layer]

    App --> View
    View --> Runtime
    Runtime --> Terminal

    classDef layer fill:#22223b,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:16px,padding:8px;
    class App,View,Runtime,Terminal layer;
```

### Layer Responsibilities

- **Application Layer**: User-defined application logic following TEA pattern
- **View Layer**: UI composition and rendering with components
- **Runtime Layer**: Event handling, lifecycle management, and coordination
- **Terminal Layer**: Low-level terminal interaction and buffer management

## Core Subsystems

### Application Runtime

The application runtime manages the lifecycle of Raxol applications:

```mermaid
graph LR
    Lifecycle[Lifecycle Manager]
    Dispatcher[Event Dispatcher]
    Plugins[Plugin Manager]
    Renderer[Rendering Engine]

    Lifecycle --> Dispatcher
    Dispatcher --> Plugins
    Dispatcher --> Renderer

    classDef component fill:#4a4e69,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class Lifecycle,Dispatcher,Plugins,Renderer component;
```

### View System

The view system provides component-based UI composition:

```mermaid
graph TB
    View[View Module]
    Components[UI Components]
    Layout[Layout Engine]
    Renderer[Renderer]

    View --> Components
    Components --> Layout
    Layout --> Renderer

    classDef component fill:#4a4e69,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class View,Components,Layout,Renderer component;
```

### Terminal System

The terminal system handles low-level terminal operations:

```mermaid
graph TB
    Emulator[Terminal Emulator]
    Buffer[Buffer Manager]
    Parser[ANSI Parser]
    IO[I/O Manager]

    Emulator --> Buffer
    Emulator --> Parser
    Emulator --> IO

    classDef component fill:#4a4e69,stroke:#f8f8f2,stroke-width:2px,color:#f8f8f2,font-size:14px,padding:6px;
    class Emulator,Buffer,Parser,IO component;
```

## Application Lifecycle

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

## Event Flow

```mermaid
sequenceDiagram
    participant Terminal
    participant Runtime
    participant App
    participant View
    participant Renderer

    Terminal->>Runtime: Raw Input
    Runtime->>App: handle_event
    App->>View: Update
    View->>Renderer: Render
    Renderer->>Terminal: Output
```

## Key Modules

### Application Layer

- `Raxol.Core.Runtime.Application` - Main application behaviour
- `Raxol.Core.Runtime.Lifecycle` - Application lifecycle management
- `Raxol.Core.Runtime.Events.Dispatcher` - Event dispatching

### View Layer

- `Raxol.Core.Renderer.View` - View composition and layout
- `Raxol.Core.Renderer.Layout` - Layout calculations
- `Raxol.UI.Components.*` - UI component library

### Runtime Layer

- `Raxol.Core.Runtime.Supervisor` - Runtime supervision
- `Raxol.Core.Runtime.Plugins.Manager` - Plugin management
- `Raxol.Core.Runtime.Rendering.Engine` - Rendering coordination

### Terminal Layer

- `Raxol.Terminal.Emulator` - Terminal emulation
- `Raxol.Terminal.Buffer.Manager` - Buffer management (now powered by the modular `BufferServerRefactored` system)
- `Raxol.Terminal.ANSI.*` - ANSI sequence handling

> **Note:** The buffer management subsystem was fully migrated from a monolithic GenServer (`BufferServer`) to the new modular `BufferServerRefactored` architecture. This new system is composed of focused modules for operation processing, batching, metrics, and damage tracking, resulting in a 42,000x performance improvement and greatly improved maintainability. All legacy code has been removed.

## Design Principles

- **Elm Architecture**: Model-Update-View pattern with unidirectional data flow
- **Component-based**: Reusable UI components with consistent interfaces
- **Performance-first**: Optimized for low-latency terminal operations
- **Extensible**: Plugin system for custom functionality
- **Accessible**: Built-in accessibility features and screen reader support

## Performance Requirements

- **Event Processing**: < 1ms average
- **Screen Updates**: < 2ms average
- **Concurrent Operations**: < 5ms average
- **Terminal Operations**: < 0.5ms average

## References

- [Component Guide](../examples/guides/03_components_and_layout/components/README.md)
- [Plugin Development](../examples/guides/04_extending_raxol/plugin_development.md)
- [Testing Guide](../examples/guides/05_development_and_testing/testing.md)
