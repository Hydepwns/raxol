# Component Deep Dive

---
id: component_deep_dive
title: Deep Dive into Raxol Components
difficulty: intermediate
estimated_time: 25
tags: [components, lifecycle, state, props]
prerequisites: [getting_started]
---

## Understanding Raxol's Component System

This tutorial provides an in-depth exploration of Raxol's component architecture, lifecycle, and best practices.

### Step 1: Component Lifecycle
---
step_id: component_lifecycle
title: Understanding Component Lifecycle
---

Raxol components follow a predictable lifecycle with hooks for initialization, updates, and cleanup.

#### Lifecycle Phases

1. **Initialization**: Component is created and mounted
2. **Rendering**: Component generates UI
3. **Updates**: State or props change trigger re-renders
4. **Cleanup**: Component is unmounted

#### Example Code

```elixir
defmodule LifecycleDemo do
  use Raxol.Component
  
  @impl true
  def init(props) do
    IO.puts("Component initializing with props: #{inspect(props)}")
    
    # Setup resources
    timer_ref = :timer.send_interval(1000, self(), :tick)
    
    {:ok, %{
      timer_ref: timer_ref,
      counter: 0,
      mounted_at: System.system_time(:second)
    }}
  end
  
  @impl true
  def update(state, prev_props, new_props) do
    IO.puts("Props changed from #{inspect(prev_props)} to #{inspect(new_props)}")
    
    # Update state based on prop changes
    if new_props.reset && !prev_props.reset do
      {:ok, %{state | counter: 0}}
    else
      {:ok, state}
    end
  end
  
  @impl true
  def render(state, props) do
    uptime = System.system_time(:second) - state.mounted_at
    
    Raxol.UI.box(title: props.title || "Lifecycle Demo") do
      Raxol.UI.text("Counter: #{state.counter}")
      Raxol.UI.text("Uptime: #{uptime}s")
      Raxol.UI.text("Props: #{inspect(props)}")
    end
  end
  
  @impl true
  def handle_info(:tick, state) do
    {:ok, %{state | counter: state.counter + 1}}
  end
  
  @impl true
  def terminate(_reason, state) do
    IO.puts("Component terminating")
    :timer.cancel(state.timer_ref)
    :ok
  end
end
```

#### Exercise

Create a component that tracks its own lifecycle events and displays them in a log.

#### Hints
- Store lifecycle events in state as a list
- Add timestamps to each event
- Display events in reverse chronological order

### Step 2: State Management Patterns
---
step_id: state_management
title: State Management Patterns
---

Learn different patterns for managing component state effectively.

#### Local State vs. Shared State

- **Local State**: Component-specific data
- **Shared State**: Data shared between components
- **Derived State**: Computed from props or other state

#### Example Code

```elixir
defmodule StatePatterns do
  use Raxol.Component
  
  # Define state structure
  defstruct [
    :local_value,
    :computed_value,
    :history,
    :undo_stack,
    :redo_stack
  ]
  
  def init(props) do
    initial_state = %__MODULE__{
      local_value: props.initial_value || "",
      computed_value: nil,
      history: [],
      undo_stack: [],
      redo_stack: []
    }
    
    {:ok, compute_derived_state(initial_state)}
  end
  
  def render(state, props) do
    Raxol.UI.box do
      # Local state input
      Raxol.UI.text_input(
        value: state.local_value,
        on_change: {:update_value, :value}
      )
      
      # Computed state display
      Raxol.UI.text("Computed: #{state.computed_value}")
      
      # History tracking
      Raxol.UI.text("History (#{length(state.history)} entries)")
      
      # Undo/Redo controls
      Raxol.UI.flex(direction: :horizontal) do
        Raxol.UI.button(
          "Undo",
          on_click: :undo,
          disabled: Enum.empty?(state.undo_stack)
        )
        Raxol.UI.button(
          "Redo", 
          on_click: :redo,
          disabled: Enum.empty?(state.redo_stack)
        )
      end
      
      # Shared state from parent
      if props.shared_data do
        Raxol.UI.text("Shared: #{props.shared_data}")
      end
    end
  end
  
  def handle_event({:update_value, value}, state) do
    # Save current state to undo stack
    new_undo = [state.local_value | state.undo_stack]
    
    new_state = %{state | 
      local_value: value,
      history: [value | Enum.take(state.history, 9)],
      undo_stack: new_undo,
      redo_stack: []  # Clear redo on new change
    }
    
    {:ok, compute_derived_state(new_state)}
  end
  
  def handle_event(:undo, state) do
    case state.undo_stack do
      [] -> {:ok, state}
      [prev | rest] ->
        new_state = %{state |
          local_value: prev,
          undo_stack: rest,
          redo_stack: [state.local_value | state.redo_stack]
        }
        {:ok, compute_derived_state(new_state)}
    end
  end
  
  def handle_event(:redo, state) do
    case state.redo_stack do
      [] -> {:ok, state}
      [next | rest] ->
        new_state = %{state |
          local_value: next,
          undo_stack: [state.local_value | state.undo_stack],
          redo_stack: rest
        }
        {:ok, compute_derived_state(new_state)}
    end
  end
  
  defp compute_derived_state(state) do
    # Compute derived values
    computed = String.upcase(state.local_value)
    %{state | computed_value: computed}
  end
end
```

#### Exercise

Implement a form component with validation that maintains error state and history.

#### Hints
- Validate on change and on submit
- Store errors in state
- Keep history of valid submissions

### Step 3: Component Composition
---
step_id: component_composition
title: Component Composition
---

Learn how to build complex UIs by composing smaller components.

#### Composition Patterns

- **Container/Presentational**: Separate logic from presentation
- **Higher-Order Components**: Enhance components with additional functionality
- **Render Props**: Share code between components using a prop

#### Example Code

```elixir
# Presentational component
defmodule UserCard do
  use Raxol.Component
  
  def init(_props), do: {:ok, %{}}
  
  def render(_state, props) do
    Raxol.UI.box(border: :single, padding: 1) do
      Raxol.UI.text(props.user.name, style: [bold: true])
      Raxol.UI.text(props.user.email, style: [color: :gray])
      
      if props.on_click do
        Raxol.UI.button("Select", on_click: props.on_click)
      end
    end
  end
end

# Container component
defmodule UserList do
  use Raxol.Component
  
  def init(_props) do
    {:ok, %{
      users: [],
      selected_user: nil,
      loading: true
    }}
  end
  
  def mount(state) do
    # Fetch users on mount
    send(self(), :load_users)
    {:ok, state}
  end
  
  def render(state, _props) do
    Raxol.UI.box do
      Raxol.UI.heading("Users")
      
      cond do
        state.loading ->
          Raxol.UI.spinner(text: "Loading users...")
          
        Enum.empty?(state.users) ->
          Raxol.UI.text("No users found", style: [color: :gray])
          
        true ->
          Raxol.UI.scroll_view do
            for user <- state.users do
              UserCard.render(%{}, %{
                user: user,
                on_click: {:select_user, user.id}
              })
            end
          end
      end
      
      if state.selected_user do
        Raxol.UI.box(title: "Selected User") do
          Raxol.UI.text("ID: #{state.selected_user.id}")
          Raxol.UI.text("Name: #{state.selected_user.name}")
        end
      end
    end
  end
  
  def handle_info(:load_users, state) do
    # Simulate API call
    Process.send_after(self(), {:users_loaded, fetch_users()}, 1000)
    {:ok, state}
  end
  
  def handle_info({:users_loaded, users}, state) do
    {:ok, %{state | users: users, loading: false}}
  end
  
  def handle_event({:select_user, user_id}, state) do
    user = Enum.find(state.users, &(&1.id == user_id))
    {:ok, %{state | selected_user: user}}
  end
  
  defp fetch_users do
    [
      %{id: 1, name: "Alice", email: "alice@example.com"},
      %{id: 2, name: "Bob", email: "bob@example.com"},
      %{id: 3, name: "Charlie", email: "charlie@example.com"}
    ]
  end
end

# Higher-Order Component for adding loading state
defmodule WithLoading do
  defmacro __using__(opts) do
    quote do
      use Raxol.Component
      
      def render_with_loading(state, props, render_fn) do
        if state.loading do
          Raxol.UI.box do
            Raxol.UI.spinner(text: unquote(opts[:message] || "Loading..."))
          end
        else
          render_fn.(state, props)
        end
      end
    end
  end
end
```

#### Exercise

Create a reusable data table component that supports sorting, filtering, and pagination.

#### Hints
- Separate table logic from presentation
- Use composition for column definitions
- Make sorting and filtering pluggable

### Step 4: Performance Optimization
---
step_id: performance_optimization
title: Performance Optimization
---

Learn techniques to optimize component rendering and state updates.

#### Optimization Techniques

- **Memoization**: Cache computed values
- **Virtual Rendering**: Render only visible items
- **Batch Updates**: Group state changes
- **Lazy Loading**: Load components on demand

#### Example Code

```elixir
defmodule OptimizedList do
  use Raxol.Component
  
  @viewport_size 20
  
  def init(props) do
    {:ok, %{
      items: props.items || [],
      filtered_items: nil,
      filter: "",
      scroll_offset: 0,
      memo_cache: %{}
    }}
  end
  
  def render(state, _props) do
    # Use memoized filtered items
    items = get_filtered_items(state)
    
    # Virtual scrolling - only render visible items
    visible_items = get_visible_items(items, state.scroll_offset)
    
    Raxol.UI.box do
      # Filter input
      Raxol.UI.text_input(
        value: state.filter,
        placeholder: "Filter items...",
        on_change: {:update_filter, :value}
      )
      
      # Item count
      Raxol.UI.text("Showing #{length(visible_items)} of #{length(items)} items")
      
      # Virtual list
      Raxol.UI.virtual_list(
        height: @viewport_size,
        item_count: length(items),
        scroll_offset: state.scroll_offset,
        on_scroll: {:update_scroll, :offset}
      ) do
        for item <- visible_items do
          render_item(item, state)
        end
      end
    end
  end
  
  # Memoized filtering
  defp get_filtered_items(state) do
    cache_key = {state.filter, hash(state.items)}
    
    case Map.get(state.memo_cache, cache_key) do
      nil ->
        filtered = filter_items(state.items, state.filter)
        # Store in cache (would need to update state properly)
        filtered
        
      cached ->
        cached
    end
  end
  
  defp filter_items(items, "") do
    items
  end
  
  defp filter_items(items, filter) do
    pattern = String.downcase(filter)
    
    Enum.filter(items, fn item ->
      String.contains?(
        String.downcase(item.text),
        pattern
      )
    end)
  end
  
  # Virtual scrolling
  defp get_visible_items(items, offset) do
    items
    |> Enum.drop(offset)
    |> Enum.take(@viewport_size)
  end
  
  # Optimized item rendering with keys
  defp render_item(item, _state) do
    Raxol.UI.box(key: item.id, padding: 0) do
      Raxol.UI.text(item.text)
    end
  end
  
  # Batch state updates
  def handle_event({:update_filter, value}, state) do
    # Debounce filter updates
    Process.cancel_timer(state[:filter_timer])
    timer = Process.send_after(self(), {:apply_filter, value}, 300)
    
    {:ok, %{state | filter: value, filter_timer: timer}}
  end
  
  def handle_info({:apply_filter, value}, state) do
    # Apply filter after debounce
    filtered = filter_items(state.items, value)
    
    new_cache = Map.put(
      state.memo_cache,
      {value, hash(state.items)},
      filtered
    )
    
    {:ok, %{state | 
      filtered_items: filtered,
      memo_cache: new_cache,
      scroll_offset: 0
    }}
  end
  
  defp hash(items) do
    :erlang.phash2(items)
  end
end
```

#### Exercise

Build a virtualized grid component that efficiently renders thousands of cells.

#### Hints
- Calculate visible viewport based on scroll position
- Use cell recycling for better performance
- Implement smooth scrolling with momentum

### Step 5: Custom Hooks
---
step_id: custom_hooks
title: Creating Custom Hooks
---

Learn how to create reusable logic with custom hooks.

#### Custom Hook Patterns

- **State Hooks**: Reusable state logic
- **Effect Hooks**: Side effects management
- **Ref Hooks**: DOM/Terminal references
- **Context Hooks**: Shared context access

#### Example Code

```elixir
defmodule Hooks do
  @moduledoc """
  Collection of reusable hooks for Raxol components.
  """
  
  # useLocalStorage hook
  defmodule UseLocalStorage do
    def init(key, default_value) do
      stored = read_storage(key)
      value = stored || default_value
      
      %{
        value: value,
        key: key,
        set_value: fn new_value ->
          write_storage(key, new_value)
          new_value
        end
      }
    end
    
    defp read_storage(key) do
      case File.read(".raxol_storage/#{key}") do
        {:ok, content} -> :erlang.binary_to_term(content)
        _ -> nil
      end
    end
    
    defp write_storage(key, value) do
      File.mkdir_p!(".raxol_storage")
      File.write!(".raxol_storage/#{key}", :erlang.term_to_binary(value))
    end
  end
  
  # useDebounce hook
  defmodule UseDebounce do
    def init(value, delay) do
      %{
        value: value,
        debounced_value: value,
        delay: delay,
        timer: nil
      }
    end
    
    def update(state, new_value) do
      if state.timer do
        Process.cancel_timer(state.timer)
      end
      
      timer = Process.send_after(self(), {:debounce_complete, new_value}, state.delay)
      
      %{state | value: new_value, timer: timer}
    end
    
    def handle_info({:debounce_complete, value}, state) do
      %{state | debounced_value: value, timer: nil}
    end
  end
  
  # useKeyboard hook
  defmodule UseKeyboard do
    def init(key_map) do
      %{
        key_map: key_map,
        pressed_keys: MapSet.new()
      }
    end
    
    def handle_key_down(state, key) do
      new_pressed = MapSet.put(state.pressed_keys, key)
      
      # Check for key combinations
      action = find_matching_action(new_pressed, state.key_map)
      
      {%{state | pressed_keys: new_pressed}, action}
    end
    
    def handle_key_up(state, key) do
      new_pressed = MapSet.delete(state.pressed_keys, key)
      {%{state | pressed_keys: new_pressed}, nil}
    end
    
    defp find_matching_action(pressed_keys, key_map) do
      Enum.find_value(key_map, fn {keys, action} ->
        if MapSet.subset?(MapSet.new(keys), pressed_keys) do
          action
        end
      end)
    end
  end
end

# Component using custom hooks
defmodule ComponentWithHooks do
  use Raxol.Component
  
  def init(_props) do
    storage = Hooks.UseLocalStorage.init("user_prefs", %{theme: "dark"})
    debounce = Hooks.UseDebounce.init("", 500)
    keyboard = Hooks.UseKeyboard.init(%{
      [:ctrl, :s] => :save,
      [:ctrl, :z] => :undo,
      [:ctrl, :shift, :z] => :redo
    })
    
    {:ok, %{
      storage: storage,
      debounce: debounce,
      keyboard: keyboard,
      content: ""
    }}
  end
  
  def render(state, _props) do
    Raxol.UI.box do
      Raxol.UI.text("Theme: #{state.storage.value.theme}")
      
      Raxol.UI.text_input(
        value: state.debounce.value,
        on_change: {:update_search, :value}
      )
      
      Raxol.UI.text("Debounced: #{state.debounce.debounced_value}")
      
      Raxol.UI.text_area(
        value: state.content,
        on_key_down: {:handle_shortcut, :key}
      )
    end
  end
  
  def handle_event({:update_search, value}, state) do
    new_debounce = Hooks.UseDebounce.update(state.debounce, value)
    {:ok, %{state | debounce: new_debounce}}
  end
  
  def handle_event({:handle_shortcut, key}, state) do
    {new_keyboard, action} = Hooks.UseKeyboard.handle_key_down(state.keyboard, key)
    
    state = %{state | keyboard: new_keyboard}
    
    case action do
      :save -> save_content(state)
      :undo -> undo_change(state)
      :redo -> redo_change(state)
      _ -> {:ok, state}
    end
  end
  
  defp save_content(state) do
    # Save logic
    {:ok, state}
  end
  
  defp undo_change(state) do
    # Undo logic
    {:ok, state}
  end
  
  defp redo_change(state) do
    # Redo logic
    {:ok, state}
  end
end
```

#### Exercise

Create a custom hook for managing form state with validation.

#### Hints
- Track field values and errors
- Validate on change or on submit
- Provide helper functions for common operations

### Congratulations!

You've mastered Raxol's component system! You now understand:

- ✓ Component lifecycle and hooks
- ✓ State management patterns
- ✓ Component composition
- ✓ Performance optimization
- ✓ Custom hooks

## Next Steps

- Explore [Terminal Emulation](03_terminal_emulation.md)
- Learn about [Advanced Input Handling](advanced_input.md)
- Build [Production Applications](production_apps.md)