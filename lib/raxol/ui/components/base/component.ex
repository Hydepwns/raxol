defmodule Raxol.UI.Components.Base.Component do
  @moduledoc '''
  Defines the behavior for UI components in the Raxol system.

  This module provides the core structure for building reusable UI components
  with lifecycle hooks, state management, and event handling. Components follow
  a similar pattern to the main application architecture but at a smaller scale.

  ## Component Lifecycle

  1. `init/1` - Initialize component state with props
  2. `mount/1` - Called when the component is first mounted
  3. `update/2` - Handle messages and update component state
  4. `render/1` - Generate the visual representation of the component
  5. `handle_event/2` - Handle UI events
  6. `unmount/1` - Clean up resources when component is removed

  ## Example

      defmodule MyComponent do
        use Raxol.UI.Components.Base.Component

        def init(props) do
          Map.merge(%{count: 0}, props)
        end

        def mount(state) do
          {state, []}
        end

        def update(:increment, state) do
          %{state | count: state.count + 1}
        end

        def render(state) do
          row do
            button(label: "-", on_click: :decrement)
            text("Count: \#{state.count}")
            button(label: "+", on_click: :increment)
          end
        end

        def handle_event({:click, :increment}, state) do
          {update(:increment, state), []}
        end

        def handle_event({:click, :decrement}, state) do
          {%{state | count: state.count - 1}, []}
        end
      end
  '''

  @type props :: map()
  @type state :: map()
  @type message :: term()
  @type command :: term()
  @type element :: term()
  @type event :: term()
  # Type for context passed to render/handle_event
  @type context :: map()

  @doc '''
  Initializes the component with the given props.

  Called when the component is created. Should merge default values with
  the provided props to create the initial state.
  '''
  @callback init(props()) :: state()

  @doc '''
  Called when the component is mounted in the UI.

  This is where you can set up subscriptions, execute initial commands,
  or perform other setup tasks. Returns the potentially modified state
  and any commands to execute.
  '''
  @callback mount(state()) :: {state(), [command()]}

  @doc '''
  Updates the component state in response to messages.

  Similar to the application update function, this handles messages sent to
  the component and returns the new state.
  '''
  @callback update(message(), state()) :: state()

  @doc '''
  Renders the component based on its current state.

  Returns an element tree that will be rendered to the screen. The context
  map contains theme, layout constraints, etc.
  '''
  @callback render(state(), context()) :: element()

  @doc '''
  Handles UI events that occur on the component.

  The context map provides additional event details or UI state.
  Returns the potentially modified state and any commands to execute.
  '''
  @callback handle_event(event(), state(), context()) :: {state(), [command()]}

  @doc '''
  Called when the component is being removed from the UI.

  Use this to clean up any resources or perform final actions.
  '''
  @callback unmount(state()) :: state()

  @optional_callbacks [mount: 1, unmount: 1]

  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.UI.Components.Base.Component

      # Default implementations
      def mount(state), do: {state, []}
      def unmount(state), do: state

      # Allow overriding
      defoverridable mount: 1, unmount: 1

      # Helper functions for commands
      def command(cmd), do: {:command, cmd}
      def schedule(msg, delay), do: {:schedule, msg, delay}
      def broadcast(msg), do: {:broadcast, msg}
    end
  end
end
