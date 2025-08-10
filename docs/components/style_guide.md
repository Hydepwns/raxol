---
title: Component Style Guide
description: Essential styling patterns and best practices for Raxol components
date: 2025-08-10
author: Raxol Team
section: components
tags: [styling, components, design, patterns, guide]
---

# Component Style Guide

Essential styling patterns and best practices for Raxol components.

## Quick Reference

- [Component Structure](#component-structure) - Module organization and patterns
- [Naming Conventions](#naming-conventions) - Consistent naming
- [Code Style](#code-style) - Elixir coding standards
- [Styling Patterns](#styling-patterns) - Visual design patterns
- [Accessibility](#accessibility) - Accessibility guidelines

## Component Structure

### Module Organization

```elixir
defmodule Raxol.UI.Components.Input.TextInput do
  @moduledoc """
  A text input component with validation and formatting support.

  ## Props
  * `:value` - Current input value
  * `:placeholder` - Placeholder text
  * `:disabled` - Whether the input is disabled
  * `:on_change` - Callback for value changes
  """

  @behaviour Raxol.UI.Components.Base.Component

  # Type definitions
  @type props :: %{
    value: String.t(),
    placeholder: String.t(),
    disabled: boolean(),
    on_change: (String.t() -> term())
  }

  @type state :: %{
    value: String.t(),
    focused: boolean(),
    error: String.t() | nil
  }

  # Constants
  @default_theme %{
    colors: %{text: "#000000", background: "#FFFFFF", error: "#FF0000"}
  }

  # Callbacks
  @impl true
  def init(props) do
    %{
      value: props[:value] || "",
      focused: false,
      error: nil
    }
  end

  @impl true
  def mount(state), do: {state, []}

  @impl true
  def update({:set_value, value}, state) do
    {Map.put(state, :value, value), []}
  end

  @impl true
  def render(state) do
    %{
      type: :text_input,
      value: state.value,
      error: state.error,
      focused: state.focused
    }
  end

  @impl true
  def handle_event(%{type: :change, value: value}, state) do
    {Map.put(state, :value, value), [{:command, :value_changed}]}
  end

  @impl true
  def unmount(state), do: state
end
```

## Naming Conventions

### Module Names

- Use PascalCase: `Raxol.UI.Components.Input.TextInput`
- Group related components in namespaces
- Use descriptive, specific names

### Function Names

- Use snake_case: `handle_text_change`, `validate_input`
- Use descriptive, action-oriented names
- Prefix private functions with `p_` if needed

### Variable Names

- Use snake_case: `current_value`, `is_valid`
- Use descriptive names that indicate purpose
- Avoid abbreviations unless very common

### Type Names

- Use snake_case: `text_input_props`, `text_input_state`
- Prefix with component name for clarity

## Code Style

### Function Documentation

```elixir
@doc """
Handles text input changes.

## Parameters
  * `event` - The input change event
  * `state` - Current component state

## Returns
  * `{new_state, commands}` - Updated state and commands
"""
@impl true
def handle_event(%{type: :change, value: value}, state) do
  {Map.put(state, :value, value), [{:command, :value_changed}]}
end
```

### Pattern Matching

```elixir
# Prefer pattern matching in function heads
def handle_event(%{type: :click} = event, state) do
  # Handle click
end

def handle_event(%{type: :key_press, key: :enter}, state) do
  # Handle enter key
end

def handle_event(%{type: :change, value: value}, state) do
  # Handle value change
end
```

### Error Handling

```elixir
def init(props) do
  case validate_props(props) do
    {:ok, validated_props} ->
      %{
        value: validated_props[:value] || "",
        focused: false,
        error: nil
      }

    {:error, error} ->
      %{
        value: "",
        focused: false,
        error: error
      }
  end
end
```

## Styling Patterns

### Color System

```elixir
# Standard colors
@colors %{
  primary: :cyan,
  secondary: :blue,
  success: :green,
  warning: :yellow,
  error: :red,
  info: :blue,
  text: :white,
  background: :black
}

# Usage in components
def render(state) do
  %{
    type: :text,
    content: state.value,
    attributes: %{
      color: if(state.error, do: @colors.error, else: @colors.text)
    }
  }
end
```

### Border Styles

```elixir
# Border options
@borders %{
  none: "",
  single: "─│┌┐└┘",
  double: "═║╔╗╚╝",
  rounded: "─│╭╮╰╯"
}

# Usage
def render(state) do
  %{
    type: :box,
    attributes: %{
      border: if(state.focused, do: :double, else: :single)
    },
    content: state.content
  }
end
```

### Layout Patterns

```elixir
# Common layout configurations
@layouts %{
  centered: %{
    justify: :center,
    align: :center
  },
  spaced: %{
    justify: :space_between,
    align: :center
  },
  stacked: %{
    direction: :column,
    gap: 1
  }
}
```

### Responsive Design

```elixir
def render(state) do
  width = calculate_width(state.container_size)

  %{
    type: :box,
    attributes: %{
      width: width,
      height: :auto
    },
    content: adapt_content_to_width(state.content, width)
  }
end
```

## Accessibility

### Keyboard Navigation

```elixir
def handle_event(%{type: :key_press, key: key}, state) do
  case key do
    :tab ->
      # Handle tab navigation
      {state, [{:command, :focus_next}]}

    :enter ->
      # Handle enter key
      {state, [{:command, :submit}]}

    :escape ->
      # Handle escape key
      {state, [{:command, :cancel}]}

    _ ->
      {state, []}
  end
end
```

### Screen Reader Support

```elixir
def render(state) do
  %{
    type: :text_input,
    attributes: %{
      "aria-label": state.label,
      "aria-describedby": state.error_id,
      "aria-invalid": state.error != nil
    },
    content: state.value
  }
end
```

### Focus Management

```elixir
def handle_event(%{type: :focus}, state) do
  new_state = Map.put(state, :focused, true)
  {new_state, [{:command, :focus_gained}]}
end

def handle_event(%{type: :blur}, state) do
  new_state = Map.put(state, :focused, false)
  {new_state, [{:command, :focus_lost}]}
end
```

## Performance Patterns

### Memoization

```elixir
def render(state) do
  # Cache expensive computations
  cached_value = get_cached_value(state.value, state.cache_key)

  %{
    type: :text,
    content: cached_value,
    attributes: %{color: calculate_color(state)}
  }
end
```

### Lazy Loading

```elixir
def mount(state) do
  if state.should_load_content do
    # Load content asynchronously
    {state, [{:command, :load_content}]}
  else
    {state, []}
  end
end
```

### Event Batching

```elixir
def handle_event(%{type: :rapid_changes, changes: changes}, state) do
  # Batch multiple changes together
  new_state = Enum.reduce(changes, state, fn change, acc ->
    apply_change(change, acc)
  end)

  {new_state, [{:command, :changes_batched}]}
end
```

## Best Practices

### Component Design

1. **Single Responsibility**: Each component should have one clear purpose
2. **Composition**: Build complex UIs from simple components
3. **Reusability**: Design components to be reusable across contexts
4. **Consistency**: Follow established patterns and conventions

### State Management

1. **Minimal State**: Keep component state as small as possible
2. **Immutable Updates**: Always use immutable state updates
3. **Clear Data Flow**: Make data flow predictable and traceable
4. **Validation**: Validate state changes and props

### Error Handling

1. **Graceful Degradation**: Handle errors without crashing
2. **User Feedback**: Provide clear error messages to users
3. **Recovery**: Allow users to recover from errors
4. **Logging**: Log errors for debugging

### Testing

1. **Unit Tests**: Test individual component functions
2. **Integration Tests**: Test component interactions
3. **Accessibility Tests**: Test keyboard navigation and screen readers
4. **Performance Tests**: Test rendering and event handling performance

## Common Patterns

### Form Components

```elixir
defmodule FormField do
  def init(props) do
    %{
      value: props[:value] || "",
      error: nil,
      touched: false,
      valid: true
    }
  end

  def handle_event(%{type: :change, value: value}, state) do
    new_state = %{state |
      value: value,
      touched: true,
      valid: validate_value(value)
    }

    {new_state, [{:command, {:field_changed, value}}]}
  end
end
```

### List Components

```elixir
defmodule List do
  def init(props) do
    %{
      items: props[:items] || [],
      selected: nil,
      scroll_position: 0
    }
  end

  def handle_event(%{type: :select, index: index}, state) do
    {Map.put(state, :selected, index), [{:command, {:item_selected, Enum.at(state.items, index)}}]}
  end
end
```

### Modal Components

```elixir
defmodule Modal do
  def init(props) do
    %{
      visible: props[:visible] || false,
      content: props[:content],
      on_close: props[:on_close]
    }
  end

  def handle_event(%{type: :close}, state) do
    {Map.put(state, :visible, false), [{:command, :modal_closed}]}
  end
end
```

## Additional Resources

- [Component Guide](README.md) - Component development patterns
- [Testing Guide](../examples/guides/05_development_and_testing/testing.md) - Component testing patterns
