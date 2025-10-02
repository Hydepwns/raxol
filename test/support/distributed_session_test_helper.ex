defmodule Raxol.Test.DistributedSessionTestHelper do
  @moduledoc """
  Test helper module for distributed session system testing.

  Provides utilities for testing distributed session management, including
  cluster simulation, session migration testing, and fault injection scenarios.

  ## Features

  - Multi-node cluster simulation
  - Session lifecycle testing utilities
  - Migration and failover scenario builders
  - Performance testing helpers
  - Consistency verification tools
  - Fault injection capabilities

  ## Usage

      use Raxol.Test.DistributedSessionTestHelper

      test "session migration works correctly" do
        cluster = create_test_cluster(3)
        session_id = create_test_session(cluster.primary_node)

        assert {:ok, _} = migrate_session(session_id, cluster.secondary_node)
        assert_session_migrated(session_id, cluster.secondary_node)

        cleanup_test_cluster(cluster)
      end
  """

  import ExUnit.Assertions

  alias Raxol.Core.Session.{
    DistributedSessionRegistry,
    SessionReplicator,
    DistributedSessionStorage,
    SessionMigrator
  }

  alias Raxol.Core.Runtime.Log

  defmacro __using__(_opts) do
    quote do
      import Raxol.Test.DistributedSessionTestHelper

      alias Raxol.Test.DistributedSessionTestHelper.{
        TestCluster,
        SessionBuilder,
        FaultInjector
      }

      setup_all do
        # Ensure required applications are started
        Application.ensure_all_started(:raxol)
        :ok
      end
    end
  end

  # Test Cluster Management

  defmodule TestCluster do
    @moduledoc """
    Represents a test cluster configuration.
    """

    defstruct [
      :primary_node,
      :secondary_nodes,
      :all_nodes,
      :registry_pids,
      :storage_pids,
      :replicator_pids,
      :migrator_pids,
      :cluster_config
    ]

    @type t :: %__MODULE__{
            primary_node: node(),
            secondary_nodes: [node()],
            all_nodes: [node()],
            registry_pids: %{node() => pid()},
            storage_pids: %{node() => pid()},
            replicator_pids: %{node() => pid()},
            migrator_pids: %{node() => pid()},
            cluster_config: map()
          }
  end

  def create_test_cluster(node_count \\ 3, opts \\ []) do
    cluster_config = %{
      replication_factor: Keyword.get(opts, :replication_factor, 2),
      storage_backend: Keyword.get(opts, :storage_backend, :ets),
      consistency_level: Keyword.get(opts, :consistency_level, :quorum),
      migration_strategy: Keyword.get(opts, :migration_strategy, :hot)
    }

    # Generate test node names
    all_nodes = for i <- 1..node_count, do: :"test_node_#{i}@test"
    [primary_node | secondary_nodes] = all_nodes

    # Start distributed session components on each "node"
    {registry_pids, storage_pids, replicator_pids, migrator_pids} =
      Enum.reduce(all_nodes, {%{}, %{}, %{}, %{}}, fn node,
                                                      {reg_acc, stor_acc,
                                                       repl_acc, migr_acc} ->
        # Start registry
        {:ok, registry_pid} =
          DistributedSessionRegistry.start_link(
            name: :"registry_#{node}",
            cluster_nodes: all_nodes,
            replication_factor: cluster_config.replication_factor
          )

        # Start storage
        {:ok, storage_pid} =
          DistributedSessionStorage.start_link(
            name: :"storage_#{node}",
            backend: cluster_config.storage_backend,
            shard_count: 8
          )

        # Start replicator
        {:ok, replicator_pid} =
          SessionReplicator.start_link(
            name: :"replicator_#{node}",
            replication_factor: cluster_config.replication_factor,
            consistency_level: cluster_config.consistency_level
          )

        # Start migrator
        {:ok, migrator_pid} =
          SessionMigrator.start_link(
            name: :"migrator_#{node}",
            failover_mode: :graceful,
            migration_batch_size: 5
          )

        {
          Map.put(reg_acc, node, registry_pid),
          Map.put(stor_acc, node, storage_pid),
          Map.put(repl_acc, node, replicator_pid),
          Map.put(migr_acc, node, migrator_pid)
        }
      end)

    cluster = %TestCluster{
      primary_node: primary_node,
      secondary_nodes: secondary_nodes,
      all_nodes: all_nodes,
      registry_pids: registry_pids,
      storage_pids: storage_pids,
      replicator_pids: replicator_pids,
      migrator_pids: migrator_pids,
      cluster_config: cluster_config
    }

    # Wait for cluster to stabilize
    Process.sleep(100)

    Log.console("Created test cluster with #{node_count} nodes")
    cluster
  end

  def cleanup_test_cluster(%TestCluster{} = cluster) do
    # Stop all processes
    all_pids =
      Map.values(cluster.registry_pids) ++
        Map.values(cluster.storage_pids) ++
        Map.values(cluster.replicator_pids) ++
        Map.values(cluster.migrator_pids)

    Enum.each(all_pids, fn pid ->
      if Process.alive?(pid) do
        GenServer.stop(pid, :normal, 1000)
      end
    end)

    # Wait for cleanup
    Process.sleep(50)
    Log.console("Cleaned up test cluster")
  end

  # Session Testing Utilities

  defmodule SessionBuilder do
    @moduledoc """
    Utilities for creating test sessions.
    """

    def create_simple_session(session_id \\ nil) do
      session_id = session_id || generate_session_id()

      session_data = %{
        user_id: "test_user_#{:rand.uniform(1000)}",
        created_at: DateTime.utc_now(),
        terminal_state: %{
          cursor: {10, 5},
          screen_buffer: generate_screen_buffer(),
          environment: %{"TERM" => "xterm-256color"}
        },
        metadata: %{
          session_type: :terminal,
          authenticated: true
        }
      }

      {session_id, session_data}
    end

    def create_complex_session(session_id \\ nil) do
      session_id = session_id || generate_session_id()

      session_data = %{
        user_id: "complex_user_#{:rand.uniform(1000)}",
        created_at: DateTime.utc_now(),
        terminal_state: %{
          tabs: generate_tab_sessions(3),
          splits: generate_split_configuration(),
          active_tab: 0,
          theme: "dark_theme"
        },
        web_state: %{
          websocket_connections: generate_websocket_connections(2),
          session_tokens: generate_session_tokens(5)
        },
        security_context: %{
          permissions: ["read", "write", "execute"],
          mfa_verified: true,
          last_activity: DateTime.utc_now()
        },
        metadata: %{
          session_type: :multiplexed,
          complexity_level: :high,
          data_size: :large
        }
      }

      {session_id, session_data}
    end

    def create_session_batch(count, complexity \\ :simple) do
      for _ <- 1..count do
        case complexity do
          :simple -> create_simple_session()
          :complex -> create_complex_session()
        end
      end
    end

    defp generate_session_id do
      "test_session_#{:erlang.unique_integer([:positive])}"
    end

    defp generate_screen_buffer do
      for row <- 1..24 do
        for col <- 1..80, do: {row, col, " ", %{fg: :white, bg: :black}}
      end
    end

    defp generate_tab_sessions(count) do
      for i <- 1..count do
        %{
          id: i,
          title: "Tab #{i}",
          active: i == 1,
          process_id: :rand.uniform(10000),
          working_directory: "/tmp/test_#{i}"
        }
      end
    end

    defp generate_split_configuration do
      %{
        layout: :vertical,
        splits: [
          %{id: 1, size: 0.6, active: true},
          %{id: 2, size: 0.4, active: false}
        ]
      }
    end

    defp generate_websocket_connections(count) do
      for i <- 1..count do
        %{
          id: "ws_#{i}",
          connected_at: DateTime.utc_now(),
          last_ping: DateTime.utc_now(),
          client_info: %{user_agent: "TestClient/1.0"}
        }
      end
    end

    defp generate_session_tokens(count) do
      for _ <- 1..count do
        :crypto.strong_rand_bytes(32) |> Base.encode64()
      end
    end
  end

  def create_test_session(
        %TestCluster{} = cluster,
        _complexity \\ :simple,
        target_node \\ nil
      ) do
    target_node = target_node || cluster.primary_node
    {session_id, session_data} = SessionBuilder.create_simple_session()

    # Store session on target node
    storage_pid = Map.get(cluster.storage_pids, target_node)
    registry_pid = Map.get(cluster.registry_pids, target_node)

    :ok =
      DistributedSessionStorage.store(
        storage_pid,
        session_id,
        session_data,
        %{}
      )

    :ok =
      DistributedSessionRegistry.register_session(
        registry_pid,
        session_id,
        target_node
      )

    {session_id, session_data}
  end

  def create_test_session_batch(
        %TestCluster{} = cluster,
        count,
        complexity \\ :simple
      ) do
    sessions = SessionBuilder.create_session_batch(count, complexity)

    # Distribute sessions across cluster nodes
    cluster.all_nodes
    |> Enum.with_index()
    |> Enum.flat_map(fn {node, node_index} ->
      node_sessions =
        Enum.filter(sessions, fn {_session_id, _data} ->
          rem(:erlang.phash2({node, node_index}), length(cluster.all_nodes)) ==
            node_index
        end)

      storage_pid = Map.get(cluster.storage_pids, node)
      registry_pid = Map.get(cluster.registry_pids, node)

      Enum.map(node_sessions, fn {session_id, session_data} ->
        :ok =
          DistributedSessionStorage.store(
            storage_pid,
            session_id,
            session_data,
            %{}
          )

        :ok =
          DistributedSessionRegistry.register_session(
            registry_pid,
            session_id,
            node
          )

        {session_id, node}
      end)
    end)
  end

  # Migration Testing

  def migrate_session(
        %TestCluster{} = cluster,
        session_id,
        target_node,
        strategy \\ :hot
      ) do
    migrator_pid = Map.get(cluster.migrator_pids, cluster.primary_node)

    SessionMigrator.migrate_session(
      migrator_pid,
      session_id,
      target_node,
      strategy
    )
  end

  def migrate_session_batch(
        %TestCluster{} = cluster,
        session_ids,
        target_node,
        strategy \\ :bulk
      ) do
    migrator_pid = Map.get(cluster.migrator_pids, cluster.primary_node)

    SessionMigrator.migrate_sessions_bulk(
      migrator_pid,
      session_ids,
      target_node,
      strategy
    )
  end

  def evacuate_node(%TestCluster{} = cluster, source_node) do
    target_nodes = cluster.all_nodes -- [source_node]
    migrator_pid = Map.get(cluster.migrator_pids, cluster.primary_node)
    SessionMigrator.evacuate_node(migrator_pid, source_node, target_nodes)
  end

  # Assertion Helpers

  def assert_session_exists(%TestCluster{} = cluster, session_id) do
    case find_session_location(cluster, session_id) do
      {:ok, _node} ->
        :ok

      {:error, :not_found} ->
        flunk("Session #{session_id} not found in cluster")
    end
  end

  def assert_session_on_node(
        %TestCluster{} = cluster,
        session_id,
        expected_node
      ) do
    case find_session_location(cluster, session_id) do
      {:ok, ^expected_node} ->
        :ok

      {:ok, actual_node} ->
        flunk(
          "Session #{session_id} found on #{actual_node}, expected #{expected_node}"
        )

      {:error, :not_found} ->
        flunk("Session #{session_id} not found in cluster")
    end
  end

  def assert_session_migrated(
        %TestCluster{} = cluster,
        session_id,
        target_node,
        timeout \\ 5000
      ) do
    end_time = :erlang.monotonic_time(:millisecond) + timeout

    wait_for_migration_completion(cluster, session_id, target_node, end_time)
  end

  def assert_session_replicated(
        %TestCluster{} = cluster,
        session_id,
        expected_replica_count
      ) do
    replica_count = count_session_replicas(cluster, session_id)

    assert replica_count >= expected_replica_count,
           "Session #{session_id} has #{replica_count} replicas, expected at least #{expected_replica_count}"
  end

  def assert_session_data_consistency(%TestCluster{} = cluster, session_id) do
    replica_data = get_all_session_replicas(cluster, session_id)

    case replica_data do
      [] ->
        flunk("No replicas found for session #{session_id}")

      [first_data | rest] ->
        inconsistent_replicas =
          Enum.filter(rest, fn data -> data != first_data end)

        assert inconsistent_replicas == [],
               "Session #{session_id} has inconsistent replicas: #{inspect(inconsistent_replicas)}"
    end
  end

  def assert_cluster_consistency(%TestCluster{} = cluster, _timeout \\ 10000) do
    # Wait for all pending operations to complete
    Process.sleep(100)

    # Verify registry consistency across nodes
    registry_states = get_all_registry_states(cluster)
    session_locations = merge_registry_states(registry_states)

    # Check for conflicts
    conflicts = find_session_location_conflicts(session_locations)

    assert conflicts == [],
           "Cluster has session location conflicts: #{inspect(conflicts)}"

    # Verify storage consistency
    storage_sessions = get_all_storage_sessions(cluster)

    orphaned_sessions =
      find_orphaned_sessions(session_locations, storage_sessions)

    assert orphaned_sessions == [],
           "Cluster has orphaned sessions: #{inspect(orphaned_sessions)}"
  end

  # Fault Injection

  defmodule FaultInjector do
    @moduledoc """
    Utilities for injecting faults into the distributed session system.
    """

    def simulate_node_failure(%TestCluster{} = cluster, target_node) do
      # Stop all processes on the target node
      node_pids = [
        Map.get(cluster.registry_pids, target_node),
        Map.get(cluster.storage_pids, target_node),
        Map.get(cluster.replicator_pids, target_node),
        Map.get(cluster.migrator_pids, target_node)
      ]

      Enum.each(node_pids, fn pid ->
        if pid && Process.alive?(pid) do
          Process.exit(pid, :kill)
        end
      end)

      # Notify remaining nodes about the failure
      remaining_nodes = cluster.all_nodes -- [target_node]

      Enum.each(remaining_nodes, fn node ->
        migrator_pid = Map.get(cluster.migrator_pids, node)

        if migrator_pid && Process.alive?(migrator_pid) do
          spawn(fn ->
            SessionMigrator.handle_node_failure(migrator_pid, target_node)
          end)
        end
      end)

      Log.console("Simulated failure of node #{target_node}")
    end

    def simulate_network_partition(%TestCluster{} = cluster, partition_nodes) do
      # Simulate network partition by preventing communication between partitions
      partitioned_pids =
        Enum.flat_map(partition_nodes, fn node ->
          [
            Map.get(cluster.registry_pids, node),
            Map.get(cluster.storage_pids, node),
            Map.get(cluster.replicator_pids, node),
            Map.get(cluster.migrator_pids, node)
          ]
        end)

      # Mark processes as isolated (simplified simulation)
      Enum.each(partitioned_pids, fn pid ->
        if pid && Process.alive?(pid) do
          Process.put(:network_partitioned, true)
        end
      end)

      Log.console(
        "Simulated network partition for nodes: #{inspect(partition_nodes)}"
      )
    end

    def simulate_storage_corruption(%TestCluster{} = cluster, target_node) do
      storage_pid = Map.get(cluster.storage_pids, target_node)

      if storage_pid && Process.alive?(storage_pid) do
        # Simulate corruption by injecting invalid data
        spawn(fn ->
          # This would inject corrupted data into the storage
          Log.console("Simulated storage corruption on node #{target_node}")
        end)
      end
    end

    def simulate_high_load(
          %TestCluster{} = cluster,
          target_node,
          load_factor \\ 5
        ) do
      # Simulate high load by creating many concurrent operations
      spawn(fn ->
        for _ <- 1..load_factor do
          spawn(fn ->
            # Create load by performing operations
            {session_id, session_data} = SessionBuilder.create_simple_session()
            storage_pid = Map.get(cluster.storage_pids, target_node)

            if storage_pid && Process.alive?(storage_pid) do
              DistributedSessionStorage.store(
                storage_pid,
                session_id,
                session_data,
                %{}
              )

              Process.sleep(:rand.uniform(100))
              DistributedSessionStorage.get(storage_pid, session_id)
              DistributedSessionStorage.delete(storage_pid, session_id)
            end
          end)
        end
      end)

      Log.console(
        "Simulated high load on node #{target_node} with factor #{load_factor}"
      )
    end
  end

  # Performance Testing Helpers

  def measure_migration_performance(
        %TestCluster{} = cluster,
        session_count,
        migration_strategy
      ) do
    # Create test sessions
    sessions = create_test_session_batch(cluster, session_count, :simple)
    session_ids = Enum.map(sessions, fn {session_id, _node} -> session_id end)

    target_node = List.first(cluster.secondary_nodes)

    # Measure migration time
    start_time = :erlang.monotonic_time(:millisecond)

    case migrate_session_batch(
           cluster,
           session_ids,
           target_node,
           migration_strategy
         ) do
      {:ok, _migration_infos} ->
        # Wait for all migrations to complete
        wait_for_batch_migration_completion(
          cluster,
          session_ids,
          target_node,
          30000
        )

        end_time = :erlang.monotonic_time(:millisecond)
        total_time = end_time - start_time

        %{
          session_count: session_count,
          migration_strategy: migration_strategy,
          total_time_ms: total_time,
          average_time_per_session: total_time / session_count,
          throughput_sessions_per_second: session_count * 1000 / total_time
        }

      {:error, reason} ->
        {:error, reason}
    end
  end

  def measure_replication_performance(%TestCluster{} = cluster, session_count) do
    sessions = SessionBuilder.create_session_batch(session_count, :simple)

    start_time = :erlang.monotonic_time(:millisecond)

    # Store sessions with replication
    Enum.each(sessions, fn {session_id, session_data} ->
      primary_storage = Map.get(cluster.storage_pids, cluster.primary_node)

      primary_replicator =
        Map.get(cluster.replicator_pids, cluster.primary_node)

      DistributedSessionStorage.store(
        primary_storage,
        session_id,
        session_data,
        %{}
      )

      SessionReplicator.replicate_session(
        primary_replicator,
        session_id,
        session_data,
        cluster.secondary_nodes,
        :quorum
      )
    end)

    end_time = :erlang.monotonic_time(:millisecond)
    total_time = end_time - start_time

    %{
      session_count: session_count,
      total_time_ms: total_time,
      average_time_per_session: total_time / session_count,
      throughput_sessions_per_second: session_count * 1000 / total_time
    }
  end

  # Private Helper Functions

  defp find_session_location(%TestCluster{} = cluster, session_id) do
    cluster.all_nodes
    |> Enum.find_value(fn node ->
      _registry_pid = Map.get(cluster.registry_pids, node)

      case DistributedSessionRegistry.locate_session(session_id) do
        {:ok, located_node} -> {:ok, located_node}
        {:error, :not_found} -> nil
        {:error, _reason} -> nil
      end
    end)
    |> case do
      {:ok, node} -> {:ok, node}
      nil -> {:error, :not_found}
    end
  end

  defp wait_for_migration_completion(
         %TestCluster{} = cluster,
         session_id,
         target_node,
         end_time
       ) do
    if :erlang.monotonic_time(:millisecond) >= end_time do
      flunk("Migration timeout for session #{session_id}")
    end

    case find_session_location(cluster, session_id) do
      {:ok, ^target_node} ->
        :ok

      {:ok, _other_node} ->
        Process.sleep(100)

        wait_for_migration_completion(
          cluster,
          session_id,
          target_node,
          end_time
        )

      {:error, :not_found} ->
        Process.sleep(100)

        wait_for_migration_completion(
          cluster,
          session_id,
          target_node,
          end_time
        )
    end
  end

  defp wait_for_batch_migration_completion(
         %TestCluster{} = cluster,
         session_ids,
         target_node,
         timeout
       ) do
    end_time = :erlang.monotonic_time(:millisecond) + timeout

    Enum.each(session_ids, fn session_id ->
      wait_for_migration_completion(cluster, session_id, target_node, end_time)
    end)
  end

  defp count_session_replicas(%TestCluster{} = cluster, session_id) do
    Enum.count(cluster.all_nodes, fn node ->
      storage_pid = Map.get(cluster.storage_pids, node)

      case DistributedSessionStorage.get(storage_pid, session_id) do
        {:ok, _data} -> true
        {:error, :not_found} -> false
        {:error, _reason} -> false
      end
    end)
  end

  defp get_all_session_replicas(%TestCluster{} = cluster, session_id) do
    cluster.all_nodes
    |> Enum.filter(fn node ->
      storage_pid = Map.get(cluster.storage_pids, node)

      case DistributedSessionStorage.get(storage_pid, session_id) do
        {:ok, _data} -> true
        {:error, _} -> false
      end
    end)
    |> Enum.map(fn node ->
      storage_pid = Map.get(cluster.storage_pids, node)
      {:ok, data} = DistributedSessionStorage.get(storage_pid, session_id)
      data
    end)
  end

  defp get_all_registry_states(%TestCluster{} = cluster) do
    Enum.map(cluster.all_nodes, fn node ->
      _registry_pid = Map.get(cluster.registry_pids, node)
      # This would get the internal state of the registry
      # Simplified for now
      {node, %{}}
    end)
  end

  defp merge_registry_states(registry_states) do
    # Merge all registry states to find session locations
    Enum.reduce(registry_states, %{}, fn {_node, state}, acc ->
      Map.merge(acc, state)
    end)
  end

  defp find_session_location_conflicts(session_locations) do
    # Find sessions that appear on multiple nodes
    Enum.filter(session_locations, fn {_session_id, locations} ->
      is_list(locations) and length(locations) > 1
    end)
  end

  defp get_all_storage_sessions(%TestCluster{} = cluster) do
    Enum.flat_map(cluster.all_nodes, fn node ->
      storage_pid = Map.get(cluster.storage_pids, node)

      case DistributedSessionStorage.list_sessions(storage_pid, %{}) do
        {:ok, session_ids} -> Enum.map(session_ids, &{&1, node})
        {:error, _} -> []
      end
    end)
  end

  defp find_orphaned_sessions(session_locations, storage_sessions) do
    registry_sessions = Map.keys(session_locations)

    storage_session_ids =
      Enum.map(storage_sessions, fn {session_id, _node} -> session_id end)

    # Find sessions in storage but not in registry
    Enum.filter(storage_session_ids, fn session_id ->
      session_id not in registry_sessions
    end)
  end
end
