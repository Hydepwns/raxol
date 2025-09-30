defmodule Raxol.Core.Behaviours.BaseRegistry do
  @moduledoc """
  Base behavior for registry GenServers to reduce code duplication.
  Provides common patterns for registering, unregistering, and looking up resources.
  """

  @doc """
  Called to initialize the registry state.
  """
  @callback init_registry(keyword()) :: {:ok, any()} | {:error, any()}

  @doc """
  Called to validate a resource before registration.
  """
  @callback validate_resource(any(), any()) :: :ok | {:error, any()}

  @doc """
  Called when a resource is registered.
  """
  @callback on_register(any(), any(), any()) :: any()

  @doc """
  Called when a resource is unregistered.
  """
  @callback on_unregister(any(), any()) :: any()

  @optional_callbacks [
    validate_resource: 2,
    on_register: 3,
    on_unregister: 2
  ]

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use GenServer
  alias Raxol.Core.Runtime.Log
      @behaviour Raxol.Core.Behaviours.BaseRegistry

      defstruct registry: %{}, metadata: %{}

      def start_link(init_opts \\ []) do
        server_opts =
          Keyword.take(init_opts, [:name, :timeout, :debug, :spawn_opt])

        registry_opts =
          Keyword.drop(init_opts, [:name, :timeout, :debug, :spawn_opt])

        GenServer.start_link(__MODULE__, registry_opts, server_opts)
      end

      ## Client API

      def register(registry \\ __MODULE__, key, resource, metadata \\ %{}) do
        GenServer.call(registry, {:register, key, resource, metadata})
      end

      def unregister(registry \\ __MODULE__, key) do
        GenServer.call(registry, {:unregister, key})
      end

      def lookup(registry \\ __MODULE__, key) do
        GenServer.call(registry, {:lookup, key})
      end

      def list_all(registry \\ __MODULE__) do
        GenServer.call(registry, :list_all)
      end

      def list_keys(registry \\ __MODULE__) do
        GenServer.call(registry, :list_keys)
      end

      def count(registry \\ __MODULE__) do
        GenServer.call(registry, :count)
      end

      ## GenServer Implementation

      @impl GenServer
      def init(opts) do
        case init_registry(opts) do
          {:ok, custom_state} ->
            state = %__MODULE__{
              registry: %{},
              metadata: Map.get(custom_state, :metadata, %{})
            }

            {:ok, Map.merge(state, custom_state)}

          {:error, reason} ->
            {:stop, reason}
        end
      end

      @impl GenServer
      def handle_call({:register, key, resource, metadata}, _from, state) do
        case validate_registration(key, resource) do
          :ok ->
            new_registry = Map.put(state.registry, key, resource)
            new_metadata = Map.put(state.metadata, key, metadata)

            new_state = %{
              state
              | registry: new_registry,
                metadata: new_metadata
            }

            if function_exported?(__MODULE__, :on_register, 3) do
              final_state = on_register(key, resource, new_state)
              {:reply, :ok, final_state}
            else
              {:reply, :ok, new_state}
            end

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      end

      def handle_call({:unregister, key}, _from, state) do
        case Map.get(state.registry, key) do
          nil ->
            {:reply, {:error, :not_found}, state}

          resource ->
            new_registry = Map.delete(state.registry, key)
            new_metadata = Map.delete(state.metadata, key)

            new_state = %{
              state
              | registry: new_registry,
                metadata: new_metadata
            }

            if function_exported?(__MODULE__, :on_unregister, 2) do
              final_state = on_unregister(key, new_state)
              {:reply, :ok, final_state}
            else
              {:reply, :ok, new_state}
            end
        end
      end

      def handle_call({:lookup, key}, _from, state) do
        resource = Map.get(state.registry, key)
        metadata = Map.get(state.metadata, key, %{})
        {:reply, {resource, metadata}, state}
      end

      def handle_call(:list_all, _from, state) do
        all =
          Enum.map(state.registry, fn {key, resource} ->
            metadata = Map.get(state.metadata, key, %{})
            {key, resource, metadata}
          end)

        {:reply, all, state}
      end

      def handle_call(:list_keys, _from, state) do
        keys = Map.keys(state.registry)
        {:reply, keys, state}
      end

      def handle_call(:count, _from, state) do
        count = map_size(state.registry)
        {:reply, count, state}
      end

      def handle_call(request, _from, state) do
        Log.module_warning("Unhandled call in #{__MODULE__}: #{inspect(request)}")
        {:reply, {:error, :not_implemented}, state}
      end

      @impl GenServer
      def handle_cast(msg, state) do
        Log.module_warning("Unhandled cast in #{__MODULE__}: #{inspect(msg)}")
        {:noreply, state}
      end

      @impl GenServer
      def handle_info(msg, state) do
        Log.module_debug("Unhandled info in #{__MODULE__}: #{inspect(msg)}")
        {:noreply, state}
      end

      ## Private Functions

      defp validate_registration(key, resource) do
        if function_exported?(__MODULE__, :validate_resource, 2) do
          validate_resource(key, resource)
        else
          :ok
        end
      end

      # Default implementations
      def init_registry(_opts), do: {:ok, %{}}

      defoverridable init_registry: 1,
                     handle_call: 3,
                     handle_cast: 2,
                     handle_info: 2
    end
  end
end
