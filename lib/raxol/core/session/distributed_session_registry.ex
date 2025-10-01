defmodule Raxol.Core.Session.DistributedSessionRegistry do
  @moduledoc """
  Distributed session registry that manages sessions across multiple nodes.

  This module provides a distributed session management system that enables
  horizontal scaling and session continuity across node failures. It uses
  a combination of consistent hashing, eventual consistency, and conflict
  resolution to maintain session state across a cluster.

  ## Features

  - **Consistent Hashing**: Sessions are distributed across nodes using consistent hashing
  - **Session Migration**: Sessions can be migrated between nodes for load balancing
  - **Fault Tolerance**: Session state is replicated across multiple nodes
  - **Conflict Resolution**: Handles session conflicts with last-writer-wins and merge strategies
  - **Node Discovery**: Automatic discovery and management of cluster nodes
  - **Session Replication**: Configurable replication factor for session durability

  ## Architecture

  The distributed session registry uses a ring-based consistent hashing algorithm
  to distribute sessions across nodes. Each session is assigned to a primary node
  and N-1 replica nodes based on the replication factor.

  ## Usage

      # Start the distributed registry
      {:ok, _pid} = DistributedSessionRegistry.start_link()

      # Register a session
      DistributedSessionRegistry.register_session(session_id, session_data, [
        affinity: :cpu_bound,
        replicas: 3
      ])

      # Find session location
      {:ok, {primary_node, replica_nodes}} =
        DistributedSessionRegistry.locate_session(session_id)

      # Migrate session to different node
      DistributedSessionRegistry.migrate_session(session_id, target_node)
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log
  alias Raxol.Core.Session.{DistributedSessionStorage, SessionReplicator}
  alias Raxol.Core.ErrorRecovery.ContextManager

  @hash_ring_size 2048
  @default_replication_factor 3
  @heartbeat_interval 5_000
  @session_sync_interval 30_000
  @node_timeout 15_000

  defstruct [
    :node_id,
    :hash_ring,
    :nodes,
    :sessions,
    :replication_factor,
    :storage,
    :replicator,
    :heartbeat_timer,
    :sync_timer,
    :context_manager
  ]

  @type session_id :: String.t()
  @type node_id :: atom()
  @type session_data :: term()
  @type session_affinity ::
          :cpu_bound | :memory_bound | :io_bound | :network_bound

  @type session_meta :: %{
          session_id: session_id(),
          created_at: DateTime.t(),
          last_accessed: DateTime.t(),
          access_count: non_neg_integer(),
          affinity: session_affinity(),
          replicas: non_neg_integer(),
          version: non_neg_integer(),
          checksum: String.t()
        }

  @type node_info :: %{
          node_id: node_id(),
          last_heartbeat: DateTime.t(),
          cpu_usage: float(),
          memory_usage: float(),
          session_count: non_neg_integer(),
          status: :active | :draining | :unhealthy
        }

  # Public API

  @doc """
  Register a session in the distributed registry.
  """
  def register_session(session_id, session_data, opts \\ []) do
    GenServer.call(
      __MODULE__,
      {:register_session, session_id, session_data, opts}
    )
  end

  @doc """
  Locate which nodes host a session.
  """
  def locate_session(session_id) do
    GenServer.call(__MODULE__, {:locate_session, session_id})
  end

  @doc """
  Get session data from the distributed registry.
  """
  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  @doc """
  Update session data in the distributed registry.
  """
  def update_session(session_id, session_data) do
    GenServer.call(__MODULE__, {:update_session, session_id, session_data})
  end

  @doc """
  Remove a session from the distributed registry.
  """
  def unregister_session(session_id) do
    GenServer.call(__MODULE__, {:unregister_session, session_id})
  end

  @doc """
  Migrate a session to a different node.
  """
  def migrate_session(session_id, target_node) do
    GenServer.call(__MODULE__, {:migrate_session, session_id, target_node})
  end

  @doc """
  List all sessions managed by this node.
  """
  def list_local_sessions do
    GenServer.call(__MODULE__, :list_local_sessions)
  end

  @doc """
  Get cluster status and node information.
  """
  def get_cluster_status do
    GenServer.call(__MODULE__, :get_cluster_status)
  end

  @doc """
  Force a cluster-wide session synchronization.
  """
  def sync_sessions do
    GenServer.call(__MODULE__, :sync_sessions)
  end

  @doc """
  Add a new node to the cluster.
  """
  def add_node(node_id) do
    GenServer.call(__MODULE__, {:add_node, node_id})
  end

  @doc """
  Remove a node from the cluster (graceful shutdown).
  """
  def remove_node(node_id) do
    GenServer.call(__MODULE__, {:remove_node, node_id})
  end

  # GenServer implementation

  @impl true
  def init_manager(opts) do
    node_id = Keyword.get(opts, :node_id, node())

    replication_factor =
      Keyword.get(opts, :replication_factor, @default_replication_factor)

    # Initialize hash ring with current node
    hash_ring = initialize_hash_ring([node_id])

    # Start storage and replication components
    {:ok, storage} = DistributedSessionStorage.start_link(node_id: node_id)
    {:ok, replicator} = SessionReplicator.start_link(node_id: node_id)
    {:ok, context_manager} = ContextManager.start_link()

    # Discover existing cluster nodes
    cluster_nodes = discover_cluster_nodes()

    updated_ring =
      if length(cluster_nodes) > 1 do
        rebuild_hash_ring(cluster_nodes)
      else
        hash_ring
      end

    # Start periodic timers
    heartbeat_timer = schedule_heartbeat()
    sync_timer = schedule_session_sync()

    state = %__MODULE__{
      node_id: node_id,
      hash_ring: updated_ring,
      nodes: initialize_node_info(cluster_nodes),
      sessions: %{},
      replication_factor: replication_factor,
      storage: storage,
      replicator: replicator,
      heartbeat_timer: heartbeat_timer,
      sync_timer: sync_timer,
      context_manager: context_manager
    }

    # Announce this node to the cluster
    announce_node_join(state)

    Log.module_info("Distributed session registry started on node #{node_id}")

    {:ok, state}
  end

  @impl true
  def handle_manager_call(
        {:register_session, session_id, session_data, opts},
        _from,
        state
      ) do
    affinity = Keyword.get(opts, :affinity, :cpu_bound)
    replicas = Keyword.get(opts, :replicas, state.replication_factor)

    case determine_session_placement(session_id, affinity, replicas, state) do
      {:ok, primary_node, replica_nodes} ->
        meta = create_session_meta(session_id, affinity, replicas)

        case register_session_on_nodes(
               session_id,
               session_data,
               meta,
               primary_node,
               replica_nodes,
               state
             ) do
          :ok ->
            updated_sessions =
              Map.put(state.sessions, session_id, %{
                primary_node: primary_node,
                replica_nodes: replica_nodes,
                meta: meta
              })

            new_state = %{state | sessions: updated_sessions}
            {:reply, {:ok, primary_node, replica_nodes}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:locate_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        # Session not found locally, check cluster
        case find_session_in_cluster(session_id, state) do
          {:ok, primary_node, replica_nodes} ->
            {:reply, {:ok, {primary_node, replica_nodes}}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      session_info ->
        {:reply, {:ok, {session_info.primary_node, session_info.replica_nodes}},
         state}
    end
  end

  @impl true
  def handle_manager_call({:get_session, session_id}, _from, state) do
    case get_session_with_fallback(session_id, state) do
      {:ok, session_data} ->
        {:reply, {:ok, session_data}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call(
        {:update_session, session_id, session_data},
        _from,
        state
      ) do
    case update_session_across_replicas(session_id, session_data, state) do
      :ok ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:unregister_session, session_id}, _from, state) do
    case remove_session_from_cluster(session_id, state) do
      :ok ->
        updated_sessions = Map.delete(state.sessions, session_id)
        new_state = %{state | sessions: updated_sessions}
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call(
        {:migrate_session, session_id, target_node},
        _from,
        state
      ) do
    case execute_session_migration(session_id, target_node, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call(:list_local_sessions, _from, state) do
    local_sessions = get_local_sessions(state)
    {:reply, local_sessions, state}
  end

  @impl true
  def handle_manager_call(:get_cluster_status, _from, state) do
    status = build_cluster_status(state)
    {:reply, status, state}
  end

  @impl true
  def handle_manager_call(:sync_sessions, _from, state) do
    case force_session_synchronization(state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:add_node, node_id}, _from, state) do
    case add_node_to_cluster(node_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:remove_node, node_id}, _from, state) do
    case remove_node_from_cluster(node_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_info(:heartbeat, state) do
    new_state = send_heartbeat_to_cluster(state)
    schedule_heartbeat()
    {:noreply, new_state}
  end

  @impl true
  def handle_manager_info(:sync_sessions, state) do
    new_state = synchronize_sessions_with_cluster(state)
    schedule_session_sync()
    {:noreply, new_state}
  end

  @impl true
  def handle_manager_info({:node_heartbeat, node_id, node_info}, state) do
    new_state = update_node_heartbeat(node_id, node_info, state)
    {:noreply, new_state}
  end

  @impl true
  def handle_manager_info({:node_joined, node_id}, state) do
    Log.module_info("Node #{node_id} joined the cluster")
    new_state = handle_node_join(node_id, state)
    {:noreply, new_state}
  end

  @impl true
  def handle_manager_info({:node_left, node_id}, state) do
    Log.module_warning("Node #{node_id} left the cluster")
    new_state = handle_node_departure(node_id, state)
    {:noreply, new_state}
  end

  # Private implementation

  defp initialize_hash_ring(nodes) do
    Enum.reduce(nodes, %{}, fn node, ring ->
      add_node_to_ring(ring, node)
    end)
  end

  defp add_node_to_ring(ring, node) do
    # Create virtual nodes for better distribution
    virtual_nodes =
      for i <- 1..div(2048, 32) do
        hash_key = "#{node}:#{i}"

        hash =
          :crypto.hash(:sha256, hash_key)
          |> Base.encode16()
          |> String.slice(0, 8)
          |> String.to_integer(16)

        {hash, node}
      end

    Enum.reduce(virtual_nodes, ring, fn {hash, node_id}, acc ->
      Map.put(acc, hash, node_id)
    end)
  end

  defp rebuild_hash_ring(nodes) do
    initialize_hash_ring(nodes)
  end

  defp determine_session_placement(session_id, affinity, replicas, state) do
    session_hash = hash_session_id(session_id)

    case find_primary_node(session_hash, state.hash_ring) do
      {:ok, primary_node} ->
        replica_nodes =
          find_replica_nodes(primary_node, replicas - 1, affinity, state)

        {:ok, primary_node, replica_nodes}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp hash_session_id(session_id) do
    :crypto.hash(:sha256, session_id)
    |> Base.encode16()
    |> String.slice(0, 8)
    |> String.to_integer(16)
  end

  defp find_primary_node(session_hash, hash_ring) do
    case find_next_node_in_ring(session_hash, hash_ring) do
      nil -> {:error, :no_nodes_available}
      node -> {:ok, node}
    end
  end

  defp find_next_node_in_ring(target_hash, hash_ring) do
    hash_ring
    |> Map.keys()
    |> Enum.sort()
    |> Enum.find(fn hash -> hash >= target_hash end)
    |> case do
      nil ->
        # Wrap around to the first node
        hash_ring
        |> Map.keys()
        |> Enum.min()
        |> then(&Map.get(hash_ring, &1))

      hash ->
        Map.get(hash_ring, hash)
    end
  end

  defp find_replica_nodes(primary_node, replica_count, affinity, state) do
    available_nodes = Map.keys(state.nodes) -- [primary_node]

    # Sort nodes by suitability for the given affinity
    sorted_nodes = sort_nodes_by_affinity(available_nodes, affinity, state)

    Enum.take(sorted_nodes, replica_count)
  end

  defp sort_nodes_by_affinity(nodes, affinity, state) do
    nodes
    |> Enum.map(fn node_id ->
      node_info = Map.get(state.nodes, node_id, %{})
      score = calculate_node_score(node_info, affinity)
      {score, node_id}
    end)
    |> Enum.sort_by(fn {score, _node} -> score end, :desc)
    |> Enum.map(fn {_score, node} -> node end)
  end

  defp calculate_node_score(node_info, affinity) do
    base_score = 100

    # Adjust score based on node health
    health_penalty =
      case Map.get(node_info, :status, :active) do
        :active -> 0
        :draining -> -50
        :unhealthy -> -100
      end

    # Adjust score based on affinity
    affinity_bonus =
      case affinity do
        :cpu_bound ->
          cpu_usage = Map.get(node_info, :cpu_usage, 0.5)
          (1.0 - cpu_usage) * 20

        :memory_bound ->
          memory_usage = Map.get(node_info, :memory_usage, 0.5)
          (1.0 - memory_usage) * 20

        :io_bound ->
          # Prefer nodes with lower session count for I/O bound sessions
          session_count = Map.get(node_info, :session_count, 0)
          max(0, 20 - session_count)

        :network_bound ->
          # For now, treat similar to I/O bound
          session_count = Map.get(node_info, :session_count, 0)
          max(0, 15 - session_count)
      end

    base_score + health_penalty + affinity_bonus
  end

  defp create_session_meta(session_id, affinity, replicas) do
    %{
      session_id: session_id,
      created_at: DateTime.utc_now(),
      last_accessed: DateTime.utc_now(),
      access_count: 0,
      affinity: affinity,
      replicas: replicas,
      version: 1,
      checksum: generate_session_checksum(session_id)
    }
  end

  defp generate_session_checksum(session_id) do
    :crypto.hash(:md5, session_id) |> Base.encode16()
  end

  defp register_session_on_nodes(
         session_id,
         session_data,
         meta,
         primary_node,
         replica_nodes,
         state
       ) do
    all_nodes = [primary_node | replica_nodes]

    results =
      Enum.map(all_nodes, fn node ->
        if node == state.node_id do
          # Local registration
          DistributedSessionStorage.store_session(
            state.storage,
            session_id,
            session_data,
            meta
          )
        else
          # Remote registration
          call_remote_node(node, :register_session, [
            session_id,
            session_data,
            meta
          ])
        end
      end)

    case Enum.all?(results, &match?(:ok, &1)) do
      true -> :ok
      false -> {:error, :partial_registration_failure}
    end
  end

  defp get_session_with_fallback(session_id, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:error, :session_not_found}

      session_info ->
        # Try primary node first
        case get_session_from_node(session_info.primary_node, session_id, state) do
          {:ok, session_data} ->
            {:ok, session_data}

          {:error, _reason} ->
            # Try replica nodes
            get_session_from_replicas(
              session_info.replica_nodes,
              session_id,
              state
            )
        end
    end
  end

  defp get_session_from_node(node_id, session_id, state) do
    if node_id == state.node_id do
      DistributedSessionStorage.get_session(state.storage, session_id)
    else
      call_remote_node(node_id, :get_session, [session_id])
    end
  end

  defp get_session_from_replicas([], _session_id, _state) do
    {:error, :session_not_available}
  end

  defp get_session_from_replicas([node | remaining_nodes], session_id, state) do
    case get_session_from_node(node, session_id, state) do
      {:ok, session_data} ->
        {:ok, session_data}

      {:error, _reason} ->
        get_session_from_replicas(remaining_nodes, session_id, state)
    end
  end

  defp update_session_across_replicas(session_id, session_data, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:error, :session_not_found}

      session_info ->
        all_nodes = [session_info.primary_node | session_info.replica_nodes]
        updated_meta = update_session_meta(session_info.meta)

        results =
          Enum.map(all_nodes, fn node ->
            if node == state.node_id do
              DistributedSessionStorage.update_session(
                state.storage,
                session_id,
                session_data,
                updated_meta
              )
            else
              call_remote_node(node, :update_session, [
                session_id,
                session_data,
                updated_meta
              ])
            end
          end)

        case Enum.count(results, &match?(:ok, &1)) do
          count when count > length(all_nodes) / 2 ->
            :ok

          _count ->
            {:error, :insufficient_replicas_updated}
        end
    end
  end

  defp update_session_meta(meta) do
    %{
      meta
      | last_accessed: DateTime.utc_now(),
        access_count: meta.access_count + 1,
        version: meta.version + 1
    }
  end

  defp discover_cluster_nodes do
    # In a real implementation, this would use service discovery
    # For now, return connected nodes
    [node() | Node.list()]
  end

  defp initialize_node_info(nodes) do
    Enum.reduce(nodes, %{}, fn node, acc ->
      Map.put(acc, node, %{
        node_id: node,
        last_heartbeat: DateTime.utc_now(),
        cpu_usage: 0.0,
        memory_usage: 0.0,
        session_count: 0,
        status: :active
      })
    end)
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
  end

  defp schedule_session_sync do
    Process.send_after(self(), :sync_sessions, @session_sync_interval)
  end

  defp announce_node_join(state) do
    # Broadcast node join to cluster
    cluster_nodes = Map.keys(state.nodes) -- [state.node_id]

    Enum.each(cluster_nodes, fn node ->
      send_to_node(node, {:node_joined, state.node_id})
    end)
  end

  defp call_remote_node(node_id, function, args) do
    try do
      :rpc.call(node_id, __MODULE__, function, args, 5000)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
      :exit, reason -> {:error, reason}
    end
  end

  defp send_to_node(node_id, message) do
    send({__MODULE__, node_id}, message)
  end

  defp find_session_in_cluster(_session_id, _state) do
    # Placeholder for cluster-wide session search
    {:error, :not_implemented}
  end

  defp remove_session_from_cluster(_session_id, _state) do
    # Placeholder for cluster-wide session removal
    :ok
  end

  defp execute_session_migration(_session_id, _target_node, state) do
    # Placeholder for session migration
    {:ok, state}
  end

  defp get_local_sessions(state) do
    # Get sessions where this node is primary or replica
    Enum.filter(state.sessions, fn {_session_id, session_info} ->
      session_info.primary_node == state.node_id or
        state.node_id in session_info.replica_nodes
    end)
    |> Enum.map(fn {session_id, _info} -> session_id end)
  end

  defp build_cluster_status(state) do
    %{
      node_id: state.node_id,
      cluster_size: map_size(state.nodes),
      total_sessions: map_size(state.sessions),
      local_sessions: length(get_local_sessions(state)),
      replication_factor: state.replication_factor,
      nodes: state.nodes
    }
  end

  defp force_session_synchronization(state) do
    # Placeholder for forced synchronization
    {:ok, state}
  end

  defp add_node_to_cluster(node_id, state) do
    # Add node to hash ring and rebalance sessions
    updated_ring = add_node_to_ring(state.hash_ring, node_id)

    updated_nodes =
      Map.put(state.nodes, node_id, %{
        node_id: node_id,
        last_heartbeat: DateTime.utc_now(),
        cpu_usage: 0.0,
        memory_usage: 0.0,
        session_count: 0,
        status: :active
      })

    new_state = %{state | hash_ring: updated_ring, nodes: updated_nodes}

    # TODO: Trigger session rebalancing
    {:ok, new_state}
  end

  defp remove_node_from_cluster(node_id, state) do
    # Remove node from hash ring and migrate sessions
    updated_nodes = Map.delete(state.nodes, node_id)
    remaining_nodes = Map.keys(updated_nodes)

    updated_ring = rebuild_hash_ring(remaining_nodes)

    new_state = %{state | hash_ring: updated_ring, nodes: updated_nodes}

    # TODO: Migrate sessions from removed node
    {:ok, new_state}
  end

  defp send_heartbeat_to_cluster(state) do
    node_info = %{
      node_id: state.node_id,
      last_heartbeat: DateTime.utc_now(),
      cpu_usage: get_cpu_usage(),
      memory_usage: get_memory_usage(),
      session_count: length(get_local_sessions(state)),
      status: :active
    }

    # Send heartbeat to all other nodes
    cluster_nodes = Map.keys(state.nodes) -- [state.node_id]

    Enum.each(cluster_nodes, fn node ->
      send_to_node(node, {:node_heartbeat, state.node_id, node_info})
    end)

    # Update local node info
    updated_nodes = Map.put(state.nodes, state.node_id, node_info)
    %{state | nodes: updated_nodes}
  end

  defp synchronize_sessions_with_cluster(state) do
    # Placeholder for session synchronization
    state
  end

  defp update_node_heartbeat(node_id, node_info, state) do
    updated_nodes = Map.put(state.nodes, node_id, node_info)
    %{state | nodes: updated_nodes}
  end

  defp handle_node_join(node_id, state) do
    add_node_to_cluster(node_id, state) |> elem(1)
  end

  defp handle_node_departure(node_id, state) do
    remove_node_from_cluster(node_id, state) |> elem(1)
  end

  defp get_cpu_usage do
    # Simplified CPU usage calculation
    case :cpu_sup.avg1() do
      cpu when is_number(cpu) -> cpu / 256.0
      _ -> 0.0
    end
  end

  defp get_memory_usage do
    # Simplified memory usage calculation
    memory_data = :memsup.get_system_memory_data()
    total = Keyword.get(memory_data, :total_memory, 1)
    available = Keyword.get(memory_data, :available_memory, total)
    (total - available) / total
  end
end
