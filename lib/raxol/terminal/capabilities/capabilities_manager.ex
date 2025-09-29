defmodule Raxol.Terminal.Capabilities.Manager do
  @moduledoc """
  Manages terminal capabilities including detection, negotiation, and caching.
  """

  use Raxol.Core.Behaviours.BaseManager


  alias Raxol.Terminal.Capabilities.Types

  @type state :: Types.t()

  # BaseManager provides start_link/1
  # Usage: Raxol.Terminal.Capabilities.Manager.start_link(name: __MODULE__, ...)

  @doc """
  Detects and registers a new capability.
  """
  @spec detect_capability(atom(), term(), atom() | nil) ::
          :ok | {:error, term()}
  def detect_capability(capability, value, name \\ __MODULE__) do
    GenServer.call(name, {:detect_capability, capability, value})
  end

  @doc """
  Queries if a capability is supported.
  """
  @spec query_capability(atom(), atom() | nil) :: Types.capability_response()
  def query_capability(capability, name \\ __MODULE__) do
    GenServer.call(name, {:query_capability, capability})
  end

  @doc """
  Enables a capability if supported.
  """
  @spec enable_capability(atom(), atom() | nil) :: :ok | {:error, term()}
  def enable_capability(capability, name \\ __MODULE__) do
    GenServer.call(name, {:enable_capability, capability})
  end

  @impl true
  def init_manager(_opts) do
    state = %Types{}
    {:ok, state}
  end

  @impl true
  def handle_manager_call({:detect_capability, capability, value}, _from, state) do
    new_state = %{
      state
      | supported: Map.put(state.supported, capability, value)
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:query_capability, capability}, _from, state) do
    case Map.get(state.supported, capability) do
      nil -> {:reply, {:error, :unsupported}, state}
      value -> {:reply, {:ok, value}, state}
    end
  end

  @impl true
  def handle_manager_call({:enable_capability, capability}, _from, state) do
    case Map.get(state.supported, capability) do
      nil ->
        {:reply, {:error, :unsupported}, state}

      value ->
        new_state = %{
          state
          | enabled: Map.put(state.enabled, capability, value)
        }

        {:reply, :ok, new_state}
    end
  end
end
