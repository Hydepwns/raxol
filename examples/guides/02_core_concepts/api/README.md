# Raxol API Documentation

## Overview

This document provides detailed API reference for the Raxol Terminal Emulator.

## Core APIs

### Terminal API

```elixir
# Terminal initialization
Raxol.Terminal.start_link(opts \\ [])

# Terminal configuration
Raxol.Terminal.configure(opts)

# Terminal operations
Raxol.Terminal.write(data)
Raxol.Terminal.read()
Raxol.Terminal.clear()
```

### Component API

```elixir
# Component creation
Raxol.UI.Components.create(type, props)

# Component lifecycle
Raxol.UI.Components.mount(component)
Raxol.UI.Components.update(component, props)
Raxol.UI.Components.unmount(component)
```

### Plugin API

```elixir
# Plugin registration
Raxol.Core.Runtime.Plugins.register(plugin)

# Plugin lifecycle
Raxol.Core.Runtime.Plugins.start(plugin)
Raxol.Core.Runtime.Plugins.stop(plugin)
```

## Event System

```elixir
# Event handling
Raxol.Core.Runtime.Events.subscribe(event_type, handler)
Raxol.Core.Runtime.Events.publish(event_type, data)
```

## Configuration

```elixir
# Configuration management
Raxol.Config.get(key)
Raxol.Config.set(key, value)
Raxol.Config.update(key, fun)
```

## Metrics

```elixir
# Metrics collection
Raxol.Core.Metrics.record(metric_name, value)
Raxol.Core.Metrics.get(metric_name)
```

For more detailed API documentation, see the ExDoc-generated documentation at `/docs`.
