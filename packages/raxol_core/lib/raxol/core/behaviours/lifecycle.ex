defmodule Raxol.Core.Behaviours.Lifecycle do
  @moduledoc """
  Common behavior for lifecycle management across different components.

  This behavior defines a consistent interface for components that have
  initialization, start, stop, and cleanup phases.
  """

  @type opts :: keyword()
  @type state :: any()
  @type reason :: term()

  @doc """
  Initializes the component with the given options.
  """
  @callback init(opts) :: {:ok, state} | {:error, reason}

  @doc """
  Starts the component. Called after successful initialization.
  """
  @callback start(state, opts) :: {:ok, state} | {:error, reason}

  @doc """
  Stops the component gracefully.
  """
  @callback stop(state, reason) :: {:ok, state} | {:error, reason}

  @doc """
  Cleans up resources. Always called during shutdown.
  """
  @callback terminate(state, reason) :: :ok

  @doc """
  Checks if the component is healthy and running.
  """
  @callback health_check(state) :: :ok | {:error, reason}

  @doc """
  Restarts the component. Default implementation stops then starts.
  """
  @callback restart(state, opts) :: {:ok, state} | {:error, reason}

  @optional_callbacks [health_check: 1, restart: 2]

  @doc """
  Default implementations for optional callbacks.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.Core.Behaviours.Lifecycle

      @impl true
      def health_check(_state), do: :ok

      @impl true
      def restart(state, opts) do
        case stop(state, :restart) do
          {:ok, stopped_state} -> start(stopped_state, opts)
          {:error, reason} -> {:error, reason}
        end
      end

      defoverridable health_check: 1, restart: 2
    end
  end
end
