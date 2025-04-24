defmodule Raxol.UI.Components.Base.Component do
  @moduledoc """
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
  """

  @type props :: map()
  @type state :: map()
  @type message :: term()
  @type command :: term()
  @type element :: term()
  @type event :: term()

  @doc """
  Initializes the component with the given props.

  Called when the component is created. Should merge default values with
  the provided props to create the initial state.
  """
  @callback init(props()) :: state()

  @doc """
  Called when the component is mounted in the UI.

  This is where you can set up subscriptions, execute initial commands,
  or perform other setup tasks. Returns the potentially modified state
  and any commands to execute.
  """
  @callback mount(state()) :: {state(), [command()]}

  @doc """
  Updates the component state in response to messages.

  Similar to the application update function, this handles messages sent to
  the component and returns the new state.
  """
  @callback update(message(), state()) :: state()

  @doc """
  Renders the component based on its current state.

  Returns an element tree that will be rendered to the screen.
  """
  @callback render(state()) :: element()

  @doc """
  Handles UI events that occur on the component.

  Returns the potentially modified state and any commands to execute.
  """
  @callback handle_event(event(), state()) :: {state(), [command()]}

  @doc """
  Called when the component is being removed from the UI.

  Use this to clean up any resources or perform final actions.
  """
  @callback unmount(state()) :: state()

  @optional_callbacks [mount: 1, unmount: 1]

  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.UI.Components.Base.Component

      import Raxol.View
      alias Raxol.Core.Events.Event

      # Default implementations
      def mount(state), do: {state, []}
      def unmount(state), do: state

      # Allow overriding
      defoverridable [mount: 1, unmount: 1]

      # Helper functions for commands
      def command(cmd), do: {:command, cmd}
      def schedule(msg, delay), do: {:schedule, msg, delay}
      def broadcast(msg), do: {:broadcast, msg}
    end
  end

  @type t :: map()

  @doc """
  Renders the component based on its current state.

  This callback must return a view representation of the component,
  which will be used by the layout engine to position and display the component.

  ## Parameters

  * `component` - The component to render
  * `context` - The rendering context containing theme and other information

  ## Returns

  A view representation of the component for the layout engine.
  """
  @callback render(component :: t(), context :: map()) :: map()

  @doc """
  Handles input events for the component.

  This callback processes user interactions and other events that affect
  the component's state.

  ## Parameters

  * `component` - The component receiving the event
  * `event` - The event to handle
  * `context` - The event handling context

  ## Returns

  `{:update, updated_component}` if the component state changed,
  `{:handled, component}` if the event was handled but state didn't change,
  `:passthrough` if the event wasn't handled by the component.
  """
  @callback handle_event(component :: t(), event :: map(), context :: map()) ::
    {:update, updated_component :: t()} |
    {:handled, component :: t()} |
    :passthrough

  @doc """
  Optional callback that runs when the component is mounted.

  This is where you can initialize state, start processes, or set up subscriptions.

  ## Parameters

  * `component` - The component being mounted
  * `context` - The mounting context

  ## Returns

  The updated component.
  """
  @callback mount(component :: t(), context :: map()) :: t()

  @doc """
  Optional callback that runs when the component is updated with new props.

  This allows the component to react to prop changes beyond simple state updates.

  ## Parameters

  * `old_component` - The component before the update
  * `new_component` - The component with updated props
  * `context` - The update context

  ## Returns

  The finalized updated component.
  """
  @callback update(old_component :: t(), new_component :: t(), context :: map()) :: t()

  @doc """
  Optional callback that runs when the component is unmounted.

  This is where you can clean up resources, stop processes, or cancel subscriptions.

  ## Parameters

  * `component` - The component being unmounted
  * `context` - The unmounting context

  ## Returns

  The final component state (typically just for debugging purposes).
  """
  @callback unmount(component :: t(), context :: map()) :: t()

  # Make mount, update, and unmount optional callbacks
  @optional_callbacks [mount: 2, update: 3, unmount: 2]

  @doc """
  Returns a default implementation for a component callback.

  This is useful for implementing common default behaviors for optional callbacks.

  ## Parameters

  * `callback` - The callback to get a default implementation for

  ## Returns

  The default implementation function.
  """
  def default_impl(:mount) do
    fn component, _context -> component end
  end

  def default_impl(:update) do
    fn _old_component, new_component, _context -> new_component end
  end

  def default_impl(:unmount) do
    fn component, _context -> component end
  end
end
