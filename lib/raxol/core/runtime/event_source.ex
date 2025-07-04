defmodule Raxol.Core.Runtime.EventSource do
  @moduledoc """
  Behaviour for implementing custom event sources for subscriptions.

  Event sources are processes that can generate events over time and send them
  to subscribers. This behaviour defines the contract that custom event sources
  must implement.

  ## Example

      defmodule MyEventSource do
        use Raxol.Core.Runtime.EventSource

        @impl true
        def init(args, context) do
          # Set up initial state
          {:ok, %{args: args, context: context}}
        end

        @impl true
        def handle_info(:tick, state) do
          # Send an event to the subscriber
          send_event(state.context, {:my_event, :data})
          {:noreply, state}
        end
      end
  """

  @doc """
  Called when the event source is started. Should return the initial state.

  ## Parameters
    * `args` - The arguments passed to `Subscription.custom/2`
    * `context` - The runtime context containing the subscriber pid

  ## Returns
    * `{:ok, state}` - Successfully initialized with state
    * `{:error, reason}` - Failed to initialize
  """
  @callback init(args :: term(), context :: map()) ::
              {:ok, state :: term()} | {:error, reason :: term()}

  @doc """
  Called when the event source receives a message. Should handle the message
  and optionally send events to the subscriber.

  ## Parameters
    * `msg` - The received message
    * `state` - The current state

  ## Returns
    * `{:noreply, new_state}` - Continue with new state
    * `{:stop, reason, new_state}` - Stop the event source
  """
  @callback handle_info(msg :: term(), state :: term()) ::
              {:noreply, new_state :: term()}
              | {:stop, reason :: term(), new_state :: term()}

  @doc """
  Called when the event source is stopping. Can be used to clean up resources.

  ## Parameters
    * `reason` - The reason for stopping
    * `state` - The current state

  ## Returns
    * `:ok`
  """
  @callback terminate(reason :: term(), state :: term()) :: :ok

  @optional_callbacks [terminate: 2]

  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.Core.Runtime.EventSource

      @impl GenServer
      def start_link(args, context) do
        GenServer.start_link(__MODULE__, {args, context})
      end

      @impl GenServer
      def init({args, context}) do
        case __MODULE__.init(args, context) do
          {:ok, state} -> {:ok, state}
          error -> error
        end
      end

      @impl GenServer
      def handle_info(msg, state) do
        case __MODULE__.handle_info(msg, state) do
          {:noreply, new_state} -> {:noreply, new_state}
          {:stop, reason, new_state} -> {:stop, reason, new_state}
        end
      end

      @impl GenServer
      def terminate(reason, state) do
        if function_exported?(__MODULE__, :terminate, 2) do
          __MODULE__.terminate(reason, state)
        else
          :ok
        end
      end

      defp send_event(context, event) do
        send(context.pid, {:subscription, event})
      end

      defoverridable init: 1, handle_info: 2, terminate: 2
    end
  end
end
