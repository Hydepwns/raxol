defmodule Raxol.Component do
  @moduledoc """
  Foundation for building reusable, stateful terminal UI components.

  Provides a React-like component system with lifecycle hooks, state management,
  and event handling. Components use props (immutable config) and state (mutable data).

  ## Usage

      defmodule Counter do
        use Raxol.Component
        
        @impl true
        def init(props), do: %{count: props[:initial] || 0}
        
        @impl true
        def render(state, _props) do
          "Count: \#{state.count}\n[+] Increment  [-] Decrement"
        end
        
        @impl true
        def handle_event(:key_press, "+", state) do
          {:ok, %{state | count: state.count + 1}}
        end
        
        @impl true
        def handle_event(:key_press, "-", state) do
          {:ok, %{state | count: state.count - 1}}
        end
        
        @impl true
        def handle_event(_, _, state), do: {:ok, state}
      end

  Required callbacks: `init/1`, `render/2`. Optional: `handle_event/3`, `update/2`,
  `mount/1`, `unmount/1`, `cleanup/1`.
  """

  defmacro __using__(opts) do
    quote do
      use Raxol.UI.Components.Base.Component, unquote(opts)
    end
  end
end
