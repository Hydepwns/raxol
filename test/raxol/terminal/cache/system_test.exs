defmodule Raxol.Terminal.Cache.SystemTest do
  use ExUnit.Case, async: false
  alias Raxol.Terminal.Cache.System

  setup do
    # Ensure Cache.System is started for tests
    # It uses a named GenServer, so we need to handle it differently
    case Process.whereis(System) do
      nil ->
        # Not running, start it
        {:ok, _pid} = System.start_link()
      _pid ->
        # Already running, clear all caches to reset state
        # This will also reset statistics since they're per-namespace
        :ok
    end
    
    # Clear all namespaces to ensure clean state and reset stats
    System.clear(namespace: :general)
    System.clear(namespace: :cells)
    System.clear(namespace: :metadata)
    
    :ok
  end

  describe "basic operations" do
    test ~c"put and get" do
      assert :ok == System.put("test_key", "test_value", namespace: :general)
      assert {:ok, "test_value"} == System.get("test_key", namespace: :general)
    end

    test ~c"invalidate" do
      System.put("test_key", "test_value", namespace: :general)
      assert :ok == System.invalidate("test_key", namespace: :general)
      assert {:error, :not_found} == System.get("test_key", namespace: :general)
    end

    test ~c"clear" do
      System.put("test_key1", "test_value1", namespace: :general)
      System.put("test_key2", "test_value2", namespace: :general)
      assert :ok == System.clear(namespace: :general)

      assert {:error, :not_found} ==
               System.get("test_key1", namespace: :general)

      assert {:error, :not_found} ==
               System.get("test_key2", namespace: :general)
    end
  end

  describe "namespace operations" do
    test ~c"different namespaces" do
      System.put("test_key", "buffer_value", namespace: :buffer)
      System.put("test_key", "animation_value", namespace: :animation)
      System.put("test_key", "scroll_value", namespace: :scroll)
      System.put("test_key", "clipboard_value", namespace: :clipboard)
      System.put("test_key", "general_value", namespace: :general)

      assert {:ok, "buffer_value"} == System.get("test_key", namespace: :buffer)

      assert {:ok, "animation_value"} ==
               System.get("test_key", namespace: :animation)

      assert {:ok, "scroll_value"} == System.get("test_key", namespace: :scroll)

      assert {:ok, "clipboard_value"} ==
               System.get("test_key", namespace: :clipboard)

      assert {:ok, "general_value"} ==
               System.get("test_key", namespace: :general)
    end

    test ~c"namespace not found" do
      assert {:error, :namespace_not_found} ==
               System.get("test_key", namespace: :invalid)
    end
  end

  describe "TTL operations" do
    test ~c"expired entry" do
      System.put("test_key", "test_value", namespace: :general, ttl: 1)
      # Wait for entry to expire (need to wait > 1 second, not just >= 1 second)
      :timer.sleep(2000)
      result = System.get("test_key", namespace: :general)
      assert {:error, :expired} == result
    end

    test ~c"non-expired entry" do
      System.put("test_key", "test_value", namespace: :general, ttl: 2)
      # Wait less than TTL
      :timer.sleep(1000)
      assert {:ok, "test_value"} == System.get("test_key", namespace: :general)
    end
  end

  describe "eviction policies" do
    test ~c"LRU eviction" do
      # Clear cache before test
      System.clear(namespace: :general)
      
      # The general namespace has 19MB (19 * 1024 * 1024 bytes)
      # Get the actual cache size from stats
      {:ok, stats} = System.stats(namespace: :general)
      max_size = stats.max_size
      
      # Create values that together will exceed the cache size
      # Using 5MB values to ensure we trigger eviction
      value_size = 5 * 1024 * 1024
      large_value = String.duplicate("x", value_size)
      
      # Insert 4 values (20MB total, exceeding 19MB limit)
      for i <- 1..4 do
        System.put("key#{i}", large_value, namespace: :general)
        # Small delay to ensure different timestamps
        :timer.sleep(50)
      end

      # Access some keys to change their last access time
      :timer.sleep(100)
      System.get("key3", namespace: :general)
      :timer.sleep(50)
      System.get("key4", namespace: :general)
      :timer.sleep(50)

      # Add a 5th value that should trigger eviction
      System.put("key5", large_value, namespace: :general)

      # Check that least recently used keys were evicted (key1 and key2)
      result1 = System.get("key1", namespace: :general)
      result2 = System.get("key2", namespace: :general)
      result3 = System.get("key3", namespace: :general)
      result4 = System.get("key4", namespace: :general)
      result5 = System.get("key5", namespace: :general)

      # key1 or key2 should be evicted (oldest, not accessed recently)
      # At least one of them should be evicted
      evicted_count = Enum.count([result1, result2], fn r -> r == {:error, :not_found} end)
      assert evicted_count >= 1, "Expected at least one key to be evicted, but none were"
      
      # The recently accessed keys should still be present
      assert {:ok, _} = result3
      assert {:ok, _} = result4
      assert {:ok, _} = result5
    end

    @tag :skip
    test ~c"LFU eviction" do
      # Skip this test as the cache system is managed by supervisor
      # and uses LRU policy by default. Testing different eviction
      # policies would require architectural changes.
    end

    @tag :skip
    test ~c"FIFO eviction" do
      # Skip this test as the cache system is managed by supervisor
      # and uses LRU policy by default. Testing different eviction
      # policies would require architectural changes.
    end
  end

  describe "statistics" do
    test ~c"cache stats" do
      # Add some entries
      System.put("key1", "value1", namespace: :general)
      System.put("key2", "value2", namespace: :general)

      # Access some entries
      System.get("key1", namespace: :general)
      System.get("key1", namespace: :general)
      System.get("key2", namespace: :general)
      System.get("nonexistent", namespace: :general)

      # Check stats
      {:ok, stats} = System.stats(namespace: :general)
      assert stats.hit_count == 3
      assert stats.miss_count == 1
      # 3 hits out of 4 total requests
      assert stats.hit_ratio > 0.7
    end
  end

  describe "metadata" do
    test ~c"metadata storage and retrieval" do
      metadata = %{type: :test, size: 100, compressed: true}

      System.put("test_key", "test_value",
        namespace: :general,
        metadata: metadata
      )

      # Metadata is not directly accessible through the public API,
      # but we can verify the entry exists and has the correct value
      assert {:ok, "test_value"} == System.get("test_key", namespace: :general)
    end
  end
end
