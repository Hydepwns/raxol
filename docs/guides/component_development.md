---
title: UI Component Development Guide
description: Guide for creating custom UI components in Raxol
date: 2024-07-27
author: Raxol Team
section: guides
tags: [development, components, ui, guide, custom components]
---

# UI Component Development Guide

This guide explains how to create your own reusable UI components in Raxol, building upon the concepts introduced in the [Quick Start Guide](quick_start.md) and the [UI Components Guide](components.md).

Developing custom components allows you to encapsulate specific UI logic, state, and presentation, making your applications more modular and maintainable.

## The `Base.Component` Behaviour

The foundation for creating UI components in Raxol is the `Raxol.UI.Components.Base.Component` behaviour. By implementing this behaviour, your module defines how the component initializes, updates its internal state, handles events, and renders itself.

```elixir
defmodule MyApp.Components.MyCustomComponent do
  # Use the core component behaviour
  use Raxol.UI.Components.Base.Component

  # Implement the required callbacks...
end
```

## Core Callbacks

You need to implement the following callbacks defined by the `Base.Component` behaviour:

1. **`init/1`**

   - **Purpose:** Initializes the component's internal state. Called when the component is first mounted.
   - **Arguments:** Receives the initial `assigns` (attributes) passed to the component.
   - **Return Value:** Must return the initial state (often a map) for the component instance.

   ```elixir
   @impl true
   def init(assigns) do
     # Example: Set initial state based on passed attributes
     %{
       label: assigns[:label] || "Default Label",
       is_active: assigns[:active] || false,
       internal_counter: 0
     }
   end
   ```

2. **`update/2`**

   - **Purpose:** Updates the component's state based on changes to its _assigns_ (attributes passed from the parent). This is called when the parent view re-renders and potentially passes new attributes to the component.
   - **Arguments:** Receives the new `assigns` and the current `model` (the component's internal state).
   - **Return Value:** Must return the _new_ state for the component.

   ```elixir
   @impl true
   def update(assigns, model) do
     # Example: Update state if the 'label' assign changed
     %{model | label: assigns[:label] || model.label}
   end
   ```

3. **`handle_event/3`**

   - **Purpose:** Handles events targeted at this component instance (e.g., clicks, key presses if captured). It allows the component to modify its own internal state in response to user interaction or other events.
   - **Arguments:** Receives the `event` (often an atom like `:click` or a more complex `Raxol.Core.Events.Event` struct), the `assigns`, and the current `model`.
   - **Return Value:** Must return the _new_ state for the component.

   ```elixir
   @impl true
   def handle_event(:toggle_active, _assigns, model) do
     # Example: Handle an internal event to toggle activity
     %{model | is_active: not model.is_active}
   end

   def handle_event(_other_event, _assigns, model) do
     # Important: Return the unchanged model for events you don't handle
     model
   end
   ```

4. **`render/2`**

   - **Purpose:** Defines the UI structure of the component based on its current state and assigns. This is where you use `Raxol.View.Elements` macros or HEEx syntax.
   - **Arguments:** Receives the current `assigns` and the current `model` (the component's state).
   - **Return Value:** Must return a rendered view structure, typically using the `Raxol.View.view/1` macro or `~H` sigil.

   ```elixir
   # Import View elements for convenience
   import Raxol.View.Elements

   @impl true
   def render(assigns, model) do
     # Use the view macro to define the component's appearance
     view do
       box border: :single, padding: 1 do
         text content: "Label: #{model.label}"
         text content: "Active: #{model.is_active}"
         text content: "Counter: #{model.internal_counter}"
         # Example: A button within the component that sends an event
         # handled by this component's handle_event/3
         button label: "Toggle", on_click: :toggle_active
       end
     end
   end
   ```

## Example: A Labelled Counter Component

Let's combine these concepts into a simple component that displays a label and an internal counter that can be incremented.

```elixir
# lib/my_app/components/labelled_counter.ex
defmodule MyApp.Components.LabelledCounter do
  use Raxol.UI.Components.Base.Component
  import Raxol.View.Elements

  # 1. Initialize state with label and counter
  @impl true
  def init(assigns) do
    %{
      label: assigns[:label] || "Counter",
      count: assigns[:initial_count] || 0
    }
  end

  # 2. Update state if label assign changes
  @impl true
  def update(assigns, model) do
    %{model | label: assigns[:label] || model.label}
  end

  # 3. Handle the :increment event to update the count
  @impl true
  def handle_event(:increment, _assigns, model) do
    %{model | count: model.count + 1}
  end

  def handle_event(_other, _assigns, model) do
    model # Ignore other events
  end

  # 4. Render the label, count, and an increment button
  @impl true
  def render(assigns, model) do
    view do
      box border: :rounded do
        text content: "#{model.label}: #{model.count}"
        # This button sends :increment to *this* component's handle_event
        button label: "Inc", on_click: :increment
      end
    end
  end
end
```

## Using Your Custom Component

You use your custom component within a `Raxol.Core.Runtime.Application` module's `render/1` function just like built-in components.

**Using Function Call Syntax (`Raxol.View`):**

```elixir
defmodule MyApp.Application do
  use Raxol.Core.Runtime.Application
  use Raxol.View
  import Raxol.View.Elements
  alias MyApp.Components.LabelledCounter # Alias your component

  @impl true
  def render(assigns) do
    view do
      box padding: 1 do
        text content: "My Application View"
        # Use your component like a function
        LabelledCounter label: "Total Clicks", initial_count: 5
        LabelledCounter label: "Score" # Uses default initial_count 0
      end
    end
  end

  # ... init/1, update/2 ...
end
```

**Using HEEx Sigil (`~H`):**

```elixir
defmodule MyApp.ApplicationHEEx do
  use Raxol.Core.Runtime.Application
  alias MyApp.Components.LabelledCounter # Alias your component

  @impl true
  def render(assigns) do
    ~H"""
    <box padding={1}>
      <text content="My Application View (HEEx)" />
      <%!-- Use your component like an HTML tag --%>
      <LabelledCounter label="Total Clicks" initial_count={5} />
      <LabelledCounter label="Score" />
    </box>
    """
  end

  # ... init/1, update/2 ...
end
```

## Testing Components

Testing custom components is crucial. You can test:

- **Initialization:** Does `init/1` set the correct initial state?
- **State Updates:** Does `update/2` and `handle_event/3` modify the state correctly?
- **Rendering:** Does `render/2` produce the expected view structure for a given state?

Refer to the main [Testing Guide](testing.md) for detailed strategies and helper functions that might be available for component testing (e.g., functions to render a component in isolation). A basic test might involve directly calling the component's functions:

```elixir
defmodule MyApp.Components.LabelledCounterTest do
  use ExUnit.Case, async: true
  alias MyApp.Components.LabelledCounter

  test "init sets initial state" do
    state = LabelledCounter.init(%{label: "Test", initial_count: 10})
    assert state == %{label: "Test", count: 10}
  end

  test "handle_event :increment updates count" do
    initial_state = LabelledCounter.init(%{}) # label: "Counter", count: 0
    new_state = LabelledCounter.handle_event(:increment, %{}, initial_state)
    assert new_state.count == 1
  end

  # More complex tests might involve rendering and asserting structure
  # test "render shows correct count" do ... end
end
```

## Best Practices

- **Keep Components Focused:** Aim for single responsibility.
- **Manage State Internally:** Components should manage their own relevant state. Pass data down via assigns when necessary.
- **Emit Events for Parent Interaction:** If a component needs to notify its parent of something, have its `handle_event/3` return a specific message or structure that the parent's `update/2` can handle (this is a more advanced pattern).
- **Document Your Components:** Use `@moduledoc` and document assigns and internal events.
