defmodule Raxol.App do
  @moduledoc ~S"""
  A behaviour module for implementing a Raxol application.

  This module provides the structure for implementing applications
  following The Elm Architecture (TEA) pattern.

  ## Example

      defmodule MyApp do
        use Raxol.App

        @impl true
        def init(_) do
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

        @impl true
        def render(%{count: count}) do
          use Raxol.View

          view do
            panel title: "Counter Example" do
              label content: "Count: #{count}"

              row do
                button label: "Increment", on_click: :increment
                button label: "Decrement", on_click: :decrement
              end
            end
          end
        end
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

      # Default implementations

      @impl true
      def init(_opts), do: %{}

      @impl true
      def update(model, _msg), do: model

      @impl true
      def render(_model), do: Raxol.View.view(do: nil)

      # Allow overriding the defaults
      defoverridable init: 1, update: 2, render: 1
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
