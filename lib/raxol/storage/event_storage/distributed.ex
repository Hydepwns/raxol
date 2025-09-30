defmodule Raxol.Storage.EventStorage.Distributed do
  @moduledoc """
  Distributed event storage implementation for high availability.
  """

  @behaviour Raxol.Storage.EventStorage

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log
  # EventSourcing aliases will be added when needed

  defstruct [
    :config,
    :local_storage,
    :cluster_nodes,
    :replication_factor,
    :consistency_level
  ]

  @default_config %{
    replication_factor: 3,
    consistency_level: :quorum,
    cluster_nodes: [node()]
  }

  ## Client API

  @impl Raxol.Storage.EventStorage
  def append_event(storage \\ __MODULE__, event, stream_name) do
    GenServer.call(storage, {:append_event, event, stream_name})
  end

  @impl Raxol.Storage.EventStorage
  def append_events(storage \\ __MODULE__, events, stream_name) do
    GenServer.call(storage, {:append_events, events, stream_name})
  end

  @impl Raxol.Storage.EventStorage
  def read_stream(storage \\ __MODULE__, stream_name, start_position, count) do
    GenServer.call(storage, {:read_stream, stream_name, start_position, count})
  end

  @impl Raxol.Storage.EventStorage
  def read_all(storage \\ __MODULE__, start_position, count) do
    GenServer.call(storage, {:read_all, start_position, count})
  end

  @impl Raxol.Storage.EventStorage
  def list_streams(storage \\ __MODULE__) do
    GenServer.call(storage, :list_streams)
  end

  @impl Raxol.Storage.EventStorage
  def save_snapshot(storage \\ __MODULE__, snapshot) do
    GenServer.call(storage, {:save_snapshot, snapshot})
  end

  @impl Raxol.Storage.EventStorage
  def load_snapshot(storage \\ __MODULE__, stream_name) do
    GenServer.call(storage, {:load_snapshot, stream_name})
  end

  ## BaseManager Implementation

  @impl true
  def init_manager(opts) when is_list(opts) do
    config =
      Keyword.get(opts, :config, %{})
      |> then(&Map.merge(@default_config, &1))

    init_manager(config)
  end

  def init_manager(config) when is_map(config) do
    # Ensure we have complete config
    config = Map.merge(@default_config, config)
    # Start local storage backend
    {:ok, local_storage} = Raxol.Storage.EventStorage.Disk.start_link()

    state = %__MODULE__{
      config: config,
      local_storage: local_storage,
      cluster_nodes: config.cluster_nodes,
      replication_factor: config.replication_factor,
      consistency_level: config.consistency_level
    }

    Log.module_info(
      "Distributed event storage initialized with replication factor #{config.replication_factor}"
    )

    {:ok, state}
  end

  @impl true
  def handle_manager_call({:append_event, event, stream_name}, _from, state) do
    # For now, delegate to local storage
    # In a full implementation, this would replicate across nodes
    result =
      Raxol.Storage.EventStorage.Disk.append_event(
        state.local_storage,
        event,
        stream_name
      )

    {:reply, result, state}
  end

  @impl true
  def handle_manager_call({:append_events, events, stream_name}, _from, state) do
    result =
      Raxol.Storage.EventStorage.Disk.append_events(
        state.local_storage,
        events,
        stream_name
      )

    {:reply, result, state}
  end

  @impl true
  def handle_manager_call(
        {:read_stream, stream_name, start_position, count},
        _from,
        state
      ) do
    result =
      Raxol.Storage.EventStorage.Disk.read_stream(
        state.local_storage,
        stream_name,
        start_position,
        count
      )

    {:reply, result, state}
  end

  @impl true
  def handle_manager_call({:read_all, start_position, count}, _from, state) do
    result =
      Raxol.Storage.EventStorage.Disk.read_all(
        state.local_storage,
        start_position,
        count
      )

    {:reply, result, state}
  end

  @impl true
  def handle_manager_call(:list_streams, _from, state) do
    result = Raxol.Storage.EventStorage.Disk.list_streams(state.local_storage)
    {:reply, result, state}
  end

  @impl true
  def handle_manager_call({:save_snapshot, snapshot}, _from, state) do
    result =
      Raxol.Storage.EventStorage.Disk.save_snapshot(
        state.local_storage,
        snapshot
      )

    {:reply, result, state}
  end

  @impl true
  def handle_manager_call({:load_snapshot, stream_name}, _from, state) do
    result =
      Raxol.Storage.EventStorage.Disk.load_snapshot(
        state.local_storage,
        stream_name
      )

    {:reply, result, state}
  end
end
