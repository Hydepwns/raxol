defmodule Raxol.Component do
  @moduledoc """
  Defines the behavior and provides helpers for Raxol components.

  Components are the building blocks of Raxol applications. Each component:
  * Manages its own state
  * Handles events
  * Renders a view
  * Can emit commands
  * Manages subscriptions through lifecycle hooks

  ## Example

      defmodule MyComponent do
        use Raxol.Component

        def init(props) do
          # Subscribe to events on init
          {:ok, subscription} = subscribe_to_events([:key, :mouse])

          %{
            count: props[:initial_count] || 0,
            subscription: subscription
          }
        end

        def update({:increment}, state) do
          %{state | count: state.count + 1}
        end

        def render(state) do
          View.text(content: "Count: \#{state.count}")
        end

        def handle_event(%Event{type: :click}, state) do
          {update({:increment}, state), []}
        end

        def mount(state) do
          # Called when component is mounted to the view tree
          {state, []}
        end

        def unmount(state) do
          # Cleanup subscriptions on unmount
          if state.subscription do
            unsubscribe(state.subscription)
          end
          state
        end
      end
  """

  @type props :: map()
  @type state :: term()
  @type message :: term()
  @type command :: term()
  @type element :: Raxol.Core.Renderer.Element.t()

  @callback init(props()) :: state()
  @callback update(message(), state()) :: state()
  @callback render(state()) :: element()
  @callback handle_event(term(), state()) :: {state(), [command()]}
  @callback mount(state()) :: {state(), [command()]}
  @callback unmount(state()) :: state()

  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.Component

      import Raxol.View
      alias Raxol.Core.Events.{Event, Subscription}

      # Default implementations
      def init(_props), do: %{}
      def update(_msg, state), do: state
      def render(_state), do: nil
      def handle_event(_event, state), do: {state, []}
      def mount(state), do: {state, []}
      def unmount(state), do: state

      # Allow overriding
      defoverridable init: 1, update: 2, render: 1, handle_event: 2, mount: 1, unmount: 1

      # Helper functions available to all components
      def component_id, do: inspect(__MODULE__)

      def emit(command), do: {:command, command}

      def schedule(msg, delay) do
        emit({:schedule, msg, delay})
      end

      def broadcast(msg) do
        emit({:broadcast, msg})
      end

      def subscribe_to_events(events) when is_list(events) do
        Subscription.events(events)
      end

      def unsubscribe(subscription) do
        Subscription.unsubscribe(subscription)
      end
    end
  end
end
