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

## Best Practices

1. **Subscription Management**
   - Always store subscription references in component state
   - Clean up subscriptions in the `terminate/1` callback
   - Use pattern matching in `handle_event/2` for clear event handling

2. **Event Filtering**
   - Use subscription options to filter events at the source
   - Implement additional filtering in `handle_event/2` if needed
   - Keep event handlers focused and specific

3. **State Updates**
   - Return updated state and commands tuple from event handlers
   - Keep state updates minimal and focused
   - Use pattern matching to handle specific event cases

4. **Command Emission**
   - Use commands to communicate with parent components
   - Keep commands simple and data-focused
   - Document expected command formats

5. **Error Handling**
   - Handle unexpected events gracefully
   - Implement proper error recovery
   - Log relevant error information

6. **Testing**
   - Test event handlers with sample events
   - Verify state updates and command emissions
   - Test subscription cleanup 