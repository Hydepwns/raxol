defmodule Raxol.Component do
  @moduledoc """
  Foundation for building reusable, stateful terminal UI components.

  This module provides a React-like component system for terminal applications,
  with lifecycle hooks, state management, and event handling. Components are
  the building blocks of Raxol applications.

  ## Core Concepts

  * **Props** - Immutable configuration passed from parent
  * **State** - Mutable component-local data
  * **Events** - Keyboard, mouse, and custom events
  * **Lifecycle** - Mount, update, unmount hooks
  * **Composition** - Components can contain other components

  ## Quick Start

      defmodule Counter do
        use Raxol.Component
        
        @impl true
        def init(props) do
          %{
            count: props[:initial] || 0,
            step: props[:step] || 1
          }
        end
        
        @impl true
        def render(state, props) do
          \"\"\"
          Count: \#{state.count}
          Step: \#{state.step}
          [+] Increment  [-] Decrement  [r] Reset
          \"\"\"
        end
        
        @impl true
        def handle_event(:key_press, "+", state) do
          {:ok, %{state | count: state.count + state.step}}
        end
        
        @impl true
        def handle_event(:key_press, "-", state) do
          {:ok, %{state | count: state.count - state.step}}
        end
        
        @impl true
        def handle_event(:key_press, "r", state) do
          {:ok, %{state | count: 0}}
        end
        
        @impl true
        def handle_event(_, _, state), do: {:ok, state}
      end

  ## Component Callbacks

  ### Required Callbacks

  * `init/1` - Initialize component state from props
    ```elixir
    @callback init(props :: map()) :: state :: map()
    ```

  * `render/2` - Render the component's visual representation
    ```elixir
    @callback render(state :: map(), props :: map()) :: String.t() | term()
    ```

  ### Optional Callbacks

  * `handle_event/3` - Process keyboard, mouse, and custom events
    ```elixir
    @callback handle_event(event_type :: atom(), event_data :: term(), state :: map()) ::
      {:ok, new_state :: map()} | {:error, reason :: term()}
    ```

  * `update/2` - Called when parent provides new props
    ```elixir
    @callback update(state :: map(), new_props :: map()) :: {:ok, new_state :: map()}
    ```

  * `mount/1` - Called when component is added to UI tree
    ```elixir
    @callback mount(state :: map()) :: {:ok, new_state :: map()}
    ```

  * `unmount/1` - Called when component is removed from UI tree
    ```elixir
    @callback unmount(state :: map()) :: :ok
    ```

  * `cleanup/1` - Final cleanup when component process terminates
    ```elixir
    @callback cleanup(state :: map()) :: :ok
    ```

  ## Real-World Example: Interactive Todo List

      defmodule TodoList do
        use Raxol.Component
        
        @impl true
        def init(props) do
          %{
            todos: props[:todos] || [],
            selected: 0,
            filter: :all,
            editing: nil
          }
        end
        
        @impl true
        def render(state, _props) do
          filtered = filter_todos(state.todos, state.filter)
          
          \"\"\"
          ╭─ Todo List (\#{length(filtered)}/\#{length(state.todos)}) ─╮
          \#{render_todos(filtered, state.selected, state.editing)}
          ╰─────────────────────────────────╯
          [j/k] Navigate  [x] Toggle  [e] Edit  [d] Delete  [n] New
          [a] All  [c] Complete  [p] Pending
          \"\"\"
        end
        
        @impl true
        def handle_event(:key_press, "j", state) do
          max_index = length(filter_todos(state.todos, state.filter)) - 1
          {:ok, %{state | selected: min(state.selected + 1, max_index)}}
        end
        
        @impl true
        def handle_event(:key_press, "k", state) do
          {:ok, %{state | selected: max(state.selected - 1, 0)}}
        end
        
        @impl true
        def handle_event(:key_press, "x", state) do
          todos = toggle_todo(state.todos, state.selected)
          {:ok, %{state | todos: todos}}
        end
        
        @impl true
        def handle_event(:key_press, "d", state) do
          todos = delete_todo(state.todos, state.selected)
          {:ok, %{state | todos: todos, selected: min(state.selected, length(todos) - 1)}}
        end
        
        @impl true
        def handle_event(:key_press, "n", state) do
          # Start creating new todo
          {:ok, %{state | editing: :new}}
        end
        
        @impl true
        def handle_event(:key_press, key, state) when key in ["a", "c", "p"] do
          filter = %{"a" => :all, "c" => :complete, "p" => :pending}[key]
          {:ok, %{state | filter: filter, selected: 0}}
        end
        
        @impl true
        def handle_event(_, _, state), do: {:ok, state}
        
        # Helper functions
        defp filter_todos(todos, :all), do: todos
        defp filter_todos(todos, :complete), do: Enum.filter(todos, & &1.complete)
        defp filter_todos(todos, :pending), do: Enum.reject(todos, & &1.complete)
        
        defp render_todos(todos, selected, editing) do
          todos
          |> Enum.with_index()
          |> Enum.map(fn {todo, idx} ->
            cursor = if idx == selected, do: ">", else: " "
            check = if todo.complete, do: "[x]", else: "[ ]"
            text = if editing == idx, do: "[editing...]", else: todo.text
            "\#{cursor} \#{check} \#{text}"
          end)
          |> Enum.join("\n")
        end
      end

  ## Component Composition

  Components can contain and manage other components, enabling complex UIs:

      defmodule Dashboard do
        use Raxol.Component
        
        @impl true
        def init(_props) do
          %{
            stats: create_child(StatsPanel, refresh_rate: 1000),
            logs: create_child(LogViewer, max_lines: 100),
            menu: create_child(MenuBar, items: menu_items()),
            active_panel: :stats
          }
        end
        
        @impl true
        def render(state, _props) do
          \"\"\"
          \#{render_child(state.menu)}
          ╭──────────────────────────────────╮
          │ \#{render_active_panel(state)}   │
          ╰──────────────────────────────────╯
          [Tab] Switch Panel  [q] Quit
          \"\"\"
        end
        
        @impl true
        def handle_event(:key_press, "\t", state) do
          next_panel = toggle_panel(state.active_panel)
          {:ok, %{state | active_panel: next_panel}}
        end
        
        defp render_active_panel(%{active_panel: :stats} = state) do
          render_child(state.stats)
        end
        
        defp render_active_panel(%{active_panel: :logs} = state) do
          render_child(state.logs)
        end
      end

  ## Performance Tips

  1. **Minimize State Updates** - Only update what changed
  2. **Use Immutable Data** - Leverage Elixir's immutable structures
  3. **Batch Updates** - Group related state changes
  4. **Lazy Rendering** - Only render visible content
  5. **Memoization** - Cache expensive computations

  ## Testing Components

      defmodule CounterTest do
        use ExUnit.Case
        
        test "increments count on + key" do
          # Initialize component
          state = Counter.init(initial: 5)
          assert state.count == 5
          
          # Simulate key press
          {:ok, new_state} = Counter.handle_event(:key_press, "+", state)
          assert new_state.count == 6
          
          # Verify render output
          output = Counter.render(new_state, %{})
          assert output =~ "Count: 6"
        end
      end

  ## See Also

  * `Raxol.UI.Components.Base.Component` - Full component API
  * `Raxol.UI.State` - State management patterns
  * `Raxol.Events` - Event system documentation
  """

  defmacro __using__(opts) do
    quote do
      use Raxol.UI.Components.Base.Component, unquote(opts)
    end
  end
end
