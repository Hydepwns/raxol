# Raxol Component Style Guide

## Component Structure

### Module Organization

1. **Module Documentation**

   ```elixir
   defmodule MyComponent do
     @moduledoc """
     A clear, concise description of the component's purpose and functionality.

     ## Features
     * Feature 1
     * Feature 2
     * Feature 3

     ## Props
     * `:prop1` - Description of prop1
     * `:prop2` - Description of prop2
     """
   ```

2. **Type Specifications**

   ```elixir
   @type props :: %{
     required(:id) => String.t(),
     optional(:theme) => map()
   }

   @type state :: %{
     id: String.t(),
     theme: map()
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
   @default_width 100
   @default_theme %{...}

   # 4. Callbacks
   @impl true
   def init(props) do ... end

   @impl true
   def mount(state) do ... end

   @impl true
   def update(message, state) do ... end

   @impl true
   def render(state, context) do ... end

   @impl true
   def handle_event(event, state) do ... end

   @impl true
   def unmount(state) do ... end

   # 5. Private functions
   defp helper_function(...) do ... end
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
     * `event` - The input change event
     * `state` - Current component state

   ## Returns
     * `{new_state, commands}` - Updated state and commands
   """
   @impl true
   def handle_event(%{type: :text_change} = event, state) do
     # Implementation
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
   def update({:set_value, value}, state) when is_number(value) do
     # Handle numeric value
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
   ```

## Component Design

1. **Props Design**

   ```elixir
   # Required props
   @required_props [:id, :value]

   # Optional props with defaults
   @default_props %{
     theme: %{},
     disabled: false
   }

   # Props validation
   def validate_props(props) do
     with :ok <- validate_required(props, @required_props),
          :ok <- validate_types(props, @prop_types) do
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
       # Only include necessary state
     }
   end

   # Use immutable updates
   def update_state(state, key, value) do
     Map.put(state, key, value)
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
   ```

## Testing Style

1. **Test Organization**

   ```elixir
   describe "Component Lifecycle" do
     test "initializes with props" do
       # Test initialization
     end

     test "mounts correctly" do
       # Test mounting
     end
   end

   describe "Event Handling" do
     test "handles valid events" do
       # Test event handling
     end

     test "handles invalid events" do
       # Test error cases
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

## Error Handling

1. **Input Validation**

   ```elixir
   # Validate props
   def validate_props(props) do
     with :ok <- validate_required(props, @required_props),
          :ok <- validate_types(props, @prop_types) do
       :ok
     end
   end

   # Handle validation errors
   def handle_validation_error(error) do
     Raxol.Core.Runtime.Log.error("Validation error: #{inspect(error)}")
     {:error, error}
   end
   ```

2. **Error Recovery**

   ```elixir
   # Provide fallback UI
   def render_error(state, error) do
     {state, %{
       type: :error,
       message: error.message
     }}
   end

   # Handle component errors
   def handle_component_error(error) do
     Raxol.Core.Runtime.Log.error("Component error: #{inspect(error)}")
     {:error, error}
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

## Accessibility Guidelines

1. **Keyboard Navigation**

   ```elixir
   # Handle keyboard events
   def handle_event(%{type: :key} = event, state) do
     case event.data.key do
       :tab -> handle_tab_navigation(state)
       :enter -> handle_enter(state)
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
       "aria-describedby": state.description_id
     }}
   end
   ```

## Component Composition

1. **Parent-Child Relationships**

   ```elixir
   # Handle child events
   def handle_event(%{type: :child_event} = event, state) do
     # Handle child event
     {new_state, commands}
   end

   # Update child state
   def update_child(child_id, new_state, state) do
     # Update child state
     {new_state, []}
   end
   ```

2. **Component Communication**

   ```elixir
   # Broadcast events
   def broadcast_event(event, state) do
     # Broadcast event to children
     {state, [{:broadcast, event}]}
   end

   # Handle broadcast events
   def handle_event(%{type: :broadcast} = event, state) do
     # Handle broadcast event
     {new_state, []}
   end
   ```
