defmodule Raxol.Component do
  @moduledoc """
  Base module for creating reusable terminal UI components.

  This module provides a convenient interface for building stateful, interactive
  terminal UI components. It's an alias for `Raxol.UI.Components.Base.Component`
  with a simpler API for common use cases.

  ## Quick Start

      defmodule Counter do
        use Raxol.Component
        
        def init(_props) do
          %{count: 0}
        end
        
        def render(state, _props) do
          \"\"\"
          Count: \#{state.count}
          Press + to increment, - to decrement
          \"\"\"
        end
        
        def handle_event(:key_press, "+", state) do
          {:ok, %{state | count: state.count + 1}}
        end
        
        def handle_event(:key_press, "-", state) do
          {:ok, %{state | count: state.count - 1}}
        end
        
        def handle_event(_, _, state), do: {:ok, state}
      end

  ## Component Callbacks

  When you `use Raxol.Component`, you can implement these callbacks:

  * `init/1` - Initialize component state (required)
  * `render/2` - Render the component UI (required)
  * `handle_event/3` - Handle keyboard/mouse events (optional)
  * `update/2` - Update state based on new props (optional)
  * `cleanup/1` - Clean up resources on unmount (optional)

  ## Advanced Example with Props

      defmodule TodoList do
        use Raxol.Component
        
        def init(props) do
          %{
            todos: props[:todos] || [],
            selected: 0,
            filter: :all
          }
        end
        
        def render(state, _props) do
          todos = filter_todos(state.todos, state.filter)
          
          \"\"\"
          Todo List (\#{length(todos)} items)
          \#{"─" |> String.duplicate(30)}
          \#{render_todos(todos, state.selected)}
          \#{"─" |> String.duplicate(30)}
          [a]ll | [c]omplete | [p]ending
          \"\"\"
        end
        
        def handle_event(:key_press, "j", state) do
          {:ok, %{state | selected: min(state.selected + 1, length(state.todos) - 1)}}
        end
        
        def handle_event(:key_press, "k", state) do
          {:ok, %{state | selected: max(state.selected - 1, 0)}}
        end
        
        def handle_event(:key_press, key, state) when key in ["a", "c", "p"] do
          filter = case key do
            "a" -> :all
            "c" -> :complete
            "p" -> :pending
          end
          {:ok, %{state | filter: filter}}
        end
        
        def handle_event(_, _, state), do: {:ok, state}
      end

  ## Component Composition

      defmodule App do
        use Raxol.Component
        
        def init(_props) do
          %{
            header: create_child(Header, title: "My App"),
            content: create_child(Content, []),
            footer: create_child(Footer, [])
          }
        end
        
        def render(state, _props) do
          \"\"\"
          \#{render_child(state.header)}
          \#{render_child(state.content)}
          \#{render_child(state.footer)}
          \"\"\"
        end
      end

  See `Raxol.UI.Components.Base.Component` for the full API documentation.
  """

  defmacro __using__(opts) do
    quote do
      use Raxol.UI.Components.Base.Component, unquote(opts)
    end
  end
end
