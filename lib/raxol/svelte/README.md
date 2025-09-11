# Raxol Svelte-Style Components

This module provides Svelte-inspired patterns for Raxol, bringing compile-time optimization and reactive programming to terminal applications.

## Philosophy: Svelte in tmux

Raxol embraces Svelte's philosophy over React's:

- **Compile-time optimization** instead of runtime virtual DOM
- **Direct manipulation** of terminal buffers
- **Reactive declarations** that automatically update
- **Minimal runtime overhead**
- **Simple, declarative syntax**

## Key Features

### 1. Reactive Stores

Svelte-style stores with automatic dependency tracking:

```elixir
defmodule AppState do
  use Raxol.Svelte.Store
  
  # Writable stores
  store :count, 0
  store :name, "World"
  
  # Derived stores (automatically update when dependencies change)
  derive :doubled, fn %{count: c} -> c * 2 end
  derive :greeting, fn %{name: n} -> "Hello, #{n}!" end
end

# Usage
AppState.set(:count, 10)
AppState.update(:count, & &1 + 1)
value = AppState.get(:count)
AppState.subscribe(:count, fn value -> IO.puts("Count: #{value}") end)
```

### 2. Reactive Components

Components with automatic re-rendering when state changes:

```elixir
defmodule Counter do
  use Raxol.Svelte.Component, optimize: :compile_time
  use Raxol.Svelte.Reactive
  
  # Component state
  state :count, 0
  state :step, 1
  
  # Reactive computed values
  reactive :doubled do
    @count * 2
  end
  
  # Reactive statements (Svelte's $: syntax)
  reactive_block do
    reactive_stmt(is_even = rem(@count, 2) == 0)
    reactive_stmt(message = "Count is #{if is_even, do: "even", else: "odd"}")
    
    # Side effects
    reactive_stmt(if @count > 10 do
      IO.puts("Warning: High count!")
    end)
  end
  
  # Event handlers
  def increment do
    update_state(:count, & &1 + @step)
  end
  
  # Template (compiled at compile-time for performance)
  def render(assigns) do
    ~H"""
    <Box>
      <Text>Count: {@count}</Text>
      <Text>Doubled: {@doubled}</Text>
      <Text>{message}</Text>
      <Button on_click={&increment/0}>+{@step}</Button>
    </Box>
    """
  end
end
```

### 3. Reactive Declarations

Svelte's `$:` syntax for automatic re-execution:

```elixir
reactive_block do
  # These statements automatically re-run when dependencies change
  reactive_stmt(sum = @x + @y)
  reactive_stmt(product = @x * @y)
  reactive_stmt(description = "Sum: #{sum}, Product: #{product}")
  
  # Side effects
  reactive_stmt(if sum > 100 do
    IO.puts("Large sum detected!")
  end)
end
```

### 4. Compile-Time Optimization

Components can be compiled to direct buffer operations:

```elixir
defmodule OptimizedComponent do
  use Raxol.Svelte.Component, optimize: :compile_time
  
  def render(assigns) do
    # This template gets compiled to direct buffer operations
    # No virtual DOM, no runtime diffing
    ~H"""
    <Text x={10} y={5} color="green">{@message}</Text>
    """
  end
end
```

At compile time, this becomes something like:

```elixir
def render_optimized(assigns, buffer) do
  buffer
  |> move_cursor(10, 5)
  |> set_color(:green)
  |> write_text(assigns.message)
end
```

### 5. Two-Way Data Binding

Svelte-style binding with automatic updates:

```elixir
def render(assigns) do
  ~H"""
  <!-- Two-way binding -->
  <TextInput bind:value={@name} />
  <Text>Hello {@name}!</Text>
  
  <!-- Equivalent to: -->
  <TextInput 
    value={@name} 
    on_change={fn value -> set_state(:name, value) end}
  />
  """
end
```

## Performance Benefits

### Compile-Time Optimization

- Templates compiled to direct buffer operations
- No virtual DOM overhead
- No runtime diffing
- Minimal memory allocations

### Reactive Efficiency

- Only affected components re-render
- Dependency tracking prevents unnecessary updates
- Batch updates for multiple state changes
- Lazy evaluation of derived values

### Memory Usage

- No virtual DOM tree in memory
- Direct terminal buffer manipulation
- Efficient state management with GenServer
- Minimal runtime overhead

## Examples

### Simple Counter

```elixir
defmodule SimpleCounter do
  use Raxol.Svelte.Component
  
  state :count, 0
  
  def increment, do: update_state(:count, & &1 + 1)
  def decrement, do: update_state(:count, & &1 - 1)
  
  def render(assigns) do
    ~H"""
    <Box>
      <Text>Count: {@count}</Text>
      <Button on_click={&increment/0}>+</Button>
      <Button on_click={&decrement/0}>-</Button>
    </Box>
    """
  end
end
```

### Todo List with Derived State

```elixir
defmodule TodoList do
  use Raxol.Svelte.Component
  use Raxol.Svelte.Reactive
  
  state :todos, []
  state :filter, :all
  
  reactive :filtered_todos do
    case @filter do
      :all -> @todos
      :active -> Enum.filter(@todos, & !&1.completed)
      :completed -> Enum.filter(@todos, & &1.completed)
    end
  end
  
  reactive :stats do
    total = length(@todos)
    active = Enum.count(@todos, & !&1.completed)
    %{total: total, active: active, completed: total - active}
  end
  
  def render(assigns) do
    ~H"""
    <Box>
      <Text>Total: {@stats.total}, Active: {@stats.active}</Text>
      
      {#each @filtered_todos as todo}
        <TodoItem {todo} />
      {/each}
    </Box>
    """
  end
end
```

## Running the Demo

```bash
# Run the Svelte-style demo
mix run examples/svelte/svelte_demo.ex

# Try the counter example
iex -S mix
iex> terminal = Raxol.Terminal.new()
iex> counter = Examples.SvelteCounter.mount(terminal)
```

## Architecture Comparison

### Traditional React-style (Virtual DOM)

```
State Change → Virtual DOM → Diff → Real DOM Update
```

### Raxol Svelte-style (Direct Manipulation)

```
State Change → Reactive Update → Direct Buffer Write
```

This eliminates the virtual DOM layer entirely, resulting in:
- Faster updates
- Lower memory usage
- More predictable performance
- Simpler debugging

## Best Practices

1. **Use reactive declarations** for computed values instead of storing them in state
2. **Minimize side effects** in reactive blocks
3. **Batch state updates** when changing multiple values
4. **Use compile-time optimization** for performance-critical components
5. **Keep components small** and focused on single responsibilities

## Migration from React-style

If you have existing Raxol components, migration is straightforward:

```elixir
# Before (React-style)
defmodule OldComponent do
  use Raxol.Component
  
  def render(assigns) do
    count = assigns.count
    doubled = count * 2
    
    ~H"""
    <Text>Count: {count}, Doubled: {doubled}</Text>
    """
  end
end

# After (Svelte-style)
defmodule NewComponent do
  use Raxol.Svelte.Component
  
  state :count, 0
  
  reactive :doubled do
    @count * 2
  end
  
  def render(assigns) do
    ~H"""
    <Text>Count: {@count}, Doubled: {@doubled}</Text>
    """
  end
end
```

The Svelte-style version automatically updates when `count` changes, and `doubled` is always in sync.