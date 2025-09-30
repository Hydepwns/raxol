defmodule Raxol.Core.Behaviours.BaseServer do
  @moduledoc """
  Base behavior for general-purpose GenServers to reduce code duplication.
  Provides common patterns for server lifecycle, error handling, and state management.
  """

  @doc """
  Called to initialize the server state.
  """
  @callback init_server(keyword()) :: {:ok, any()} | {:error, any()}

  @doc """
  Called to handle server shutdown gracefully.
  """
  @callback handle_shutdown(any()) :: :ok

  @optional_callbacks [handle_shutdown: 1]

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use GenServer
  alias Raxol.Core.Runtime.Log
      @behaviour Raxol.Core.Behaviours.BaseServer

      def start_link(init_opts \\ []) do
        server_opts =
          Keyword.take(init_opts, [:name, :timeout, :debug, :spawn_opt])

        init_args =
          Keyword.drop(init_opts, [:name, :timeout, :debug, :spawn_opt])

        GenServer.start_link(__MODULE__, init_args, server_opts)
      end

      @impl GenServer
      def init(opts) do
        case init_server(opts) do
          {:ok, state} ->
            Process.flag(:trap_exit, true)
            {:ok, state}

          {:error, reason} ->
            {:stop, reason}
        end
      end

      @impl GenServer
      def terminate(reason, state) do
        Log.module_info("#{__MODULE__} terminating: #{inspect(reason)}")

        if function_exported?(__MODULE__, :handle_shutdown, 1) do
          handle_shutdown(state)
        end

        :ok
      end

      # Helper functions for common server operations

      def get_state(server \\ __MODULE__) do
        GenServer.call(server, :get_state)
      end

      def reset_state(server \\ __MODULE__) do
        GenServer.call(server, :reset_state)
      end

      # Default implementations
      def init_server(_opts), do: {:ok, %{}}

      def handle_call(:get_state, _from, state) do
        {:reply, state, state}
      end

      def handle_call(:reset_state, _from, _state) do
        case init_server([]) do
          {:ok, new_state} -> {:reply, :ok, new_state}
          {:error, reason} -> {:reply, {:error, reason}, %{}}
        end
      end

      def handle_call(request, _from, state) do
        Log.module_warning("Unhandled call in #{__MODULE__}: #{inspect(request)}")
        {:reply, {:error, :not_implemented}, state}
      end

      def handle_cast(msg, state) do
        Log.module_warning("Unhandled cast in #{__MODULE__}: #{inspect(msg)}")
        {:noreply, state}
      end

      def handle_info(msg, state) do
        Log.module_debug("Unhandled info in #{__MODULE__}: #{inspect(msg)}")
        {:noreply, state}
      end

      defoverridable init_server: 1,
                     handle_call: 3,
                     handle_cast: 2,
                     handle_info: 2
    end
  end
end
