defmodule Raxol.Web.PersistentStoreTest do
  use ExUnit.Case, async: false

  alias Raxol.Web.PersistentStore

  setup do
    # Ensure the PersistentStore is started
    case GenServer.whereis(PersistentStore) do
      nil ->
        {:ok, _pid} = PersistentStore.start_link([])

      _pid ->
        # Clear existing data
        PersistentStore.clear()
    end

    :ok
  end

  describe "store/3 and fetch/1" do
    test "stores and retrieves a value" do
      :ok = PersistentStore.store("key1", "value1")

      assert {:ok, "value1"} = PersistentStore.fetch("key1")
    end

    test "stores complex values" do
      data = %{
        nested: %{
          list: [1, 2, 3],
          map: %{a: 1, b: 2}
        },
        tuple: {1, 2, 3}
      }

      :ok = PersistentStore.store("complex", data)

      {:ok, retrieved} = PersistentStore.fetch("complex")

      assert retrieved.nested.list == [1, 2, 3]
      assert retrieved.tuple == {1, 2, 3}
    end

    test "returns not_found for missing key" do
      assert {:error, :not_found} = PersistentStore.fetch("nonexistent")
    end

    test "overwrites existing value" do
      PersistentStore.store("key", "value1")
      PersistentStore.store("key", "value2")

      assert {:ok, "value2"} = PersistentStore.fetch("key")
    end
  end

  describe "store/3 with options" do
    test "stores with TTL - entry is accessible before expiration" do
      :ok = PersistentStore.store("ttl_key", "value", ttl: 10)

      # Entry should be accessible
      assert {:ok, "value"} = PersistentStore.fetch("ttl_key")
    end

    test "stores with tier hint" do
      :ok = PersistentStore.store("hot_key", "value", tier: :hot)

      assert {:ok, "value"} = PersistentStore.fetch("hot_key")
    end
  end

  describe "delete/1" do
    test "removes a key" do
      PersistentStore.store("key", "value")

      assert {:ok, "value"} = PersistentStore.fetch("key")

      :ok = PersistentStore.delete("key")

      assert {:error, :not_found} = PersistentStore.fetch("key")
    end

    test "returns ok for non-existent key" do
      assert :ok = PersistentStore.delete("nonexistent")
    end
  end

  describe "exists?/1" do
    test "returns true for existing key" do
      PersistentStore.store("key", "value")

      assert PersistentStore.exists?("key") == true
    end

    test "returns false for missing key" do
      assert PersistentStore.exists?("nonexistent") == false
    end
  end

  describe "keys/0" do
    test "returns empty list when store is empty" do
      PersistentStore.clear()

      assert PersistentStore.keys() == []
    end

    test "returns all keys" do
      PersistentStore.store("key1", "v1")
      PersistentStore.store("key2", "v2")
      PersistentStore.store("key3", "v3")

      keys = PersistentStore.keys()

      assert "key1" in keys
      assert "key2" in keys
      assert "key3" in keys
    end
  end

  describe "clear/0" do
    test "removes all keys" do
      PersistentStore.store("key1", "v1")
      PersistentStore.store("key2", "v2")

      :ok = PersistentStore.clear()

      assert PersistentStore.keys() == []
    end
  end

  describe "promote/1" do
    test "promotes key to faster tier" do
      PersistentStore.store("key", "value", tier: :warm)

      :ok = PersistentStore.promote("key")

      # Key should still be accessible
      assert {:ok, "value"} = PersistentStore.fetch("key")
    end

    test "returns error for non-existent key" do
      assert {:error, :not_found} = PersistentStore.promote("nonexistent")
    end
  end

  describe "demote/1" do
    test "demotes key to slower tier" do
      PersistentStore.store("key", "value", tier: :hot)

      :ok = PersistentStore.demote("key")

      # Key should still be accessible
      assert {:ok, "value"} = PersistentStore.fetch("key")
    end

    test "returns error for non-existent key" do
      assert {:error, :not_found} = PersistentStore.demote("nonexistent")
    end
  end

  describe "cleanup_expired/0" do
    test "returns count of cleaned entries" do
      # Store permanent entries
      PersistentStore.store("permanent", "value")

      # Run cleanup
      {:ok, count} = PersistentStore.cleanup_expired()

      # Count should be 0 or a non-negative integer
      assert is_integer(count)
      assert count >= 0

      # Permanent entry should still exist
      assert {:ok, "value"} = PersistentStore.fetch("permanent")
    end
  end

  describe "stats/0" do
    test "returns store statistics" do
      PersistentStore.store("k1", "v1")
      PersistentStore.store("k2", "v2")

      stats = PersistentStore.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :hot_count) or Map.has_key?(stats, :total_keys)
    end
  end

  describe "fetch_or_store/2" do
    test "returns existing value without computing" do
      PersistentStore.store("key", "existing_value")

      compute_count = :counters.new(1, [])

      result = PersistentStore.fetch_or_store("key", fn ->
        :counters.add(compute_count, 1, 1)
        "computed_value"
      end)

      assert result == "existing_value"
      assert :counters.get(compute_count, 1) == 0
    end

    test "computes and stores value when key missing" do
      compute_count = :counters.new(1, [])

      result = PersistentStore.fetch_or_store("new_key", fn ->
        :counters.add(compute_count, 1, 1)
        "computed_value"
      end)

      assert result == "computed_value"
      assert :counters.get(compute_count, 1) == 1

      # Value should now be stored
      assert {:ok, "computed_value"} = PersistentStore.fetch("new_key")
    end

    test "only computes once even when called multiple times" do
      compute_count = :counters.new(1, [])

      compute_fn = fn ->
        :counters.add(compute_count, 1, 1)
        "computed"
      end

      _result1 = PersistentStore.fetch_or_store("once_key", compute_fn)
      _result2 = PersistentStore.fetch_or_store("once_key", compute_fn)
      _result3 = PersistentStore.fetch_or_store("once_key", compute_fn)

      assert :counters.get(compute_count, 1) == 1
    end
  end

  describe "update/2" do
    test "updates existing value" do
      PersistentStore.store("counter", 0)

      :ok = PersistentStore.update("counter", fn count -> count + 1 end)

      assert {:ok, 1} = PersistentStore.fetch("counter")
    end

    test "chains multiple updates" do
      PersistentStore.store("counter", 0)

      :ok = PersistentStore.update("counter", fn c -> c + 1 end)
      :ok = PersistentStore.update("counter", fn c -> c + 1 end)
      :ok = PersistentStore.update("counter", fn c -> c * 2 end)

      assert {:ok, 4} = PersistentStore.fetch("counter")
    end

    test "returns error for non-existent key" do
      assert {:error, :not_found} = PersistentStore.update("nonexistent", fn v -> v end)
    end

    test "works with complex values" do
      PersistentStore.store("map", %{count: 0, items: []})

      :ok = PersistentStore.update("map", fn m ->
        %{m | count: m.count + 1, items: ["item1" | m.items]}
      end)

      {:ok, result} = PersistentStore.fetch("map")
      assert result.count == 1
      assert result.items == ["item1"]
    end
  end
end
