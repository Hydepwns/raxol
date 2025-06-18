# Raxol Component Style Guide

> See also: [Component Architecture](./component_architecture.md) for component lifecycle and patterns.

## Table of Contents

1. [Component Structure](#component-structure)
2. [Naming Conventions](#naming-conventions)
3. [Code Style](#code-style)
4. [Component Design](#component-design)
5. [Testing Style](#testing-style)
6. [Documentation Style](#documentation-style)
7. [Accessibility Guidelines](#accessibility-guidelines)
8. [Performance Guidelines](#performance-guidelines)

## Component Structure

### Module Organization

1. **Module Documentation**

   ```elixir
   defmodule Raxol.UI.Components.Input.TextInput do
     @moduledoc """
     A text input component with validation and formatting support.

     ## Features
     * Real-time validation
     * Custom formatting
     * Error handling
     * Accessibility support

     ## Props
     * `:id` - Unique identifier for the component
     * `:value` - Current input value
     * `:placeholder` - Placeholder text
     * `:disabled` - Whether the input is disabled
     * `:on_change` - Callback for value changes
     * `:on_submit` - Callback for form submission
     """
   ```

2. **Type Specifications**

   ```elixir
   @type props :: %{
     required(:id) => String.t(),
     required(:value) => String.t(),
     optional(:placeholder) => String.t(),
     optional(:disabled) => boolean(),
     optional(:on_change) => (String.t() -> term()),
     optional(:on_submit) => (String.t() -> term())
   }

   @type state :: %{
     id: String.t(),
     value: String.t(),
     error: String.t() | nil,
     focused: boolean(),
     dirty: boolean()
   }
   ```

3. **Callback Order**

   ```elixir
   # 1. Behaviour declaration
   @behaviour Raxol.UI.Components.Base.Component

   # 2. Type definitions
   @type props :: ...
   @type state :: ...

   # 3. Constants
   @default_theme %{
     colors: %{
       text: "#000000",
       background: "#FFFFFF",
       error: "#FF0000"
     }
   }

   # 4. Callbacks
   @impl true
   def init(props) do
     validate_props(props)
     %{
       id: props[:id],
       value: props[:value] || "",
       error: nil,
       focused: false,
       dirty: false
     }
   end

   @impl true
   def mount(state) do
     # Setup resources
     {state, []}
   end

   @impl true
   def update({:set_value, value}, state) do
     {put_in(state, [:value], value), []}
   end

   @impl true
   def render(state) do
     %{
       type: :text_input,
       id: state.id,
       value: state.value,
       error: state.error,
       focused: state.focused
     }
   end

   @impl true
   def handle_event(%{type: :change, value: value}, state) do
     {put_in(state, [:value], value), []}
   end

   @impl true
   def unmount(state) do
     # Cleanup resources
     state
   end

   # 5. Private functions
   defp validate_props(props) do
     with :ok <- validate_required(props, [:id]),
          :ok <- validate_types(props, @prop_types) do
       :ok
     end
   end
   ```

## Naming Conventions

1. **Module Names**

   - Use PascalCase for module names
   - Group related components in namespaces
   - Example: `Raxol.UI.Components.Input.TextInput`

2. **Function Names**

   - Use snake_case for function names
   - Use descriptive, action-oriented names
   - Example: `handle_text_change`, `validate_input`

3. **Variable Names**

   - Use snake_case for variables
   - Use descriptive names that indicate purpose
   - Example: `current_value`, `is_valid`

4. **Type Names**
   - Use snake_case for type names
   - Prefix with component name for clarity
   - Example: `text_input_props`, `text_input_state`

## Code Style

1. **Function Documentation**

   ```elixir
   @doc """
   Handles text input changes.

   ## Parameters
     * `event` - The input change event containing:
       * `:type` - Event type (`:change`, `:focus`, `:blur`)
       * `:value` - New input value
     * `state` - Current component state

   ## Returns
     * `{new_state, commands}` - Updated state and commands

   ## Examples
       iex> handle_event(%{type: :change, value: "new value"}, %{value: "old"})
       {%{value: "new value"}, []}
   """
   @impl true
   def handle_event(%{type: :change, value: value}, state) do
     {put_in(state, [:value], value), []}
   end
   ```

2. **Pattern Matching**

   ```elixir
   # Prefer pattern matching in function heads
   def handle_event(%{type: :click} = event, state) do
     # Handle click
   end

   def handle_event(%{type: :key} = event, state) do
     # Handle key
   end

   # Use guard clauses for type checking
   def update({:set_value, value}, state) when is_binary(value) do
     {put_in(state, [:value], value), []}
   end

   # Use with for complex validations
   def update({:set_value, value}, state) do
     with :ok <- validate_value(value),
          :ok <- check_length(value) do
       {put_in(state, [:value], value), []}
     else
       {:error, reason} -> {put_in(state, [:error], reason), []}
     end
   end
   ```

3. **State Updates**

   ```elixir
   # Use Map.update for atomic updates
   def update_state(state, key, value) do
     Map.update(state, key, value, &update_value/2)
   end

   # Use Map.put for simple updates
   def update_state(state, key, value) do
     Map.put(state, key, value)
   end

   # Use put_in for nested updates
   def update_nested_state(state, path, value) do
     put_in(state, path, value)
   end
   ```

## Component Design

1. **Props Design**

   ```elixir
   # Required props
   @required_props [:id, :value]

   # Optional props with defaults
   @default_props %{
     theme: @default_theme,
     disabled: false,
     placeholder: "",
     on_change: fn _ -> :ok end,
     on_submit: fn _ -> :ok end
   }

   # Props validation
   def validate_props(props) do
     with :ok <- validate_required(props, @required_props),
          :ok <- validate_types(props, @prop_types),
          :ok <- validate_callbacks(props) do
       :ok
     end
   end
   ```

2. **State Management**

   ```elixir
   # Keep state minimal
   def init(props) do
     %{
       id: props[:id],
       value: props[:value],
       error: nil,
       focused: false,
       dirty: false
     }
   end

   # Use immutable updates
   def update_state(state, key, value) do
     Map.put(state, key, value)
   end

   # Batch related updates
   def batch_update(state, updates) do
     Enum.reduce(updates, state, fn {key, value}, acc ->
       Map.put(acc, key, value)
     end)
   end
   ```

3. **Event Handling**

   ```elixir
   # Handle specific events
   def handle_event(%{type: :click} = event, state) do
     # Handle click
   end

   # Provide fallback handler
   def handle_event(_event, state) do
     {state, []}
   end

   # Handle errors gracefully
   def handle_event(event, state) do
     try do
       process_event(event, state)
     rescue
       error ->
         Raxol.Core.Runtime.Log.error("Event handling error: #{inspect(error)}")
         {put_in(state, [:error], "An error occurred"), []}
     end
   end
   ```

## Testing Style

1. **Test Organization**

   ```elixir
   defmodule Raxol.UI.Components.Input.TextInputTest do
     use ExUnit.Case, async: true
     import Raxol.ComponentTestHelpers

     describe "Component Lifecycle" do
       test "initializes with props" do
         component = create_test_component(TextInput, %{id: "test", value: "initial"})
         assert component.state.value == "initial"
       end

       test "mounts correctly" do
         component = create_test_component(TextInput, %{id: "test"})
         {mounted, _} = simulate_lifecycle(component, &(&1))
         assert mounted.state.mounted
       end
     end

     describe "Event Handling" do
       test "handles valid events" do
         component = create_test_component(TextInput, %{id: "test"})
         {updated, _} = simulate_event(component, %{type: :change, value: "new"})
         assert updated.state.value == "new"
       end

       test "handles invalid events" do
         component = create_test_component(TextInput, %{id: "test"})
         {updated, _} = simulate_event(component, %{type: :invalid})
         assert updated.state == component.state
       end
     end
   end
   ```

2. **Test Helpers**

   ```elixir
   # Use helper functions for common setup
   defp create_test_component(props \\ %{}) do
     # Create test component
   end

   # Use helper functions for assertions
   defp assert_component_mounted(component) do
     # Assert component is mounted
   end

   # Use helper functions for event simulation
   defp simulate_event(component, event) do
     # Simulate event
   end
   ```

## Documentation Style

1. **Module Documentation**

   ```elixir
   @moduledoc """
   A clear, concise description of the component.

   ## Features
   * Feature 1
   * Feature 2

   ## Props
   * `:prop1` - Description
   * `:prop2` - Description

   ## Examples
       MyComponent.new(id: "my-component")
   """
   ```

2. **Function Documentation**

   ```elixir
   @doc """
   Handles component events.

   ## Parameters
     * `event` - The event to handle
     * `state` - Current component state

   ## Returns
     * `{new_state, commands}` - Updated state and commands

   ## Examples
       handle_event(%{type: :click}, state)
   """
   ```

## Accessibility Guidelines

1. **Keyboard Navigation**

   ```elixir
   # Handle keyboard events
   def handle_event(%{type: :key} = event, state) do
     case event.data.key do
       :tab -> handle_tab_navigation(state)
       :enter -> handle_enter(state)
       :escape -> handle_escape(state)
       _ -> {state, []}
     end
   end
   ```

2. **Screen Reader Support**
   ```elixir
   # Provide ARIA attributes
   def render(state, context) do
     {state, %{
       type: :component,
       "aria-label": state.label,
       "aria-describedby": state.description_id,
       "aria-invalid": state.error != nil,
       "aria-disabled": state.disabled
     }}
   end
   ```

## Performance Guidelines

1. **State Updates**

   ```elixir
   # Batch related updates
   def update_multiple(state, updates) do
     Enum.reduce(updates, state, fn {key, value}, acc ->
       Map.put(acc, key, value)
     end)
   end

   # Use efficient data structures
   def init(props) do
     %{
       items: MapSet.new(props[:items] || []),
       # Use appropriate data structures
     }
   end
   ```

2. **Rendering**

   ```elixir
   # Cache expensive computations
   def render(state, context) do
     computed_value = compute_expensive_value(state)
     {state, %{
       type: :component,
       value: computed_value
     }}
   end

   # Use memoization
   def memoized_value(state) do
     # Cache and return value
   end
   ```

## Related Documentation

- [Component Architecture](./component_architecture.md)
- [Component Testing Guide](./testing.md)
- [Component Composition Patterns](./composition.md)
