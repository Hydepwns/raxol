# Raxol Component Architecture

> See also: [Component API Reference](docs/components/api/component_api_reference.md) for callback signatures and types.

## Overview

Raxol's component system provides a robust, hierarchical UI framework with clear communication patterns and lifecycle management. Components are reusable, stateful modules that implement a standard behaviour and support a clear lifecycle:

- `init/1` — Initialize state from props
- `mount/1` — Set up resources after mounting
- `update/2` — Update state in response to messages
- `render/1` — Produce the component's view
- `handle_event/2` — Handle user/system events
- `unmount/1` — Clean up resources

## Component Structure

Every component in Raxol must implement the `Raxol.UI.Components.Base.Component` behaviour, which requires the above callbacks. Components are composed using the `Raxol.View.Elements` DSL, supporting hierarchical parent-child relationships and explicit event propagation.

## Component Hierarchy

### Parent-Child Relationships

- **Parent Components:**
  - Manage child components and track their state
  - Handle child events and coordinate updates
- **Child Components:**
  - Communicate state changes up via events/commands
  - Receive updates from parent

Events propagate up and down the component tree, enabling rich interactivity and predictable state management.

## Component Lifecycle

- **Mounting:**
  1. Parent components mount first
  2. Children mount in order
  3. Each component's `mount/1` callback is called
  4. State initialization occurs
- **Unmounting:**
  1. Children unmount first
  2. Parent unmounts last
  3. Each component's `unmount/1` callback is called
  4. Cleanup occurs in reverse order

## Best Practices

- Keep state minimal and focused
- Use immutable updates
- Track child states in parent
- Use typed events and proper error handling
- Minimize state updates and use efficient data structures
- Test components in isolation using provided helpers

## Testing

Components should be tested for:

- Unit behavior and state management
- Parent-child relationships and event propagation
- Lifecycle (mounting/unmounting, state persistence, error recovery)

## Communication Patterns

### Event Propagation

1. **Upward Communication**

   - Children notify parents through commands
   - Parents receive updates via `update/2` callback
   - State changes are tracked in parent's `child_states`

2. **Downward Communication**
   - Parents send events to children
   - Children receive updates via `update/2` callback
   - State synchronization is maintained

### Broadcast Events

Components can broadcast events to multiple children:

```elixir
# Parent broadcasting to children
def handle_event(%{type: :broadcast, value: value}, state) do
  commands = Enum.map(state.children, fn child_id ->
    {:command, {:child_event, child_id, value}}
  end)
  {state, commands}
end
```

## Error Handling

### Graceful Error Recovery

1. **Child Errors**

   - Parent components remain stable
   - Child state is preserved
   - Error events are logged

2. **Parent Errors**
   - Children remain stable
   - Parent state is preserved
   - Error events are logged

## Testing

Components should be tested for:

1. **Unit Tests**

   - Individual component behavior
   - State management
   - Event handling

2. **Integration Tests**

   - Parent-child relationships
   - Event propagation
   - State synchronization

3. **Lifecycle Tests**
   - Mounting/unmounting
   - State persistence
   - Error recovery

Example test structure:

```elixir
describe "Component Integration" do
  test "parent-child relationship" do
    # Set up components
    parent = create_test_component(ParentComponent)
    child = create_test_component(ChildComponent, %{parent_id: parent.state.id})

    # Set up hierarchy
    {parent, child} = setup_component_hierarchy(ParentComponent, ChildComponent)

    # Verify hierarchy
    assert_hierarchy_valid(parent, [child])
  end
end
```
