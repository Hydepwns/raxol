defmodule Raxol.Terminal.Cache.UnifiedCacheTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Cache.UnifiedCache

  setup do
    {:ok, _pid} = UnifiedCache.start_link(max_size: 1000, default_ttl: 1)
    :ok
  end

  describe "basic operations" do
    test 'put and get' do
      assert :ok == UnifiedCache.put("key1", "value1")
      assert {:ok, "value1"} == UnifiedCache.get("key1")
    end

    test 'get non-existent key' do
      assert {:error, :not_found} == UnifiedCache.get("nonexistent")
    end

    test 'invalidate' do
      UnifiedCache.put("key1", "value1")
      assert :ok == UnifiedCache.invalidate("key1")
      assert {:error, :not_found} == UnifiedCache.get("key1")
    end

    test 'clear' do
      UnifiedCache.put("key1", "value1")
      UnifiedCache.put("key2", "value2")
      assert :ok == UnifiedCache.clear()
      assert {:error, :not_found} == UnifiedCache.get("key1")
      assert {:error, :not_found} == UnifiedCache.get("key2")
    end
  end

  describe "namespaces" do
    test 'different namespaces' do
      UnifiedCache.put("key1", "value1", namespace: :ns1)
      UnifiedCache.put("key1", "value2", namespace: :ns2)
      assert {:ok, "value1"} == UnifiedCache.get("key1", namespace: :ns1)
      assert {:ok, "value2"} == UnifiedCache.get("key1", namespace: :ns2)
    end

    test 'non-existent namespace' do
      assert {:error, :namespace_not_found} ==
               UnifiedCache.get("key1", namespace: :nonexistent)
    end
  end

  describe "TTL" do
    test 'expired entry' do
      UnifiedCache.put("key1", "value1", ttl: 1)
      # Wait for expiration
      Process.sleep(1100)
      assert {:error, :expired} == UnifiedCache.get("key1")
    end

    test 'non-expired entry' do
      UnifiedCache.put("key1", "value1", ttl: 2)
      # Wait less than TTL
      Process.sleep(1000)
      assert {:ok, "value1"} == UnifiedCache.get("key1")
    end
  end

  describe "eviction policies" do
    test 'LRU eviction' do
      {:ok, _pid} =
        UnifiedCache.start_link(max_size: 100, eviction_policy: :lru)

      UnifiedCache.put("key1", String.duplicate("a", 50))
      UnifiedCache.put("key2", String.duplicate("b", 50))
      # Should evict key1
      UnifiedCache.put("key3", String.duplicate("c", 50))
      assert {:error, :not_found} == UnifiedCache.get("key1")
      assert {:ok, _value2} = UnifiedCache.get("key2")
      assert {:ok, _value3} = UnifiedCache.get("key3")
    end

    test 'LFU eviction' do
      {:ok, _pid} =
        UnifiedCache.start_link(max_size: 100, eviction_policy: :lfu)

      UnifiedCache.put("key1", String.duplicate("a", 50))
      UnifiedCache.put("key2", String.duplicate("b", 50))
      # Access key1 twice
      UnifiedCache.get("key1")
      UnifiedCache.get("key1")
      # Should evict key2
      UnifiedCache.put("key3", String.duplicate("c", 50))
      assert {:ok, _value1} = UnifiedCache.get("key1")
      assert {:error, :not_found} == UnifiedCache.get("key2")
      assert {:ok, _value3} = UnifiedCache.get("key3")
    end

    test 'FIFO eviction' do
      {:ok, _pid} =
        UnifiedCache.start_link(max_size: 100, eviction_policy: :fifo)

      UnifiedCache.put("key1", String.duplicate("a", 50))
      UnifiedCache.put("key2", String.duplicate("b", 50))
      # Should evict key1
      UnifiedCache.put("key3", String.duplicate("c", 50))
      assert {:error, :not_found} == UnifiedCache.get("key1")
      assert {:ok, _value2} = UnifiedCache.get("key2")
      assert {:ok, _value3} = UnifiedCache.get("key3")
    end
  end

  describe "statistics" do
    test 'hit and miss counts' do
      UnifiedCache.put("key1", "value1")
      # Hit
      UnifiedCache.get("key1")
      # Hit
      UnifiedCache.get("key1")
      # Miss
      UnifiedCache.get("nonexistent")
      {:ok, stats} = UnifiedCache.stats()
      assert stats.hit_count == 2
      assert stats.miss_count == 1
      assert_in_delta stats.hit_ratio, 0.666, 0.001
    end

    test 'size tracking' do
      value = String.duplicate("a", 100)
      UnifiedCache.put("key1", value)
      {:ok, stats} = UnifiedCache.stats()
      assert stats.size > 0
      assert stats.size <= stats.max_size
    end
  end

  describe "metadata" do
    test 'metadata storage' do
      metadata = %{type: "test", priority: 1}
      UnifiedCache.put("key1", "value1", metadata: metadata)
      {:ok, stats} = UnifiedCache.stats()
      assert stats.size > 0
    end
  end
end
