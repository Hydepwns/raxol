defmodule Raxol.Core.Behaviours.BaseManager do
  @moduledoc """
  Base behavior for manager GenServers to reduce code duplication.
  Provides common patterns for state management, lifecycle, and error handling.
  """

  @doc """
  Called to initialize the manager state.
  """
  @callback init_manager(keyword()) :: {:ok, any()} | {:error, any()}

  @doc """
  Called to handle manager-specific requests.
  """
  @callback handle_manager_call(any(), GenServer.from(), any()) ::
              {:reply, any(), any()} | {:noreply, any()} | {:stop, any(), any(), any()}

  @doc """
  Called to handle manager-specific casts.
  """
  @callback handle_manager_cast(any(), any()) ::
              {:noreply, any()} | {:stop, any(), any()}

  @doc """
  Called to handle manager-specific info messages.
  """
  @callback handle_manager_info(any(), any()) ::
              {:noreply, any()} | {:stop, any(), any()}

  @optional_callbacks [
    handle_manager_call: 3,
    handle_manager_cast: 2,
    handle_manager_info: 2
  ]

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use GenServer
      require Logger

      @behaviour Raxol.Core.Behaviours.BaseManager

      def start_link(init_opts \\ []) do
        # Convert map to keyword list if needed
        opts_as_keywords = case init_opts do
          opts when is_map(opts) -> Map.to_list(opts)
          opts when is_list(opts) -> opts
          _ -> []
        end

        server_opts = Keyword.take(opts_as_keywords, [:name, :timeout, :debug, :spawn_opt])
        manager_opts = Keyword.drop(opts_as_keywords, [:name, :timeout, :debug, :spawn_opt])

        GenServer.start_link(__MODULE__, manager_opts, server_opts)
      end

      @impl GenServer
      def init(opts) do
        case init_manager(opts) do
          {:ok, state} ->
            {:ok, state}
          {:error, reason} ->
            {:stop, reason}
        end
      end

      @impl GenServer
      def handle_call(request, from, state) do
        if function_exported?(__MODULE__, :handle_manager_call, 3) do
          handle_manager_call(request, from, state)
        else
          Logger.warning("Unhandled call: #{inspect(request)}")
          {:reply, {:error, :not_implemented}, state}
        end
      end

      @impl GenServer
      def handle_cast(msg, state) do
        if function_exported?(__MODULE__, :handle_manager_cast, 2) do
          handle_manager_cast(msg, state)
        else
          Logger.warning("Unhandled cast: #{inspect(msg)}")
          {:noreply, state}
        end
      end

      @impl GenServer
      def handle_info(msg, state) do
        if function_exported?(__MODULE__, :handle_manager_info, 2) do
          handle_manager_info(msg, state)
        else
          Logger.debug("Unhandled info: #{inspect(msg)}")
          {:noreply, state}
        end
      end

      # Default implementations for callbacks
      def handle_manager_call(_request, _from, state), do: {:reply, {:error, :not_implemented}, state}
      def handle_manager_cast(_msg, state), do: {:noreply, state}
      def handle_manager_info(_msg, state), do: {:noreply, state}

      # Default implementations
      def init_manager(_opts), do: {:ok, %{}}

      defoverridable init_manager: 1,
                     handle_manager_call: 3,
                     handle_manager_cast: 2,
                     handle_manager_info: 2
    end
  end
end