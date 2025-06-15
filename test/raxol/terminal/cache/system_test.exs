defmodule Raxol.Terminal.Cache.SystemTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Cache.System

  setup do
    # Start the cache system with test configuration
    {:ok, _pid} =
      System.start_link(
        # 1MB
        max_size: 1024 * 1024,
        default_ttl: 3600,
        eviction_policy: :lru,
        compression_enabled: true,
        namespace_configs: %{
          # 512KB
          buffer: %{max_size: 512 * 1024},
          # 256KB
          animation: %{max_size: 256 * 1024},
          # 128KB
          scroll: %{max_size: 128 * 1024},
          # 64KB
          clipboard: %{max_size: 64 * 1024},
          # 64KB
          general: %{max_size: 64 * 1024}
        }
      )

    :ok
  end

  describe "basic operations" do
    test "put and get" do
      assert :ok == System.put("test_key", "test_value", namespace: :general)
      assert {:ok, "test_value"} == System.get("test_key", namespace: :general)
    end

    test "invalidate" do
      System.put("test_key", "test_value", namespace: :general)
      assert :ok == System.invalidate("test_key", namespace: :general)
      assert {:error, :not_found} == System.get("test_key", namespace: :general)
    end

    test "clear" do
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
    test "different namespaces" do
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

    test "namespace not found" do
      assert {:error, :namespace_not_found} ==
               System.get("test_key", namespace: :invalid)
    end
  end

  describe "TTL operations" do
    test "expired entry" do
      System.put("test_key", "test_value", namespace: :general, ttl: 1)
      # Wait for entry to expire
      :timer.sleep(1100)
      assert {:error, :expired} == System.get("test_key", namespace: :general)
    end

    test "non-expired entry" do
      System.put("test_key", "test_value", namespace: :general, ttl: 2)
      # Wait less than TTL
      :timer.sleep(1000)
      assert {:ok, "test_value"} == System.get("test_key", namespace: :general)
    end
  end

  describe "eviction policies" do
    test "LRU eviction" do
      # Fill cache with values
      for i <- 1..10 do
        System.put("key#{i}", String.duplicate("value", 100),
          namespace: :general
        )
      end

      # Access some keys to change their last access time
      System.get("key1", namespace: :general)
      System.get("key2", namespace: :general)

      # Add a new value that should trigger eviction
      System.put("new_key", String.duplicate("value", 100), namespace: :general)

      # Check that least recently used keys were evicted
      assert {:error, :not_found} == System.get("key3", namespace: :general)
      assert {:ok, value1} = System.get("key1", namespace: :general)
      assert {:ok, value2} = System.get("key2", namespace: :general)
      assert is_binary(value1)
      assert is_binary(value2)
    end

    test "LFU eviction" do
      # Start with LFU policy
      {:ok, _pid} =
        System.start_link(
          max_size: 1024 * 1024,
          eviction_policy: :lfu,
          namespace_configs: %{general: %{max_size: 64 * 1024}}
        )

      # Fill cache with values
      for i <- 1..10 do
        System.put("key#{i}", String.duplicate("value", 100),
          namespace: :general
        )
      end

      # Access some keys multiple times
      for _ <- 1..5 do
        System.get("key1", namespace: :general)
        System.get("key2", namespace: :general)
      end

      # Add a new value that should trigger eviction
      System.put("new_key", String.duplicate("value", 100), namespace: :general)

      # Check that least frequently used keys were evicted
      assert {:error, :not_found} == System.get("key3", namespace: :general)
      assert {:ok, value1} = System.get("key1", namespace: :general)
      assert {:ok, value2} = System.get("key2", namespace: :general)
      assert is_binary(value1)
      assert is_binary(value2)
    end

    test "FIFO eviction" do
      # Start with FIFO policy
      {:ok, _pid} =
        System.start_link(
          max_size: 1024 * 1024,
          eviction_policy: :fifo,
          namespace_configs: %{general: %{max_size: 64 * 1024}}
        )

      # Fill cache with values
      for i <- 1..10 do
        System.put("key#{i}", String.duplicate("value", 100),
          namespace: :general
        )
      end

      # Add a new value that should trigger eviction
      System.put("new_key", String.duplicate("value", 100), namespace: :general)

      # Check that oldest keys were evicted
      assert {:error, :not_found} == System.get("key1", namespace: :general)
      assert {:error, :not_found} == System.get("key2", namespace: :general)
      assert {:ok, value9} = System.get("key9", namespace: :general)
      assert {:ok, value10} = System.get("key10", namespace: :general)
      assert is_binary(value9)
      assert is_binary(value10)
    end
  end

  describe "statistics" do
    test "cache stats" do
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
    test "metadata storage and retrieval" do
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
