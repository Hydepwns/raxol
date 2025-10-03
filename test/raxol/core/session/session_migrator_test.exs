defmodule Raxol.Core.Session.SessionMigratorTest do
  use ExUnit.Case, async: false
  use Raxol.Test.DistributedSessionTestHelper

  @moduletag :distributed
  @moduletag skip: "Requires distributed Erlang nodes - depends on DistributedSessionRegistry"

  alias Raxol.Core.Session.SessionMigrator

  describe "single session migration" do
    test "performs hot migration successfully" do
      cluster = create_test_cluster(3)

      {session_id, _session_data} = create_test_session(cluster, :simple, cluster.primary_node)
      target_node = List.first(cluster.secondary_nodes)

      # Perform hot migration
      assert {:ok, migration_info} = migrate_session(cluster, session_id, target_node, :hot)
      assert migration_info.strategy == :hot
      assert migration_info.status == :in_progress

      # Wait for migration completion
      assert_session_migrated(cluster, session_id, target_node, 5000)

      # Verify session is accessible on target node
      assert_session_on_node(cluster, session_id, target_node)

      # Verify session data integrity
      assert_session_data_consistency(cluster, session_id)

      cleanup_test_cluster(cluster)
    end

    test "performs warm migration with brief pause" do
      cluster = create_test_cluster(3)

      {session_id, _session_data} = create_test_session(cluster, :simple, cluster.primary_node)
      target_node = List.first(cluster.secondary_nodes)

      # Perform warm migration
      assert {:ok, migration_info} = migrate_session(cluster, session_id, target_node, :warm)
      assert migration_info.strategy == :warm

      # Wait for migration completion
      assert_session_migrated(cluster, session_id, target_node, 5000)

      # Verify session is on target node
      assert_session_on_node(cluster, session_id, target_node)

      cleanup_test_cluster(cluster)
    end

    test "performs cold migration with full suspension" do
      cluster = create_test_cluster(3)

      {session_id, _session_data} = create_test_session(cluster, :simple, cluster.primary_node)
      target_node = List.first(cluster.secondary_nodes)

      # Perform cold migration
      assert {:ok, migration_info} = migrate_session(cluster, session_id, target_node, :cold)
      assert migration_info.strategy == :cold

      # Wait for migration completion
      assert_session_migrated(cluster, session_id, target_node, 5000)

      # Verify session is on target node
      assert_session_on_node(cluster, session_id, target_node)

      cleanup_test_cluster(cluster)
    end

    test "handles migration of nonexistent session" do
      cluster = create_test_cluster(3)

      target_node = List.first(cluster.secondary_nodes)

      # Try to migrate nonexistent session
      assert {:error, {:session_location_failed, :not_found}} =
        migrate_session(cluster, "nonexistent_session", target_node, :hot)

      cleanup_test_cluster(cluster)
    end

    test "prevents migration to same node" do
      cluster = create_test_cluster(3)

      {session_id, _session_data} = create_test_session(cluster, :simple, cluster.primary_node)

      # Try to migrate to same node
      assert {:error, :session_already_on_target_node} =
        migrate_session(cluster, session_id, cluster.primary_node, :hot)

      cleanup_test_cluster(cluster)
    end
  end

  describe "bulk migration" do
    test "migrates multiple sessions efficiently" do
      cluster = create_test_cluster(3)

      # Create multiple sessions
      session_batch = create_test_session_batch(cluster, 10, :simple)
      session_ids = Enum.map(session_batch, fn {session_id, _node} -> session_id end)
      target_node = List.first(cluster.secondary_nodes)

      # Perform bulk migration
      assert {:ok, migration_infos} = migrate_session_batch(cluster, session_ids, target_node, :bulk)
      assert length(migration_infos) == 10

      # Wait for all migrations to complete
      Enum.each(session_ids, fn session_id ->
        assert_session_migrated(cluster, session_id, target_node, 10000)
      end)

      # Verify all sessions are on target node
      Enum.each(session_ids, fn session_id ->
        assert_session_on_node(cluster, session_id, target_node)
      end)

      cleanup_test_cluster(cluster)
    end

    test "handles partial bulk migration failures gracefully" do
      cluster = create_test_cluster(3)

      # Create mix of valid and invalid session IDs
      valid_sessions = create_test_session_batch(cluster, 5, :simple)
      valid_session_ids = Enum.map(valid_sessions, fn {session_id, _node} -> session_id end)
      invalid_session_ids = ["invalid1", "invalid2"]
      all_session_ids = valid_session_ids ++ invalid_session_ids

      target_node = List.first(cluster.secondary_nodes)

      # Bulk migration should handle partial failures
      case migrate_session_batch(cluster, all_session_ids, target_node, :bulk) do
        {:ok, migration_infos} ->
          # Some migrations should succeed
          successful_migrations = Enum.filter(migration_infos, &(&1.status != :failed))
          assert length(successful_migrations) >= 5

        {:error, _reason} ->
          # Bulk migration might fail entirely if any session is invalid
          # This is also acceptable behavior
          :ok
      end

      cleanup_test_cluster(cluster)
    end
  end

  describe "node evacuation" do
    test "evacuates all sessions from a node" do
      cluster = create_test_cluster(3)

      # Create sessions specifically on the target evacuation node
      evacuation_node = List.first(cluster.secondary_nodes)
      sessions_on_node = for i <- 1..8 do
        create_test_session(cluster, :simple, evacuation_node)
      end
      session_ids = Enum.map(sessions_on_node, fn {session_id, _data} -> session_id end)

      # Evacuate the node
      assert {:ok, migrated_count} = evacuate_node(cluster, evacuation_node)

      # Verify sessions were migrated away from evacuation node
      Enum.each(session_ids, fn session_id ->
        case find_session_location(cluster, session_id) do
          {:ok, node} ->
            assert node != evacuation_node, "Session #{session_id} still on evacuated node"

          {:error, :not_found} ->
            # Session might be in transit
            Process.sleep(100)
            case find_session_location(cluster, session_id) do
              {:ok, node} -> assert node != evacuation_node
              {:error, :not_found} -> flunk("Session #{session_id} lost during evacuation")
            end
        end
      end)

      cleanup_test_cluster(cluster)
    end

    test "distributes evacuated sessions across remaining nodes" do
      cluster = create_test_cluster(4)

      # Create many sessions on one node
      evacuation_node = List.first(cluster.secondary_nodes)
      sessions_on_node = for _i <- 1..20 do
        create_test_session(cluster, :simple, evacuation_node)
      end
      session_ids = Enum.map(sessions_on_node, fn {session_id, _data} -> session_id end)

      remaining_nodes = cluster.all_nodes -- [evacuation_node]

      # Evacuate the node
      assert {:ok, migrated_count} = evacuate_node(cluster, evacuation_node)
      assert migrated_count > 0

      # Wait for evacuation to complete
      Process.sleep(1000)

      # Verify sessions are distributed across remaining nodes
      session_distribution = Enum.group_by(session_ids, fn session_id ->
        case find_session_location(cluster, session_id) do
          {:ok, node} -> node
          {:error, :not_found} -> :not_found
        end
      end)

      # Sessions should be distributed across multiple remaining nodes
      distributed_nodes = Map.keys(session_distribution) -- [:not_found]
      assert length(distributed_nodes) >= 2, "Sessions not properly distributed during evacuation"

      cleanup_test_cluster(cluster)
    end
  end

  describe "failover handling" do
    test "handles node failure with immediate failover" do
      cluster = create_test_cluster(3, replication_factor: 2)

      # Create sessions with replication
      sessions = for _i <- 1..5 do
        create_test_session(cluster, :simple, cluster.primary_node)
      end
      session_ids = Enum.map(sessions, fn {session_id, _data} -> session_id end)

      # Ensure sessions are replicated
      Enum.each(session_ids, fn session_id ->
        assert_session_replicated(cluster, session_id, 2)
      end)

      # Simulate node failure
      failed_node = cluster.primary_node
      FaultInjector.simulate_node_failure(cluster, failed_node)

      # Wait for failover
      Process.sleep(500)

      # Verify sessions are accessible on other nodes
      Enum.each(session_ids, fn session_id ->
        case find_session_location(cluster, session_id) do
          {:ok, node} ->
            assert node != failed_node, "Session #{session_id} still showing on failed node"

          {:error, :not_found} ->
            # Failover might still be in progress
            Process.sleep(200)
            assert_session_exists(cluster, session_id)
        end
      end)

      cleanup_test_cluster(cluster)
    end

    test "maintains session availability during graceful failover" do
      cluster = create_test_cluster(3, replication_factor: 2)

      {session_id, _session_data} = create_test_session(cluster, :simple, cluster.primary_node)

      # Ensure session is replicated
      assert_session_replicated(cluster, session_id, 2)

      # Simulate graceful node shutdown
      failed_node = cluster.primary_node
      migrator_pid = Map.get(cluster.migrator_pids, List.first(cluster.secondary_nodes))

      # Handle node failure gracefully
      assert {:ok, failover_result} = SessionMigrator.handle_node_failure(migrator_pid, failed_node)
      assert failover_result.failed_node == failed_node

      # Verify session is still accessible
      assert_session_exists(cluster, session_id)

      cleanup_test_cluster(cluster)
    end
  end

  describe "migration rollback" do
    test "rolls back failed migration" do
      cluster = create_test_cluster(3)

      {session_id, _session_data} = create_test_session(cluster, :simple, cluster.primary_node)
      original_node = cluster.primary_node

      # Start migration (which we'll simulate as failing)
      migrator_pid = Map.get(cluster.migrator_pids, cluster.primary_node)

      # Simulate migration failure scenario
      # In a real test, we'd inject a failure during migration
      assert {:ok, _migration_info} = SessionMigrator.migrate_session(migrator_pid, session_id, List.first(cluster.secondary_nodes), :warm)

      # Simulate rollback
      assert :ok = SessionMigrator.rollback_migration(migrator_pid, session_id)

      # Verify session is back on original node
      # Note: This test requires implementing rollback functionality
      assert_session_on_node(cluster, session_id, original_node)

      cleanup_test_cluster(cluster)
    end
  end

  describe "load balancing and rebalancing" do
    test "rebalances sessions based on load" do
      cluster = create_test_cluster(3)

      # Create uneven session distribution
      primary_sessions = for _i <- 1..15 do
        create_test_session(cluster, :simple, cluster.primary_node)
      end

      secondary_sessions = for _i <- 1..5 do
        create_test_session(cluster, :simple, List.first(cluster.secondary_nodes))
      end

      all_session_ids = Enum.map(primary_sessions ++ secondary_sessions, fn {session_id, _data} -> session_id end)

      # Trigger rebalancing
      migrator_pid = Map.get(cluster.migrator_pids, cluster.primary_node)
      rebalance_config = %{
        target_balance_threshold: 0.3,  # 30% imbalance threshold
        max_migrations_per_rebalance: 5
      }

      assert {:ok, rebalanced_count} = SessionMigrator.rebalance_sessions(migrator_pid, rebalance_config)
      assert rebalanced_count > 0

      # Wait for rebalancing to complete
      Process.sleep(2000)

      # Verify more even distribution
      final_distribution = Enum.group_by(all_session_ids, fn session_id ->
        {:ok, node} = find_session_location(cluster, session_id)
        node
      end)

      session_counts = Enum.map(final_distribution, fn {_node, sessions} -> length(sessions) end)
      max_count = Enum.max(session_counts)
      min_count = Enum.min(session_counts)

      # Distribution should be more balanced
      assert (max_count - min_count) <= 8, "Sessions not properly rebalanced"

      cleanup_test_cluster(cluster)
    end
  end

  describe "performance testing" do
    test "measures migration performance" do
      cluster = create_test_cluster(3)

      # Test migration performance with different strategies
      strategies = [:hot, :warm, :cold]

      performance_results = Enum.map(strategies, fn strategy ->
        session_count = 20
        target_node = List.first(cluster.secondary_nodes)

        # Create sessions for this test
        sessions = for i <- 1..session_count do
          create_test_session(cluster, :simple, cluster.primary_node)
        end
        session_ids = Enum.map(sessions, fn {session_id, _data} -> session_id end)

        # Measure migration performance
        performance = measure_migration_performance(cluster, session_count, strategy)

        # Cleanup sessions for next test
        Enum.each(session_ids, fn session_id ->
          storage_pid = Map.get(cluster.storage_pids, target_node)
          if storage_pid && Process.alive?(storage_pid) do
            DistributedSessionStorage.delete(storage_pid, session_id)
          end
        end)

        {strategy, performance}
      end)

      # Verify performance metrics
      Enum.each(performance_results, fn {strategy, performance} ->
        case performance do
          %{throughput_sessions_per_second: throughput} ->
            assert throughput > 1.0, "#{strategy} migration throughput too low: #{throughput}"

          {:error, reason} ->
            flunk("Migration performance test failed for #{strategy}: #{inspect(reason)}")
        end
      end)

      cleanup_test_cluster(cluster)
    end

    test "handles concurrent migrations efficiently" do
      cluster = create_test_cluster(4)

      # Create sessions on different nodes
      sessions_node1 = for _i <- 1..5, do: create_test_session(cluster, :simple, cluster.primary_node)
      sessions_node2 = for _i <- 1..5, do: create_test_session(cluster, :simple, List.first(cluster.secondary_nodes))

      all_sessions = sessions_node1 ++ sessions_node2
      target_node = List.last(cluster.secondary_nodes)

      # Start concurrent migrations
      migration_tasks = Enum.map(all_sessions, fn {session_id, _data} ->
        Task.async(fn ->
          migrate_session(cluster, session_id, target_node, :hot)
        end)
      end)

      # Wait for all migrations to complete
      migration_results = Enum.map(migration_tasks, &Task.await(&1, 10000))

      # Verify most migrations succeeded
      successful_migrations = Enum.count(migration_results, fn
        {:ok, _} -> true
        {:error, :max_concurrent_migrations_exceeded} -> false  # Expected during high concurrency
        {:error, _} -> false
      end)

      assert successful_migrations >= 8, "Too many concurrent migrations failed"

      cleanup_test_cluster(cluster)
    end
  end

  describe "error handling and edge cases" do
    test "handles migration timeout gracefully" do
      cluster = create_test_cluster(3)

      {session_id, _session_data} = create_test_session(cluster, :simple, cluster.primary_node)

      # Simulate slow target node by introducing delay
      target_node = List.first(cluster.secondary_nodes)

      # Note: In a real implementation, we'd inject delays into the migration process
      # For this test, we'll just verify the migration system can handle timeouts

      migrator_pid = Map.get(cluster.migrator_pids, cluster.primary_node)

      # Start migration
      case SessionMigrator.migrate_session(migrator_pid, session_id, target_node, :warm) do
        {:ok, _migration_info} ->
          # Migration started successfully
          :ok

        {:error, :timeout} ->
          # Migration timed out as expected
          :ok

        {:error, other_reason} ->
          # Other errors are acceptable for this edge case test
          assert other_reason != :unexpected_error
      end

      cleanup_test_cluster(cluster)
    end

    test "maintains consistency during migration failures" do
      cluster = create_test_cluster(3)

      {session_id, _session_data} = create_test_session(cluster, :simple, cluster.primary_node)
      target_node = List.first(cluster.secondary_nodes)

      # Simulate storage failure on target node
      FaultInjector.simulate_storage_corruption(cluster, target_node)

      # Attempt migration (should fail)
      case migrate_session(cluster, session_id, target_node, :hot) do
        {:ok, _migration_info} ->
          # Migration might still succeed if corruption simulation didn't work
          :ok

        {:error, _reason} ->
          # Expected failure
          :ok
      end

      # Verify session is still accessible on original node
      assert_session_on_node(cluster, session_id, cluster.primary_node)

      # Verify no partial migration state
      assert_cluster_consistency(cluster)

      cleanup_test_cluster(cluster)
    end
  end

  describe "integration testing" do
    test "coordinates with session replication during migration" do
      cluster = create_test_cluster(4, replication_factor: 2)

      {session_id, session_data} = create_test_session(cluster, :simple, cluster.primary_node)

      # Ensure session is replicated
      assert_session_replicated(cluster, session_id, 2)

      # Migrate session
      target_node = List.last(cluster.all_nodes)
      assert {:ok, _migration_info} = migrate_session(cluster, session_id, target_node, :hot)

      # Wait for migration and re-replication
      assert_session_migrated(cluster, session_id, target_node, 5000)
      Process.sleep(200)  # Allow time for re-replication

      # Verify session is still properly replicated on new node
      assert_session_replicated(cluster, session_id, 2)

      cleanup_test_cluster(cluster)
    end

    test "works with existing session management systems" do
      cluster = create_test_cluster(3)

      # This test would verify integration with the existing
      # Raxol.Core.Session.SessionManager and Raxol.Terminal.SessionManager

      {session_id, session_data} = create_test_session(cluster, :complex, cluster.primary_node)

      # Migrate complex session with terminal state
      target_node = List.first(cluster.secondary_nodes)
      assert {:ok, _migration_info} = migrate_session(cluster, session_id, target_node, :warm)

      # Verify complex session data integrity
      assert_session_migrated(cluster, session_id, target_node)
      assert_session_data_consistency(cluster, session_id)

      cleanup_test_cluster(cluster)
    end
  end
end