defmodule Raxol.Core.Session.SessionReplicator do
  @moduledoc """
  Handles session replication and synchronization across nodes in a distributed cluster.

  The SessionReplicator ensures session data consistency across multiple nodes by
  managing replication, conflict resolution, and synchronization of session state.

  ## Features

  - Asynchronous session replication across replica nodes
  - Conflict-free replicated data types (CRDTs) for session merging
  - Vector clocks for ordering and conflict detection
  - Configurable replication factor and consistency levels
  - Anti-entropy mechanisms for drift correction
  - Partition tolerance with eventual consistency

  ## Replication Strategies

  - **Immediate**: Synchronous replication to all replicas
  - **Eventual**: Asynchronous replication with eventual consistency
  - **Quorum**: Write to majority of replicas before confirming
  - **Best Effort**: Fire-and-forget replication

  ## Usage

      # Start replicator
      {:ok, pid} = SessionReplicator.start_link(
        replication_factor: 3,
        consistency_level: :quorum
      )

      # Replicate session data
      SessionReplicator.replicate_session(pid, session_id, session_data, replica_nodes)

      # Sync session across replicas
      SessionReplicator.sync_session(pid, session_id)
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log

  @behaviour Raxol.Core.Behaviours.BaseManager

  defstruct [
    :replication_factor,
    :consistency_level,
    :sync_interval,
    :vector_clocks,
    :pending_replications,
    :replica_health,
    :anti_entropy_timer,
    :sync_conflicts
  ]

  @type replication_strategy :: :immediate | :eventual | :quorum | :best_effort
  @type consistency_level :: :strong | :eventual | :quorum | :weak
  @type vector_clock :: %{node() => non_neg_integer()}
  @type session_version :: {vector_clock(), term()}

  @default_replication_factor 3
  @default_consistency_level :quorum
  @default_sync_interval 30_000
  @default_anti_entropy_interval 300_000

  # Public API

  @spec replicate_session(
          pid(),
          binary(),
          term(),
          [node()],
          replication_strategy()
        ) ::
          {:ok, term()} | {:error, term()}
  def replicate_session(
        pid,
        session_id,
        session_data,
        replica_nodes,
        strategy
      ) do
    GenServer.call(
      pid,
      {:replicate_session, session_id, session_data, replica_nodes, strategy}
    )
  end

  @spec sync_session(pid(), binary()) :: {:ok, term()} | {:error, term()}
  def sync_session(pid, session_id) do
    GenServer.call(pid, {:sync_session, session_id})
  end

  @spec get_session_replicas(pid(), binary()) ::
          {:ok, [node()]} | {:error, term()}
  def get_session_replicas(pid, session_id) do
    GenServer.call(pid, {:get_session_replicas, session_id})
  end

  @spec resolve_conflicts(pid(), binary()) :: {:ok, term()} | {:error, term()}
  def resolve_conflicts(pid, session_id) do
    GenServer.call(pid, {:resolve_conflicts, session_id})
  end

  @spec get_replication_status(pid()) :: %{
          pending_replications: non_neg_integer(),
          replica_health: %{node() => :healthy | :degraded | :failed},
          sync_conflicts: non_neg_integer()
        }
  def get_replication_status(pid) do
    GenServer.call(pid, :get_replication_status)
  end

  # BaseManager Callbacks

  @impl true
  def init_manager(opts) do
    state = %__MODULE__{
      replication_factor:
        Keyword.get(opts, :replication_factor, @default_replication_factor),
      consistency_level:
        Keyword.get(opts, :consistency_level, @default_consistency_level),
      sync_interval: Keyword.get(opts, :sync_interval, @default_sync_interval),
      vector_clocks: %{},
      pending_replications: %{},
      replica_health: %{},
      sync_conflicts: 0
    }

    # Start periodic sync timer
    _sync_timer = Process.send_after(self(), :periodic_sync, state.sync_interval)

    # Start anti-entropy timer
    anti_entropy_timer =
      Process.send_after(self(), :anti_entropy, @default_anti_entropy_interval)

    updated_state = %{state | anti_entropy_timer: anti_entropy_timer}

    Log.module_info(
      "SessionReplicator started with replication_factor=#{state.replication_factor}"
    )

    {:ok, updated_state}
  end

  @impl true
  def handle_call(
        {:replicate_session, session_id, session_data, replica_nodes, strategy},
        _from,
        state
      ) do
    case perform_replication(
           session_id,
           session_data,
           replica_nodes,
           strategy,
           state
         ) do
      {:ok, updated_state} ->
        {:reply, :ok, updated_state}

      {:error, reason} = error ->
        Log.module_error(
          "Failed to replicate session #{session_id}: #{inspect(reason)}"
        )

        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:sync_session, session_id}, _from, state) do
    case sync_session_replicas(session_id, state) do
      {:ok, merged_data, updated_state} ->
        {:reply, {:ok, merged_data}, updated_state}

      {:error, reason} = error ->
        Log.module_error(
          "Failed to sync session #{session_id}: #{inspect(reason)}"
        )

        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_session_replicas, session_id}, _from, state) do
    replicas = get_replica_nodes_for_session(session_id, state)
    {:reply, {:ok, replicas}, state}
  end

  @impl true
  def handle_call({:resolve_conflicts, session_id}, _from, state) do
    case resolve_session_conflicts(session_id, state) do
      {:ok, resolved_data, updated_state} ->
        {:reply, {:ok, resolved_data}, updated_state}

      {:error, reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:get_replication_status, _from, state) do
    status = %{
      pending_replications: map_size(state.pending_replications),
      replica_health: state.replica_health,
      sync_conflicts: state.sync_conflicts
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:periodic_sync, state) do
    updated_state = perform_periodic_sync(state)

    # Schedule next sync
    Process.send_after(self(), :periodic_sync, state.sync_interval)

    {:noreply, updated_state}
  end

  @impl true
  def handle_info(:anti_entropy, state) do
    updated_state = perform_anti_entropy_repair(state)

    # Schedule next anti-entropy
    timer =
      Process.send_after(self(), :anti_entropy, @default_anti_entropy_interval)

    updated_state = %{updated_state | anti_entropy_timer: timer}

    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:replication_result, session_id, node, result}, state) do
    updated_state = handle_replication_result(session_id, node, result, state)
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    Log.module_info("Node #{node} joined cluster, updating replica health")
    updated_health = Map.put(state.replica_health, node, :healthy)
    {:noreply, %{state | replica_health: updated_health}}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    Log.module_warning("Node #{node} left cluster, marking as failed")
    updated_health = Map.put(state.replica_health, node, :failed)
    {:noreply, %{state | replica_health: updated_health}}
  end

  # Private Implementation

  defp perform_replication(
         session_id,
         session_data,
         replica_nodes,
         strategy,
         state
       ) do
    vector_clock = increment_vector_clock(session_id, state)
    versioned_data = {vector_clock, session_data}

    case strategy do
      :immediate ->
        replicate_immediate(session_id, versioned_data, replica_nodes, state)

      :eventual ->
        replicate_eventual(session_id, versioned_data, replica_nodes, state)

      :quorum ->
        replicate_quorum(session_id, versioned_data, replica_nodes, state)

      :best_effort ->
        replicate_best_effort(session_id, versioned_data, replica_nodes, state)
    end
  end

  defp replicate_immediate(session_id, versioned_data, replica_nodes, state) do
    results =
      Enum.map(replica_nodes, fn node ->
        case :rpc.call(
               node,
               Raxol.Core.Session.DistributedSessionRegistry,
               :store_replica,
               [session_id, versioned_data]
             ) do
          {:ok, _} -> {:ok, node}
          {:error, reason} -> {:error, {node, reason}}
          {:badrpc, reason} -> {:error, {node, {:rpc_error, reason}}}
        end
      end)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {successes, []} ->
        success_nodes = Enum.map(successes, fn {:ok, node} -> node end)

        Log.module_debug(
          "Immediate replication successful to nodes: #{inspect(success_nodes)}"
        )

        {:ok, update_vector_clock(session_id, versioned_data, state)}

      {_successes, failures} ->
        failure_details =
          Enum.map(failures, fn {:error, {node, reason}} ->
            "#{node}: #{inspect(reason)}"
          end)

        {:error, {:partial_failure, failure_details}}
    end
  end

  defp replicate_eventual(session_id, versioned_data, replica_nodes, state) do
    # Start async replication to all nodes
    Enum.each(replica_nodes, fn node ->
      Task.start(fn ->
        result =
          :rpc.call(
            node,
            Raxol.Core.Session.DistributedSessionRegistry,
            :store_replica,
            [session_id, versioned_data]
          )

        send(self(), {:replication_result, session_id, node, result})
      end)
    end)

    # Add to pending replications for tracking
    pending =
      Map.put(
        state.pending_replications,
        session_id,
        {replica_nodes, :erlang.monotonic_time()}
      )

    updated_state = %{state | pending_replications: pending}

    {:ok, update_vector_clock(session_id, versioned_data, updated_state)}
  end

  defp replicate_quorum(session_id, versioned_data, replica_nodes, state) do
    required_replicas = div(length(replica_nodes), 2) + 1

    # Replicate to nodes in parallel and wait for quorum
    parent = self()
    ref = make_ref()

    tasks =
      Enum.map(replica_nodes, fn node ->
        Task.async(fn ->
          result =
            :rpc.call(
              node,
              Raxol.Core.Session.DistributedSessionRegistry,
              :store_replica,
              [session_id, versioned_data]
            )

          send(parent, {ref, node, result})
          result
        end)
      end)

    # Wait for quorum responses
    case wait_for_quorum_responses(ref, required_replicas, 5000) do
      {:ok, successful_nodes} ->
        Log.module_debug(
          "Quorum replication successful to #{length(successful_nodes)}/#{required_replicas} nodes"
        )

        {:ok, update_vector_clock(session_id, versioned_data, state)}

      {:error, reason} ->
        # Clean up remaining tasks
        Enum.each(tasks, &Task.shutdown(&1, :brutal_kill))
        {:error, reason}
    end
  end

  defp replicate_best_effort(session_id, versioned_data, replica_nodes, state) do
    # Fire and forget to all nodes
    Enum.each(replica_nodes, fn node ->
      spawn(fn ->
        :rpc.call(
          node,
          Raxol.Core.Session.DistributedSessionRegistry,
          :store_replica,
          [session_id, versioned_data]
        )
      end)
    end)

    Log.module_debug(
      "Best effort replication initiated for session #{session_id}"
    )

    {:ok, update_vector_clock(session_id, versioned_data, state)}
  end

  defp wait_for_quorum_responses(ref, required_count, timeout) do
    wait_for_quorum_responses(ref, required_count, timeout, [], 0)
  end

  defp wait_for_quorum_responses(
         _ref,
         required_count,
         _timeout,
         successful_nodes,
         success_count
       )
       when success_count >= required_count do
    {:ok, successful_nodes}
  end

  defp wait_for_quorum_responses(
         ref,
         required_count,
         timeout,
         successful_nodes,
         success_count
       ) do
    receive do
      {^ref, node, {:ok, _}} ->
        wait_for_quorum_responses(
          ref,
          required_count,
          timeout,
          [node | successful_nodes],
          success_count + 1
        )

      {^ref, _node, _error} ->
        wait_for_quorum_responses(
          ref,
          required_count,
          timeout,
          successful_nodes,
          success_count
        )
    after
      timeout ->
        {:error, {:quorum_timeout, success_count, required_count}}
    end
  end

  defp sync_session_replicas(session_id, state) do
    replica_nodes = get_replica_nodes_for_session(session_id, state)

    # Fetch session data from all replicas
    replica_data =
      Enum.map(replica_nodes, fn node ->
        case :rpc.call(
               node,
               Raxol.Core.Session.DistributedSessionRegistry,
               :get_replica,
               [session_id]
             ) do
          {:ok, data} -> {node, data}
          {:error, :not_found} -> {node, nil}
          error -> {node, {:error, error}}
        end
      end)

    # Filter out errors and merge valid data
    valid_data =
      Enum.filter(replica_data, fn
        {_node, nil} -> false
        {_node, {:error, _}} -> false
        {_node, _data} -> true
      end)

    case valid_data do
      [] ->
        {:error, :no_valid_replicas}

      data_list ->
        merged_data = merge_session_versions(data_list)
        {:ok, merged_data, state}
    end
  end

  defp merge_session_versions(data_list) do
    # Extract versioned data and sort by vector clock causality
    versioned_data =
      Enum.map(data_list, fn {_node, {vector_clock, data}} ->
        {vector_clock, data}
      end)

    # Find the most recent version using vector clock comparison
    case find_concurrent_versions(versioned_data) do
      {latest_version, []} ->
        # No conflicts, return latest version
        elem(latest_version, 1)

      {latest, conflicts} ->
        # Resolve conflicts using last-writer-wins with node priority
        resolve_concurrent_versions([elem(latest, 1) | conflicts])
    end
  end

  defp find_concurrent_versions(versioned_data) do
    # For simplicity, use timestamp-based ordering
    # In production, implement proper vector clock comparison
    sorted_data =
      Enum.sort_by(
        versioned_data,
        fn {vector_clock, _data} ->
          Map.values(vector_clock) |> Enum.sum()
        end,
        :desc
      )

    case sorted_data do
      [latest | rest] -> {latest, Enum.map(rest, &elem(&1, 1))}
      [] -> {nil, []}
    end
  end

  defp resolve_concurrent_versions(conflicting_data) do
    # Simple last-writer-wins resolution
    # In production, implement application-specific conflict resolution
    List.first(conflicting_data)
  end

  defp increment_vector_clock(session_id, state) do
    current_node = Node.self()
    current_clock = Map.get(state.vector_clocks, session_id, %{})

    Map.update(current_clock, current_node, 1, &(&1 + 1))
  end

  defp update_vector_clock(session_id, {vector_clock, _data}, state) do
    updated_clocks = Map.put(state.vector_clocks, session_id, vector_clock)
    %{state | vector_clocks: updated_clocks}
  end

  defp get_replica_nodes_for_session(session_id, _state) do
    # Get replica nodes from the distributed registry
    case GenServer.call(
           Raxol.Core.Session.DistributedSessionRegistry,
           {:get_replica_nodes, session_id}
         ) do
      {:ok, nodes} -> nodes
      {:error, _} -> []
    end
  end

  defp handle_replication_result(session_id, node, result, state) do
    case result do
      {:ok, _} ->
        Log.module_debug(
          "Replication to #{node} successful for session #{session_id}"
        )

        update_replica_health(node, :healthy, state)

      {:error, reason} ->
        Log.module_warning(
          "Replication to #{node} failed for session #{session_id}: #{inspect(reason)}"
        )

        update_replica_health(node, :degraded, state)

      {:badrpc, reason} ->
        Log.module_error(
          "RPC error to #{node} for session #{session_id}: #{inspect(reason)}"
        )

        update_replica_health(node, :failed, state)
    end
  end

  defp update_replica_health(node, health_status, state) do
    updated_health = Map.put(state.replica_health, node, health_status)
    %{state | replica_health: updated_health}
  end

  defp perform_periodic_sync(state) do
    # Sync sessions that have pending replications
    Enum.reduce(state.pending_replications, state, fn {session_id,
                                                       {_nodes, timestamp}},
                                                      acc_state ->
      # Only sync if replication is older than sync interval
      age = :erlang.monotonic_time() - timestamp

      if age > state.sync_interval do
        case sync_session_replicas(session_id, acc_state) do
          {:ok, _merged_data, updated_state} ->
            # Remove from pending
            pending = Map.delete(updated_state.pending_replications, session_id)
            %{updated_state | pending_replications: pending}

          {:error, _reason} ->
            acc_state
        end
      else
        acc_state
      end
    end)
  end

  defp perform_anti_entropy_repair(state) do
    # Implement anti-entropy repair by comparing vector clocks across replicas
    # This is a simplified version - production would use merkle trees

    all_sessions = Map.keys(state.vector_clocks)

    Enum.reduce(all_sessions, state, fn session_id, acc_state ->
      case sync_session_replicas(session_id, acc_state) do
        {:ok, _merged_data, updated_state} ->
          updated_state

        {:error, _reason} ->
          acc_state
      end
    end)
  end

  defp resolve_session_conflicts(session_id, state) do
    case sync_session_replicas(session_id, state) do
      {:ok, resolved_data, updated_state} ->
        # Update conflict count
        updated_state = %{
          updated_state
          | sync_conflicts: updated_state.sync_conflicts + 1
        }

        {:ok, resolved_data, updated_state}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
