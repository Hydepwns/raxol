# Raxol API Documentation

_Raxol 0.6.0 introduces an improved plugin system and enhanced terminal reliability. Make sure you are using the latest version for the best experience!_

## Overview

This document provides detailed API reference for the Raxol Terminal Emulator. Raxol provides a comprehensive set of APIs for building terminal-based applications with a focus on performance, accessibility, and developer experience.

## Core APIs

### Application Lifecycle

```elixir
# Start a Raxol application
Raxol.Core.Runtime.Lifecycle.start_application(module, opts \\ [])

# Stop a Raxol application
Raxol.Core.Runtime.Lifecycle.stop_application(pid)

# Get application state
Raxol.Core.Runtime.Lifecycle.get_state(pid)
```

### Terminal API

```elixir
# Terminal initialization and configuration
Raxol.Terminal.start_link(opts \\ [])
Raxol.Terminal.configure(opts)

# Terminal operations
Raxol.Terminal.write(data)
Raxol.Terminal.read()
Raxol.Terminal.clear()
Raxol.Terminal.get_size()
Raxol.Terminal.set_title(title)

# Terminal state
Raxol.Terminal.get_state()
Raxol.Terminal.alternate_screen?()
```

### Component API

```elixir
# Component creation and lifecycle
Raxol.UI.Components.create(type, props)
Raxol.UI.Components.mount(component)
Raxol.UI.Components.update(component, props)
Raxol.UI.Components.unmount(component)

# Component state management
Raxol.UI.Components.get_state(component)
Raxol.UI.Components.set_state(component, state)
Raxol.UI.Components.update_state(component, fun)

# Component rendering
Raxol.UI.Components.render(component)
Raxol.UI.Components.force_update(component)
```

### Plugin API

```elixir
# Plugin registration and lifecycle
Raxol.Core.Runtime.Plugins.register(plugin)
Raxol.Core.Runtime.Plugins.start(plugin)
Raxol.Core.Runtime.Plugins.stop(plugin)

# Plugin management
Raxol.Core.Runtime.Plugins.list()
Raxol.Core.Runtime.Plugins.get(plugin_id)
Raxol.Core.Runtime.Plugins.enabled?(plugin_id)
```

### Event System

```elixir
# Event handling
Raxol.Core.Runtime.Events.subscribe(event_type, handler)
Raxol.Core.Runtime.Events.publish(event_type, data)
Raxol.Core.Runtime.Events.unsubscribe(event_type, handler)

# Event types
Raxol.Core.Runtime.Events.key_event(key, modifiers)
Raxol.Core.Runtime.Events.mouse_event(x, y, button, modifiers)
Raxol.Core.Runtime.Events.resize_event(width, height)
```

### Configuration

```elixir
# Configuration management
Raxol.Config.get(key)
Raxol.Config.set(key, value)
Raxol.Config.update(key, fun)
Raxol.Config.delete(key)

# Runtime configuration
Raxol.set_theme(theme)
Raxol.set_accessibility_option(option, value)
Raxol.set_log_level(level)
```

### Theming

```elixir
# Theme management
Raxol.UI.Theming.Theme.get(theme_id)
Raxol.UI.Theming.Theme.apply(theme)
Raxol.UI.Theming.Theme.create_high_contrast_variant(theme)

# Color system
Raxol.Core.ColorSystem.get_color(name)
Raxol.Core.ColorSystem.get_ui_color(role)
Raxol.Core.ColorSystem.apply_theme(theme_id, opts \\ [])
```

### Metrics and Debugging

```elixir
# Metrics collection
Raxol.Core.Metrics.record(metric_name, value)
Raxol.Core.Metrics.get(metric_name)
Raxol.Core.Metrics.reset(metric_name)

# Debugging
Raxol.Core.Debug.enable()
Raxol.Core.Debug.disable()
Raxol.Core.Debug.log(message, level \\ :info)
```

## Common Options

Many Raxol APIs accept options as keyword lists. Here are some common options:

```elixir
# Terminal options
opts = [
  width: 80,
  height: 24,
  title: "My App",
  fps: 60,
  debug: false,
  quit_keys: [:ctrl_c, "q"]
]

# Accessibility options
accessibility_opts = [
  screen_reader: true,
  high_contrast: false,
  large_text: false,
  reduced_motion: false
]

# Theme options
theme_opts = [
  high_contrast: true,
  color_scheme: :dark
]
```

## Error Handling

Raxol uses standard Elixir error handling patterns:

```elixir
# Pattern matching on results
case Raxol.Terminal.start_link(opts) do
  {:ok, pid} ->
    # Success case
  {:error, reason} ->
    # Error case
end

# Using with
with {:ok, pid} <- Raxol.Terminal.start_link(opts),
     :ok <- Raxol.Terminal.configure(term_opts) do
  # Success case
else
  {:error, reason} ->
    # Error case
end
```

## Best Practices

1. **Error Handling**: Always handle potential errors from API calls
2. **Resource Cleanup**: Ensure proper cleanup of resources (e.g., unmounting components)
3. **Event Management**: Unsubscribe from events when no longer needed
4. **Configuration**: Use environment variables for configuration when possible
5. **Performance**: Monitor metrics and adjust configuration accordingly

For more detailed API documentation, see the ExDoc-generated documentation at `/docs`.
