defmodule Raxol.Terminal.Capabilities.Manager do
  @moduledoc """
  Manages terminal capabilities including detection, negotiation, and caching.
  """

  use GenServer
  require Logger

  alias Raxol.Terminal.Capabilities.Types

  @type state :: Types.t()

  # Client API

  @doc """
  Starts the capabilities manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Detects and registers a new capability.
  """
  @spec detect_capability(atom(), term()) :: :ok | {:error, term()}
  def detect_capability(capability, value) do
    GenServer.call(__MODULE__, {:detect_capability, capability, value})
  end

  @doc """
  Queries if a capability is supported.
  """
  @spec query_capability(atom()) :: Types.capability_response()
  def query_capability(capability) do
    GenServer.call(__MODULE__, {:query_capability, capability})
  end

  @doc """
  Enables a capability if supported.
  """
  @spec enable_capability(atom()) :: :ok | {:error, term()}
  def enable_capability(capability) do
    GenServer.call(__MODULE__, {:enable_capability, capability})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %Types{}
    {:ok, state}
  end

  @impl true
  def handle_call({:detect_capability, capability, value}, _from, state) do
    new_state = %{state | supported: Map.put(state.supported, capability, value)}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:query_capability, capability}, _from, state) do
    case Map.get(state.supported, capability) do
      nil -> {:reply, {:error, :unsupported}, state}
      value -> {:reply, {:ok, value}, state}
    end
  end

  @impl true
  def handle_call({:enable_capability, capability}, _from, state) do
    case Map.get(state.supported, capability) do
      nil ->
        {:reply, {:error, :unsupported}, state}
      value ->
        new_state = %{state | enabled: Map.put(state.enabled, capability, value)}
        {:reply, :ok, new_state}
    end
  end
end
