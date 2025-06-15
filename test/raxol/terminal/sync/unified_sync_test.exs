defmodule Raxol.Terminal.Sync.UnifiedSyncTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Sync.UnifiedSync

  setup do
    {:ok, _pid} =
      UnifiedSync.start_link(
        consistency: :strong,
        conflict_resolution: :last_write_wins,
        timeout: 1000,
        retry_count: 3
      )

    :ok
  end

  describe "basic operations" do
    test "creates sync context" do
      assert {:ok, sync_id} = UnifiedSync.create_sync(:state)
      assert {:ok, sync_state} = UnifiedSync.get_sync_state(sync_id)
      assert sync_state.type == :state
      assert sync_state.version == 0
    end

    test "syncs data" do
      {:ok, sync_id} = UnifiedSync.create_sync(:state)
      data = %{value: "test"}
      assert :ok = UnifiedSync.sync(sync_id, data)
      assert {:ok, sync_state} = UnifiedSync.get_sync_state(sync_id)
      assert sync_state.data == data
      assert sync_state.version == 1
    end

    test "handles version conflicts" do
      {:ok, sync_id} = UnifiedSync.create_sync(:state)
      data1 = %{value: "test1"}
      data2 = %{value: "test2"}
      assert :ok = UnifiedSync.sync(sync_id, data1)

      assert {:error, :version_conflict} =
               UnifiedSync.sync(sync_id, data2, version: 0)
    end
  end

  describe "consistency levels" do
    test "strong consistency" do
      {:ok, sync_id} = UnifiedSync.create_sync(:state, consistency: :strong)
      data = %{value: "test"}
      assert :ok = UnifiedSync.sync(sync_id, data)
      assert {:ok, sync_state} = UnifiedSync.get_sync_state(sync_id)
      assert sync_state.data == data
    end

    test "eventual consistency" do
      {:ok, sync_id} = UnifiedSync.create_sync(:state, consistency: :eventual)
      data = %{value: "test"}
      assert :ok = UnifiedSync.sync(sync_id, data)
      assert {:ok, sync_state} = UnifiedSync.get_sync_state(sync_id)
      assert sync_state.data == data
    end
  end

  describe "conflict resolution" do
    test "last write wins" do
      {:ok, sync_id} =
        UnifiedSync.create_sync(:state, conflict_resolution: :last_write_wins)

      conflicts = [
        {%{value: "old"}, 1000, 1},
        {%{value: "new"}, 2000, 1}
      ]

      assert {:ok, resolved} = UnifiedSync.resolve_conflicts(sync_id, conflicts)
      assert resolved.value == "new"
    end

    test "version based" do
      {:ok, sync_id} =
        UnifiedSync.create_sync(:state, conflict_resolution: :version_based)

      conflicts = [
        {%{value: "old"}, 2000, 1},
        {%{value: "new"}, 1000, 2}
      ]

      assert {:ok, resolved} = UnifiedSync.resolve_conflicts(sync_id, conflicts)
      assert resolved.value == "new"
    end

    test "custom strategy" do
      {:ok, sync_id} =
        UnifiedSync.create_sync(:state, conflict_resolution: :custom)

      conflicts = [
        {%{value: "old"}, 1000, 1},
        {%{value: "new"}, 2000, 2}
      ]

      assert {:error, :not_implemented} =
               UnifiedSync.resolve_conflicts(sync_id, conflicts)
    end
  end

  describe "error handling" do
    test "handles non-existent sync" do
      assert {:error, :sync_not_found} =
               UnifiedSync.get_sync_state("nonexistent")

      assert {:error, :sync_not_found} = UnifiedSync.sync("nonexistent", %{})

      assert {:error, :sync_not_found} =
               UnifiedSync.resolve_conflicts("nonexistent", [])

      assert {:error, :sync_not_found} = UnifiedSync.cleanup("nonexistent")
    end

    test "handles invalid sync type" do
      assert {:error, _} = UnifiedSync.create_sync(:invalid)
    end
  end

  describe "cleanup" do
    test "cleans up sync context" do
      {:ok, sync_id} = UnifiedSync.create_sync(:state)
      assert :ok = UnifiedSync.cleanup(sync_id)
      assert {:error, :sync_not_found} = UnifiedSync.get_sync_state(sync_id)
    end
  end

  describe "metadata" do
    test "handles metadata in sync" do
      {:ok, sync_id} = UnifiedSync.create_sync(:state)
      data = %{value: "test"}
      metadata = %{source: "test", priority: 1}
      assert :ok = UnifiedSync.sync(sync_id, data, metadata: metadata)
      assert {:ok, sync_state} = UnifiedSync.get_sync_state(sync_id)
      assert sync_state.metadata == metadata
    end
  end

  describe "concurrent operations" do
    test "handles concurrent syncs" do
      {:ok, sync_id} = UnifiedSync.create_sync(:state)
      data1 = %{value: "test1"}
      data2 = %{value: "test2"}

      # Simulate concurrent syncs
      Task.async(fn ->
        UnifiedSync.sync(sync_id, data1, version: 0)
      end)

      Task.async(fn ->
        UnifiedSync.sync(sync_id, data2, version: 0)
      end)
      |> Task.await()

      assert {:ok, sync_state} = UnifiedSync.get_sync_state(sync_id)
      assert sync_state.version == 1
    end
  end
end
