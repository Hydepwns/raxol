defmodule Raxol.App do
  @moduledoc """
  Defines the behaviour for a Raxol application and provides default implementations.

  A Raxol application follows The Elm Architecture (TEA) pattern:

  - `init/1`: Initializes the application state (model).
  - `update/2`: Handles messages (events) and updates the model.
  - `render/1`: Renders the UI based on the current model.

  To create a Raxol application, `use Raxol.App` in your module and implement
  the required callbacks (`init/1`, `update/2`, `render/1`).

  Example:

      defmodule MyApp do
        use Raxol.App

        @impl true
        def init(_opts) do
          %{count: 0}
        end

        @impl true
        def update(%{count: count} = model, msg) do
          case msg do
            :increment -> %{model | count: count + 1}
            :decrement -> %{model | count: count - 1}
            _ -> model
          end
        end

        # The render function example was removed due to compilation issues.
        # Refer to Raxol.View documentation for rendering examples.
      end
  """

  @type model :: term()
  @type msg :: term()
  @type options :: term()

  @doc """
  Defines the Raxol.App behaviour.

  This macro imports Raxol.View for use in render function
  and defines required callbacks for implementing the TEA pattern.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.App

      # Default implementations provided by the behaviour itself
      # These can be overridden by the specific app module

      @impl Raxol.App
      def init(_opts), do: %{}

      @impl Raxol.App
      def update(model, _msg), do: model

      @impl Raxol.App
      def render(_model) do
        # Default render returns an empty view
        # Import View locally for the default implementation
        require Raxol.View
        Raxol.View.view(do: nil)
      end

      # Allow overriding the defaults
      defoverridable init: 1, update: 2, render: 1

      # Import View functions for use in the specific app's render
      import Raxol.View
    end
  end

  @doc """
  Initialize the application state.

  This callback is called once when the application starts.
  It should return the initial model (state) for the application.

  ## Parameters

  - `options` - The options passed to `Raxol.run/2`

  ## Returns

  The initial model (state) for the application.
  """
  @callback init(options()) :: model()

  @doc """
  Update the application state in response to a message.

  This callback is called whenever a message is sent to the application.
  It should return an updated model based on the received message.

  ## Parameters

  - `model` - The current application state
  - `msg` - The message that was sent

  ## Returns

  The updated model (state) for the application.
  """
  @callback update(model(), msg()) :: model()

  @doc """
  Render the application UI based on the current state.

  This callback is called whenever the application needs to redraw the UI.
  It should return a view representation using the Raxol.View DSL.

  ## Parameters

  - `model` - The current application state

  ## Returns

  A view representation using the Raxol.View DSL.
  """
  @callback render(model()) :: Raxol.View.t()
end
