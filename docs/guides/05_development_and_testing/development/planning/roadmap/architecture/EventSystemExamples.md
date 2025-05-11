---
title: Event System Examples
description: Examples demonstrating the event system in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: architecture
tags: [architecture, events, examples, documentation]
---

# Event System Examples

This document provides comprehensive examples of using the Raxol event system in components. These patterns demonstrate best practices for event handling, subscription management, and component lifecycle integration.

## Table of Contents

1. [Basic Keyboard Event Handling](#basic-keyboard-event-handling)
2. [Mouse Event Handling](#mouse-event-handling)
3. [Window Events and Responsive Layout](#window-events-and-responsive-layout)
4. [Timer and Interval Events](#timer-and-interval-events)
5. [Custom Events](#custom-events)
6. [Best Practices](#best-practices)

## Core Runtime Events

### Runtime Initialization

```elixir
# Subscribe to runtime initialization
Raxol.Core.Runtime.Events.Dispatcher.subscribe(self(), [:runtime_initialized])

# Handle the event
def handle_info({:runtime_initialized, runtime_pid}, state) do
  # Runtime is ready for use
  {:noreply, %{state | runtime_ready: true}}
end
```

### Plugin Manager Ready

```elixir
# Subscribe to plugin manager ready event
Raxol.Core.Runtime.Events.Dispatcher.subscribe(self(), [:plugin_manager_ready])

# Handle the event
def handle_info({:plugin_manager_ready, plugin_manager_pid}, state) do
  # Plugin manager is ready to load plugins
  {:noreply, %{state | plugin_manager_ready: true}}
end
```

## Plugin Manager Events

### Command Processing

```elixir
# Subscribe to command processed events
Raxol.Core.Runtime.Events.Dispatcher.subscribe(self(), [:command_processed])

# Handle the event
def handle_info({:command_processed, command, result}, state) do
  # Command has been processed
  Logger.info("Command processed: #{inspect(command)} with result: #{inspect(result)}")
  {:noreply, state}
end
```

### Plugin Loading

```elixir
# Subscribe to plugin load events
Raxol.Core.Runtime.Events.Dispatcher.subscribe(self(), [:plugin_load_attempted])

# Handle the event
def handle_info({:plugin_load_attempted, plugin_id}, state) do
  # Plugin load was attempted
  Logger.info("Plugin load attempted: #{plugin_id}")
  {:noreply, state}
end
```

## Component Manager Events

### Component Rendering

```elixir
# Subscribe to component render events
Raxol.Core.Runtime.Events.Dispatcher.subscribe(self(), [:component_queued_for_render])

# Handle the event
def handle_info({:component_queued_for_render, component_id}, state) do
  # Component is queued for rendering
  Logger.debug("Component queued for render: #{component_id}")
  {:noreply, state}
end
```

## Accessibility Events

### Preferences Applied

```elixir
# Subscribe to preferences events
Raxol.Core.Runtime.Events.Dispatcher.subscribe(self(), [:preferences_applied])

# Handle the event
def handle_info({:preferences_applied, preferences}, state) do
  # Accessibility preferences have been applied
  Logger.info("Accessibility preferences applied: #{inspect(preferences)}")
  {:noreply, state}
end
```

### Text Scale Updates

```elixir
# Subscribe to text scale events
Raxol.Core.Runtime.Events.Dispatcher.subscribe(self(), [:text_scale_updated])

# Handle the event
def handle_info({:text_scale_updated, scale}, state) do
  # Text scale has been updated
  Logger.info("Text scale updated to: #{scale}")
  {:noreply, state}
end
```

## Testing with Events

### Event-Based Synchronization

```elixir
defmodule MyTest do
  use ExUnit.Case
  import Raxol.Test.Integration.Assertions

  test "waits for runtime initialization" do
    # Start the runtime
    {:ok, _pid} = Raxol.Runtime.start_link([])

    # Wait for initialization event
    assert_receive {:runtime_initialized, _runtime_pid}, 1000

    # Continue with test
    # ...
  end

  test "verifies plugin loading" do
    # Start the plugin manager
    {:ok, _pid} = Raxol.Core.Runtime.Plugins.Manager.start_link([])

    # Attempt to load a plugin
    Raxol.Core.Runtime.Plugins.Manager.load_plugin("my_plugin", %{})

    # Verify plugin load attempt
    assert_receive {:plugin_load_attempted, "my_plugin"}, 1000
  end

  test "checks accessibility preferences" do
    # Set accessibility preferences
    Raxol.Core.Accessibility.Preferences.set_large_text(true)

    # Verify text scale update
    assert_receive {:text_scale_updated, 1.5}, 1000
  end
end
```

## Best Practices

1. **Event Subscription Management**

   - Always unsubscribe from events when no longer needed
   - Use pattern matching to handle specific events
   - Consider using event handlers for complex event processing

2. **Error Handling**

   - Handle all possible event patterns
   - Log unexpected events
   - Implement proper error recovery

3. **Testing**

   - Use `assert_receive` instead of `Process.sleep`
   - Clean up event subscriptions after tests
   - Test both success and failure cases

4. **Performance**
   - Subscribe only to needed events
   - Process events efficiently
   - Avoid blocking operations in event handlers

## Basic Keyboard Event Handling

This example shows how to handle keyboard input in a component:

```elixir
defmodule MyComponent do
  use Raxol.Component
  alias Raxol.Core.Events.{Event, Subscription}

  def init(_props) do
    # Subscribe to keyboard events
    {:ok, key_sub} = Subscription.subscribe_keyboard(keys: [:enter, :esc])

    %{
      subscription: key_sub,
      text: ""
    }
  end

  def handle_event(%Event{type: :key} = event, state) do
    case event.key do
      {:char, c} when c in ?a..?z ->
        {%{state | text: state.text <> <<c>>}, []}
      :enter ->
        {state, [{:submit, state.text}]}
      :esc ->
        {%{state | text: ""}, []}
      _ ->
        {state, []}
    end
  end

  def terminate(state) do
    Subscription.unsubscribe(state.subscription)
  end
end
```

## Mouse Event Handling

Example of handling mouse events with area filtering:

```elixir
defmodule ClickableArea do
  use Raxol.Component
  alias Raxol.Core.Events.{Event, Subscription}

  def init(props) do
    # Subscribe to mouse events in a specific area
    {:ok, mouse_sub} = Subscription.subscribe_mouse(
      buttons: [:left],
      area: {props.x, props.y, props.width, props.height}
    )

    %{
      subscription: mouse_sub,
      clicked: false
    }
  end

  def handle_event(%Event{type: :mouse} = event, state) do
    case event.mouse do
      %{button: :left, drag: false} ->
        {%{state | clicked: true}, [{:on_click, event.mouse.position}]}
      _ ->
        {state, []}
    end
  end
end
```

## Window Events and Responsive Layout

Example of handling window resize events for responsive layouts:

```elixir
defmodule ResponsivePanel do
  use Raxol.Component
  alias Raxol.Core.Events.{Event, Subscription}

  def init(_props) do
    # Subscribe to window resize events
    {:ok, window_sub} = Subscription.subscribe_window(actions: [:resize])

    %{
      subscription: window_sub,
      width: 0,
      height: 0
    }
  end

  def handle_event(%Event{type: :window} = event, state) do
    case event.window do
      %{action: :resize, width: w, height: h} ->
        {%{state | width: w, height: h}, [{:layout_changed, {w, h}}]}
      _ ->
        {state, []}
    end
  end
end
```

## Timer and Interval Events

Example of using timer events for periodic actions:

```elixir
defmodule AutoSave do
  use Raxol.Component
  alias Raxol.Core.Events.{Event, Subscription}
  alias Raxol.Core.Runtime.EventLoop

  def init(_props) do
    # Set up an interval for auto-saving
    {:ok, timer_ref} = EventLoop.set_interval(5000, :auto_save)
    {:ok, timer_sub} = Subscription.subscribe_timer(match: :auto_save)

    %{
      timer_ref: timer_ref,
      subscription: timer_sub,
      last_save: nil
    }
  end

  def handle_event(%Event{type: :timer, data: :auto_save}, state) do
    now = System.system_time(:second)
    {%{state | last_save: now}, [{:save_data}]}
  end

  def terminate(state) do
    EventLoop.cancel_timer(state.timer_ref)
    Subscription.unsubscribe(state.subscription)
  end
end
```

## Custom Events

Example of handling custom events for application-specific functionality:

```elixir
defmodule NotificationHandler do
  use Raxol.Component
  alias Raxol.Core.Events.{Event, Subscription, Manager}

  def init(_props) do
    # Subscribe to custom notification events
    {:ok, custom_sub} = Subscription.subscribe_custom(
      match: {:notification, _}
    )

    %{
      subscription: custom_sub,
      notifications: []
    }
  end

  def handle_event(%Event{type: :custom, data: {:notification, msg}}, state) do
    {%{state | notifications: [msg | state.notifications]}, []}
  end

  # Dispatch a custom notification
  def notify(message) do
    Manager.dispatch(Event.custom({:notification, message}))
  end
end
```
