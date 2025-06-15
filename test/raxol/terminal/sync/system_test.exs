defmodule Raxol.Terminal.Sync.SystemTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Sync.System

  setup do
    # Start the sync system with test configuration
    {:ok, _pid} =
      System.start_link(
        consistency_levels: %{
          split: :strong,
          window: :strong,
          tab: :eventual
        }
      )

    :ok
  end

  describe "basic operations" do
    test "sync and get" do
      # Sync a value
      assert :ok == System.sync("test_sync", "test_key", "test_value")

      # Get the value
      assert {:ok, "test_value"} == System.get("test_sync", "test_key")
    end

    test "get non-existent sync" do
      assert {:error, :not_found} == System.get("nonexistent", "test_key")
    end

    test "get non-existent key" do
      System.sync("test_sync", "test_key", "test_value")
      assert {:error, :not_found} == System.get("test_sync", "nonexistent")
    end

    test "delete" do
      # Sync a value
      System.sync("test_sync", "test_key", "test_value")
      assert {:ok, "test_value"} == System.get("test_sync", "test_key")

      # Delete the value
      assert :ok == System.delete("test_sync", "test_key")
      assert {:error, :not_found} == System.get("test_sync", "test_key")
    end

    test "clear" do
      # Sync multiple values
      System.sync("test_sync", "key1", "value1")
      System.sync("test_sync", "key2", "value2")

      # Clear all values
      assert :ok == System.clear("test_sync")
      assert {:error, :not_found} == System.get("test_sync", "key1")
      assert {:error, :not_found} == System.get("test_sync", "key2")
    end
  end

  describe "consistency levels" do
    test "strong consistency" do
      # First sync with strong consistency
      System.sync("split", "test_key", "value1", consistency: :strong)

      # Second sync with lower version
      System.sync("split", "test_key", "value2", consistency: :strong)

      # Should keep the first value due to strong consistency
      assert {:ok, "value1"} == System.get("split", "test_key")
    end

    test "eventual consistency" do
      # First sync with eventual consistency
      System.sync("tab", "test_key", "value1", consistency: :eventual)

      # Second sync with higher version
      System.sync("tab", "test_key", "value2", consistency: :eventual)

      # Should use the second value due to higher version
      assert {:ok, "value2"} == System.get("tab", "test_key")
    end

    test "conflict resolution" do
      # First sync with eventual consistency
      System.sync("tab", "test_key", "value1", consistency: :eventual)

      # Second sync with same version
      assert {:error, :conflict} ==
               System.sync("tab", "test_key", "value2", consistency: :eventual)
    end
  end

  describe "metadata handling" do
    test "preserves metadata" do
      # Sync with metadata
      System.sync("test_sync", "test_key", "test_value", source: "test_source")

      # Get all data
      {:ok, sync_data} = System.get_all("test_sync")
      entry = Map.get(sync_data, "test_key")

      assert entry.value == "test_value"
      assert entry.metadata.source == "test_source"
      assert entry.metadata.consistency in [:strong, :eventual, :causal]
      assert is_integer(entry.metadata.version)
      assert is_integer(entry.metadata.timestamp)
    end
  end

  describe "statistics" do
    test "tracks sync statistics" do
      # Perform some syncs
      System.sync("test_sync", "key1", "value1", consistency: :strong)
      System.sync("test_sync", "key2", "value2", consistency: :eventual)
      System.sync("test_sync", "key3", "value3", consistency: :causal)

      # Get stats
      {:ok, stats} = System.stats("test_sync")
      assert stats.sync_count == 3
      assert stats.conflict_count == 0
      assert is_integer(stats.last_sync)
      assert stats.consistency_levels.strong == 1
      assert stats.consistency_levels.eventual == 1
      assert stats.consistency_levels.causal == 1
    end

    test "tracks conflicts" do
      # First sync
      System.sync("test_sync", "test_key", "value1", consistency: :eventual)

      # Second sync with same version (should cause conflict)
      System.sync("test_sync", "test_key", "value2", consistency: :eventual)

      # Get stats
      {:ok, stats} = System.stats("test_sync")
      assert stats.conflict_count == 1
    end
  end

  describe "multiple syncs" do
    test "handles multiple sync types" do
      # Sync to different types
      System.sync("split", "key1", "split_value")
      System.sync("window", "key1", "window_value")
      System.sync("tab", "key1", "tab_value")

      # Verify each type has its own data
      assert {:ok, "split_value"} == System.get("split", "key1")
      assert {:ok, "window_value"} == System.get("window", "key1")
      assert {:ok, "tab_value"} == System.get("tab", "key1")
    end

    test "get_all returns all data for sync" do
      # Sync multiple values
      System.sync("test_sync", "key1", "value1")
      System.sync("test_sync", "key2", "value2")
      System.sync("test_sync", "key3", "value3")

      # Get all data
      {:ok, sync_data} = System.get_all("test_sync")
      assert map_size(sync_data) == 3
      assert Map.get(sync_data, "key1").value == "value1"
      assert Map.get(sync_data, "key2").value == "value2"
      assert Map.get(sync_data, "key3").value == "value3"
    end
  end
end
