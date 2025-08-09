# ADR-0001: Component-Based Architecture

## Status
Accepted

## Context
When building terminal applications, developers traditionally work with low-level primitives like cursor movements, ANSI escape codes, and character-by-character rendering. This approach is error-prone, difficult to maintain, and doesn't scale well for complex UIs.

Modern web development has proven that component-based architectures provide better developer experience, maintainability, and reusability. Frameworks like React and Vue have shown that declarative UI programming is more productive than imperative approaches.

## Decision
We will implement a component-based architecture for Raxol that mirrors modern web frameworks, specifically inspired by React and Phoenix LiveView.

Key architectural decisions:
1. **Declarative Components**: Define UI as a function of state
2. **Virtual Terminal**: Maintain a virtual representation before rendering
3. **Lifecycle Hooks**: mount, update, render, unmount
4. **Props and State**: Clear separation between component inputs and internal state
5. **Event System**: Unified event handling for keyboard, mouse, and custom events

## Implementation

### Component Structure
```elixir
defmodule MyComponent do
  use Raxol.Component
  
  prop :title, :string, required: true
  prop :items, {:list, :map}, default: []
  
  @impl true
  def mount(socket) do
    {:ok, assign(socket, selected: nil)}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Box>
      <Heading><%= @title %></Heading>
      <List items={@items} />
    </Box>
    """
  end
end
```

### Virtual Terminal Benefits
- **Efficient Rendering**: Only re-render changed portions
- **Testing**: Test components without actual terminal
- **Platform Independence**: Same code works in terminal and web

## Consequences

### Positive
- **Developer Productivity**: Familiar component model for web developers
- **Code Reusability**: Components can be shared and published
- **Maintainability**: Clear separation of concerns
- **Testing**: Components are easily unit testable
- **Documentation**: Self-documenting component APIs

### Negative
- **Learning Curve**: Developers need to learn the component model
- **Performance Overhead**: Virtual terminal adds a layer of abstraction
- **Memory Usage**: Maintaining virtual state requires additional memory

### Mitigation Strategies
- **Performance**: Implemented EmulatorLite for bypassing GenServer overhead
- **Memory**: Implemented efficient diff algorithms and buffer pooling
- **Learning**: Comprehensive documentation and examples

## Metrics
- Component render time: < 1ms for typical components
- Memory per component: < 1KB for simple components
- Developer onboarding: Target 5 minutes to first component

## References
- React Component Model: https://react.dev/learn/thinking-in-react
- Phoenix LiveView: https://hexdocs.pm/phoenix_live_view
- Elm Architecture: https://guide.elm-lang.org/architecture/