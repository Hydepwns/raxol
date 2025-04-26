defmodule Raxol.Core.Runtime.Application do
  @moduledoc """
  Defines the behaviour for Raxol applications following The Elm Architecture (TEA).

  This module provides the core structure for building terminal applications using
  a pure functional approach with unidirectional data flow. The architecture is
  composed of three main parts:

  1. **Model** - The complete state of your application
  2. **Update** - A way to update your state
  3. **View** - A way to view your state as UI elements

  ## Example

      defmodule MyApp do
        use Raxol.Core.Runtime.Application

        def init(_context) do
          %{count: 0}
        end

        def update(msg, model) do
          case msg do
            :increment ->
              {%{model | count: model.count + 1}, []}
            :decrement ->
              {%{model | count: model.count - 1}, []}
            _ ->
              {model, []}
          end
        end

        def view(model) do
          view do
            panel title: "Counter" do
              row do
                button(label: "-", on_click: :decrement)
                text(content: "Count: \#{model.count}")
                button(label: "+", on_click: :increment)
              end
            end
          end
        end

        def subscribe(_model) do
          # Optional subscriptions to time-based or external events
          []
        end
      end

  ## Lifecycle

  1. The application starts with `init/1`, which sets up the initial state
  2. Events or messages trigger `update/2`, which computes the new state
  3. State changes cause `view/1` to re-render the UI
  4. `subscribe/1` can set up recurring updates or external event subscriptions

  ## Commands and Effects

  The update function returns a tuple of `{new_state, commands}`, where commands
  are used to handle side effects like:
  - API calls
  - File operations
  - Timer operations
  - Inter-process communication

  Commands are executed by the runtime system, keeping the update function pure.

  ## Subscriptions

  Subscriptions allow your application to receive messages over time, such as:
  - Timer-based updates
  - System events
  - External data streams

  Define subscriptions in the `subscribe/1` callback, which is called after
  initialization and after each state update.
  """

  @type context :: map()
  @type state :: term()
  @type message :: term()
  @type command :: term()
  @type subscription :: term()
  @type element :: Raxol.Core.Renderer.Element.t()

  require Logger

  @doc """
  Initializes the application state.

  Called once when the application starts. The context map contains runtime
  information such as terminal dimensions, environment variables, and startup
  arguments.

  Returns either:
  - Initial state: `state()`
  - State and commands: `{state(), [command()]}`
  """
  @callback init(context()) :: state() | {state(), [command()]}

  @doc """
  Updates the application state in response to messages.

  Called whenever a message is received, either from events, commands, or
  subscriptions. Should be a pure function that computes the new state
  based on the current state and message.

  Returns a tuple of the new state and any commands to be executed:
  `{state(), [command()]}`
  """
  @callback update(message(), state()) :: {state(), [command()]}

  @doc """
  Renders the current state as UI elements.

  Called after every state update to generate the new view. Should be a
  pure function that converts the state into UI elements.

  Returns an element tree that will be rendered to the terminal.
  """
  @callback view(state()) :: element()

  @doc """
  Sets up subscriptions based on the current state.

  Called after initialization and after each state update. Use this to
  set up recurring updates or subscribe to external events.

  Returns a list of subscription specifications.
  """
  @callback subscribe(state()) :: [subscription()]

  @optional_callbacks [subscribe: 1]

  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.Core.Runtime.Application

      import Raxol.View
      alias Raxol.Core.Events.Event
      alias Raxol.Core.Runtime.Command
      alias Raxol.Core.Runtime.Subscription

      # Default implementations
      def init(_), do: %{}
      def update(_, state), do: {state, []}
      def view(_), do: view(do: text(content: "Default view"))
      def subscribe(_), do: []

      # Allow overriding
      defoverridable init: 1, update: 2, view: 1, subscribe: 1

      # Helper functions
      def command(cmd), do: Command.new(cmd)
      def batch(cmds) when is_list(cmds), do: Command.batch(cmds)

      def subscribe_to_events(events) when is_list(events) do
        Subscription.events(events)
      end

      def subscribe_interval(interval, msg) do
        Subscription.interval(interval, msg)
      end
    end
  end

  @doc """
  Placeholder for the application update function.
  Should handle messages and update the application model.
  """
  @spec update(module(), any(), map()) :: {map(), list()} | {:error, term()}
  def update(_app_module, message, current_model) do
    Logger.debug("[#{__MODULE__}] update called with: #{inspect(message)}")
    # Default behaviour: return model unchanged, no commands
    # TODO: Implement actual update logic based on app_module behaviour
    {current_model, []}
  end

  @doc """
  Placeholder for getting environment configuration.
  """
  @spec get_env(atom(), atom(), any()) :: any()
  def get_env(app, key, default \\ nil) do
    Logger.debug("[#{__MODULE__}] get_env called for: #{app}.#{key}")
    # TODO: Implement actual config fetching (e.g., from Application env)
    Application.get_env(app, key, default)
  end
end
