defmodule Raxol.Swarm.TacticalOverlay do
  @moduledoc """
  CRDT-backed shared state visible to all nodes.

  Maintains entities (LWW-Register per entity), waypoints (OR-Set),
  and annotations (LWW-Register per annotation). Syncs deltas to
  peers at a configurable interval, with full anti-entropy exchange
  periodically.
  """

  use GenServer

  require Logger

  alias Raxol.Swarm.CRDT.{LWWRegister, ORSet}

  @default_sync_interval_ms 500
  @default_anti_entropy_interval_ms 60_000

  @type entity :: %{
          id: atom(),
          node: node(),
          position: {float(), float(), float()},
          heading: float(),
          status: :active | :damaged | :offline,
          last_updated: integer(),
          metadata: map()
        }

  @type waypoint :: %{
          id: binary(),
          position: {float(), float(), float()},
          label: String.t(),
          created_by: node(),
          created_at: integer()
        }

  @type pending_op ::
          {:update_entity, atom(), LWWRegister.t()}
          | {:add_waypoint, waypoint()}
          | {:remove_waypoint, waypoint()}
          | {:add_annotation, binary(), LWWRegister.t()}

  @type t :: %__MODULE__{
          node_id: node(),
          entities: %{atom() => LWWRegister.t()},
          waypoints: ORSet.t(),
          annotations: %{binary() => LWWRegister.t()},
          peers: [node()],
          subscribers: [pid()],
          pending_ops: [pending_op()],
          sync_interval_ms: pos_integer(),
          anti_entropy_interval_ms: pos_integer(),
          sync_ref: reference() | nil,
          anti_entropy_ref: reference() | nil,
          comms_manager: GenServer.server()
        }

  defstruct node_id: nil,
            entities: %{},
            waypoints: ORSet.new(),
            annotations: %{},
            peers: [],
            subscribers: [],
            pending_ops: [],
            sync_interval_ms: @default_sync_interval_ms,
            anti_entropy_interval_ms: @default_anti_entropy_interval_ms,
            sync_ref: nil,
            anti_entropy_ref: nil,
            comms_manager: Raxol.Swarm.CommsManager

  # -- Public API --

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec update_entity(GenServer.server(), atom(), map()) :: :ok
  def update_entity(server \\ __MODULE__, entity_id, data) do
    GenServer.cast(server, {:update_entity, entity_id, data})
  end

  @spec add_waypoint(GenServer.server(), waypoint()) :: :ok
  def add_waypoint(server \\ __MODULE__, waypoint) do
    GenServer.cast(server, {:add_waypoint, waypoint})
  end

  @spec remove_waypoint(GenServer.server(), binary()) :: :ok
  def remove_waypoint(server \\ __MODULE__, waypoint_id) do
    GenServer.cast(server, {:remove_waypoint, waypoint_id})
  end

  @spec get_all_entities(GenServer.server()) :: [entity()]
  def get_all_entities(server \\ __MODULE__) do
    GenServer.call(server, :get_all_entities)
  end

  @spec get_all_waypoints(GenServer.server()) :: [waypoint()]
  def get_all_waypoints(server \\ __MODULE__) do
    GenServer.call(server, :get_all_waypoints)
  end

  @spec add_annotation(GenServer.server(), binary(), map()) :: :ok
  def add_annotation(server \\ __MODULE__, annotation_id, data) do
    GenServer.cast(server, {:add_annotation, annotation_id, data})
  end

  @spec get_overlay_state(GenServer.server()) :: map()
  def get_overlay_state(server \\ __MODULE__) do
    GenServer.call(server, :get_overlay_state)
  end

  @spec subscribe(GenServer.server()) :: :ok
  def subscribe(server \\ __MODULE__) do
    GenServer.call(server, {:subscribe, self()})
  end

  @spec set_peers(GenServer.server(), [node()]) :: :ok
  def set_peers(server \\ __MODULE__, peers) do
    GenServer.cast(server, {:set_peers, peers})
  end

  @doc "Receive a delta from a remote peer. Called via :rpc.cast."
  @spec receive_delta(GenServer.server(), node(), [term()]) :: :ok
  def receive_delta(server \\ __MODULE__, from_node, ops) do
    GenServer.cast(server, {:receive_delta, from_node, ops})
  end

  @doc "Receive full state for anti-entropy exchange."
  @spec receive_full_state(GenServer.server(), node(), map()) :: :ok
  def receive_full_state(server \\ __MODULE__, from_node, remote_state) do
    GenServer.cast(server, {:receive_full_state, from_node, remote_state})
  end

  # -- Callbacks --

  @impl true
  def init(opts) do
    node_id = Keyword.get(opts, :node_id, Node.self())

    sync_interval =
      Keyword.get(opts, :sync_interval_ms, @default_sync_interval_ms)

    anti_entropy_interval =
      Keyword.get(
        opts,
        :anti_entropy_interval_ms,
        @default_anti_entropy_interval_ms
      )

    comms_manager = Keyword.get(opts, :comms_manager, Raxol.Swarm.CommsManager)
    peers = Keyword.get(opts, :peers, [])

    state = %__MODULE__{
      node_id: node_id,
      sync_interval_ms: sync_interval,
      anti_entropy_interval_ms: anti_entropy_interval,
      comms_manager: comms_manager,
      peers: peers
    }

    state = schedule_sync(state)
    state = schedule_anti_entropy(state)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_all_entities, _from, state) do
    entities =
      Enum.map(state.entities, fn {_id, reg} -> LWWRegister.value(reg) end)

    {:reply, entities, state}
  end

  @impl true
  def handle_call(:get_all_waypoints, _from, state) do
    {:reply, ORSet.to_list(state.waypoints), state}
  end

  @impl true
  def handle_call(:get_overlay_state, _from, state) do
    overlay = %{
      entities: unwrap_registers(state.entities),
      waypoints: ORSet.to_list(state.waypoints),
      annotations: unwrap_registers(state.annotations),
      node_id: state.node_id,
      peers: state.peers
    }

    {:reply, overlay, state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, %__MODULE__{} = state) do
    Process.monitor(pid)
    {:reply, :ok, %__MODULE__{state | subscribers: [pid | state.subscribers]}}
  end

  @impl true
  def handle_cast({:update_entity, entity_id, data}, %__MODULE__{} = state) do
    now = System.monotonic_time(:millisecond)

    entity_data =
      Map.merge(data, %{
        id: entity_id,
        node: state.node_id,
        last_updated: now
      })

    reg =
      case Map.get(state.entities, entity_id) do
        nil -> LWWRegister.new(entity_data, state.node_id)
        existing -> LWWRegister.update(existing, entity_data)
      end

    entities = Map.put(state.entities, entity_id, reg)
    op = {:update_entity, entity_id, reg}

    state = %__MODULE__{
      state
      | entities: entities,
        pending_ops: [op | state.pending_ops]
    }

    notify_subscribers(
      state.subscribers,
      {:entity_updated, entity_id, entity_data}
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_waypoint, waypoint}, %__MODULE__{} = state) do
    waypoints = ORSet.add(state.waypoints, waypoint, state.node_id)
    op = {:add_waypoint, waypoint}

    state = %__MODULE__{
      state
      | waypoints: waypoints,
        pending_ops: [op | state.pending_ops]
    }

    notify_subscribers(state.subscribers, {:waypoint_added, waypoint})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:remove_waypoint, waypoint_id}, %__MODULE__{} = state) do
    # Find the waypoint by id in the set, then remove it
    waypoints_list = ORSet.to_list(state.waypoints)

    case Enum.find(waypoints_list, fn wp -> wp.id == waypoint_id end) do
      nil ->
        {:noreply, state}

      waypoint ->
        waypoints = ORSet.remove(state.waypoints, waypoint)
        op = {:remove_waypoint, waypoint}

        state = %__MODULE__{
          state
          | waypoints: waypoints,
            pending_ops: [op | state.pending_ops]
        }

        notify_subscribers(state.subscribers, {:waypoint_removed, waypoint_id})
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:add_annotation, annotation_id, data}, %__MODULE__{} = state) do
    reg =
      case Map.get(state.annotations, annotation_id) do
        nil -> LWWRegister.new(data, state.node_id)
        existing -> LWWRegister.update(existing, data)
      end

    annotations = Map.put(state.annotations, annotation_id, reg)
    op = {:add_annotation, annotation_id, reg}

    state = %__MODULE__{
      state
      | annotations: annotations,
        pending_ops: [op | state.pending_ops]
    }

    notify_subscribers(
      state.subscribers,
      {:annotation_added, annotation_id, data}
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_peers, peers}, %__MODULE__{} = state) do
    {:noreply, %__MODULE__{state | peers: peers}}
  end

  @impl true
  def handle_cast({:receive_delta, _from_node, ops}, %__MODULE__{} = state) do
    state = apply_remote_ops(state, ops)
    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:receive_full_state, _from_node, remote},
        %__MODULE__{} = state
      ) do
    state = merge_full_state(state, remote)
    {:noreply, state}
  end

  @impl true
  def handle_info(:sync, %__MODULE__{} = state) do
    state = broadcast_delta(state)
    {:noreply, schedule_sync(state)}
  end

  @impl true
  def handle_info(:anti_entropy, %__MODULE__{} = state) do
    broadcast_full_state(state)
    {:noreply, schedule_anti_entropy(state)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %__MODULE__{} = state) do
    {:noreply,
     %__MODULE__{state | subscribers: List.delete(state.subscribers, pid)}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("#{__MODULE__} received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # -- Private: Delta sync --

  defp broadcast_delta(%__MODULE__{pending_ops: []} = state), do: state

  defp broadcast_delta(%__MODULE__{} = state) do
    ops = Enum.reverse(state.pending_ops)

    Enum.each(state.peers, fn peer ->
      :rpc.cast(peer, __MODULE__, :receive_delta, [
        __MODULE__,
        state.node_id,
        ops
      ])
    end)

    %__MODULE__{state | pending_ops: []}
  end

  defp broadcast_full_state(%__MODULE__{} = state) do
    full = %{
      entities: state.entities,
      waypoints: state.waypoints,
      annotations: state.annotations
    }

    Enum.each(state.peers, fn peer ->
      :rpc.cast(peer, __MODULE__, :receive_full_state, [
        __MODULE__,
        state.node_id,
        full
      ])
    end)
  end

  defp unwrap_registers(registers) do
    Map.new(registers, fn {id, reg} -> {id, LWWRegister.value(reg)} end)
  end

  defp apply_remote_ops(%__MODULE__{} = state, ops),
    do: Enum.reduce(ops, state, &apply_op/2)

  defp apply_op({:update_entity, entity_id, remote_reg}, %__MODULE__{} = state) do
    local_reg = Map.get(state.entities, entity_id)

    merged =
      if local_reg,
        do: LWWRegister.merge(local_reg, remote_reg),
        else: remote_reg

    %__MODULE__{state | entities: Map.put(state.entities, entity_id, merged)}
  end

  defp apply_op({:add_waypoint, waypoint}, %__MODULE__{} = state) do
    waypoints =
      ORSet.add(
        state.waypoints,
        waypoint,
        Map.get(waypoint, :created_by, :remote)
      )

    %__MODULE__{state | waypoints: waypoints}
  end

  defp apply_op({:remove_waypoint, waypoint}, %__MODULE__{} = state) do
    %__MODULE__{state | waypoints: ORSet.remove(state.waypoints, waypoint)}
  end

  defp apply_op(
         {:add_annotation, annotation_id, remote_reg},
         %__MODULE__{} = state
       ) do
    local_reg = Map.get(state.annotations, annotation_id)

    merged =
      if local_reg,
        do: LWWRegister.merge(local_reg, remote_reg),
        else: remote_reg

    %__MODULE__{
      state
      | annotations: Map.put(state.annotations, annotation_id, merged)
    }
  end

  defp apply_op(_unknown, %__MODULE__{} = state), do: state

  defp merge_full_state(%__MODULE__{} = state, remote) do
    # Merge entities
    entities =
      Map.merge(state.entities, remote.entities, fn _id, local, remote_reg ->
        LWWRegister.merge(local, remote_reg)
      end)

    # Merge waypoints
    waypoints = ORSet.merge(state.waypoints, remote.waypoints)

    # Merge annotations
    annotations =
      Map.merge(state.annotations, remote.annotations, fn _id,
                                                          local,
                                                          remote_reg ->
        LWWRegister.merge(local, remote_reg)
      end)

    %__MODULE__{
      state
      | entities: entities,
        waypoints: waypoints,
        annotations: annotations
    }
  end

  # -- Private: Scheduling --

  defp schedule_sync(%__MODULE__{} = state) do
    _ = if state.sync_ref, do: Process.cancel_timer(state.sync_ref)
    ref = Process.send_after(self(), :sync, state.sync_interval_ms)
    %__MODULE__{state | sync_ref: ref}
  end

  defp schedule_anti_entropy(%__MODULE__{} = state) do
    _ =
      if state.anti_entropy_ref,
        do: Process.cancel_timer(state.anti_entropy_ref)

    ref =
      Process.send_after(self(), :anti_entropy, state.anti_entropy_interval_ms)

    %__MODULE__{state | anti_entropy_ref: ref}
  end

  defp notify_subscribers(subscribers, event) do
    Enum.each(subscribers, fn pid -> send(pid, {:overlay_event, event}) end)
  end
end
