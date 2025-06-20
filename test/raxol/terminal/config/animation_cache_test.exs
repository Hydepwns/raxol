defmodule Raxol.Terminal.Config.AnimationCacheTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Config.AnimationCache
  alias Raxol.Terminal.Cache.System

  setup do
    # Start the cache system
    {:ok, _pid} =
      System.start_link(
        max_size: 1024 * 1024,
        default_ttl: 3600,
        eviction_policy: :lru,
        namespace_configs: %{
          animation: %{max_size: 10 * 1024 * 1024} # 10MB for test
        }
      )

    # Create test animation data
    animation_data = %{
      frames: [
        %{content: "Frame 1", duration: 100},
        %{content: "Frame 2", duration: 100},
        %{content: "Frame 3", duration: 100}
      ],
      metadata: %{
        name: "test_animation",
        type: :text,
        size: 150
      }
    }

    %{animation_data: animation_data}
  end

  describe "animation caching" do
    test "caches animation data", %{animation_data: animation_data} do
      # Cache animation
      :ok = AnimationCache.cache_animation_data("test_anim", animation_data)

      # Retrieve from cache
      {:ok, cached_data} = AnimationCache.get_cached_animation("test_anim")
      assert cached_data == animation_data

      # Verify cache stats
      {:ok, stats} = System.stats(namespace: :animation)
      assert stats.hit_count > 0
    end

    test "handles cache misses", %{animation_data: animation_data} do
      # Try to get non-existent animation
      assert {:error, :not_found} ==
               AnimationCache.get_cached_animation("nonexistent")

      # Cache animation
      :ok = AnimationCache.cache_animation_data("test_anim", animation_data)

      # Verify it's now in cache
      {:ok, cached_data} = AnimationCache.get_cached_animation("test_anim")
      assert cached_data == animation_data
    end

    test "updates existing animation", %{animation_data: animation_data} do
      # Cache initial animation
      :ok = AnimationCache.cache_animation_data("test_anim", animation_data)

      # Update animation
      updated_data = %{
        animation_data
        | frames: [%{content: "New Frame", duration: 200}]
      }

      :ok = AnimationCache.cache_animation_data("test_anim", updated_data)

      # Verify update
      {:ok, cached_data} = AnimationCache.get_cached_animation("test_anim")
      assert cached_data == updated_data
    end
  end

  describe "cache management" do
    test "clears animation cache", %{animation_data: animation_data} do
      # Cache some animations
      :ok = AnimationCache.cache_animation_data("anim1", animation_data)
      :ok = AnimationCache.cache_animation_data("anim2", animation_data)

      # Clear cache
      :ok = AnimationCache.clear_animation_cache()

      # Verify cache is empty
      assert {:error, :not_found} ==
               AnimationCache.get_cached_animation("anim1")

      assert {:error, :not_found} ==
               AnimationCache.get_cached_animation("anim2")
    end

    test "handles cache size limits", %{animation_data: animation_data} do
      # Create large animation data
      large_data = %{
        animation_data
        | frames:
            Enum.map(1..100, fn i ->
              %{content: String.duplicate("Frame #{i}", 1000), duration: 100}
            end)
      }

      # Cache large animation
      :ok = AnimationCache.cache_animation_data("large_anim", large_data)

      # Cache another animation
      :ok = AnimationCache.cache_animation_data("small_anim", animation_data)

      # Verify both are cached
      {:ok, cached_large} = AnimationCache.get_cached_animation("large_anim")
      {:ok, cached_small} = AnimationCache.get_cached_animation("small_anim")
      assert cached_large == large_data
      assert cached_small == animation_data
    end
  end

  describe "cache statistics" do
    test "tracks cache statistics", %{animation_data: animation_data} do
      # Cache some animations
      :ok = AnimationCache.cache_animation_data("anim1", animation_data)
      :ok = AnimationCache.cache_animation_data("anim2", animation_data)

      # Access animations multiple times
      for _ <- 1..5 do
        AnimationCache.get_cached_animation("anim1")
      end

      for _ <- 1..3 do
        AnimationCache.get_cached_animation("anim2")
      end

      # Get cache stats
      {:ok, stats} = AnimationCache.get_animation_cache_stats()
      # 5 + 3 hits
      assert stats.hit_count == 8
      assert stats.miss_count == 0
      assert stats.hit_ratio == 1.0
    end

    test "tracks cache misses", %{animation_data: animation_data} do
      # Try to get non-existent animations
      for _ <- 1..3 do
        AnimationCache.get_cached_animation("nonexistent")
      end

      # Cache an animation
      :ok = AnimationCache.cache_animation_data("test_anim", animation_data)

      # Get cache stats
      {:ok, stats} = AnimationCache.get_animation_cache_stats()
      assert stats.miss_count == 3
      assert stats.hit_count == 0
      assert stats.hit_ratio == 0.0
    end
  end

  describe "metadata handling" do
    test "preserves animation metadata", %{animation_data: animation_data} do
      # Cache animation with metadata
      :ok = AnimationCache.cache_animation_data("test_anim", animation_data)

      # Retrieve and verify metadata
      {:ok, cached_data} = AnimationCache.get_cached_animation("test_anim")
      assert cached_data.metadata == animation_data.metadata
      assert cached_data.metadata.name == "test_animation"
      assert cached_data.metadata.type == :text
      assert cached_data.metadata.size == 150
    end

    test "updates metadata on cache update", %{animation_data: animation_data} do
      # Cache initial animation
      :ok = AnimationCache.cache_animation_data("test_anim", animation_data)

      # Update with new metadata
      updated_data = %{
        animation_data
        | metadata: %{
            name: "updated_animation",
            type: :graphics,
            size: 200
          }
      }

      :ok = AnimationCache.cache_animation_data("test_anim", updated_data)

      # Verify metadata update
      {:ok, cached_data} = AnimationCache.get_cached_animation("test_anim")
      assert cached_data.metadata.name == "updated_animation"
      assert cached_data.metadata.type == :graphics
      assert cached_data.metadata.size == 200
    end
  end
end
