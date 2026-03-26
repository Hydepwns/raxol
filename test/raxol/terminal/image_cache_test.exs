defmodule Raxol.Terminal.ImageCacheTest do
  use ExUnit.Case, async: false

  alias Raxol.Terminal.ImageCache

  setup do
    ImageCache.start()
    ImageCache.clear()
    :ok
  end

  describe "put/get" do
    test "stores and retrieves a value" do
      ImageCache.put("img1.png", {:decoded, [1, 2, 3]}, %{colors: 64})

      assert {:ok, {:decoded, [1, 2, 3]}} =
               ImageCache.get("img1.png", %{colors: 64})
    end

    test "returns :miss for unknown key" do
      assert :miss = ImageCache.get("nonexistent.png")
    end

    test "different opts produce different cache entries" do
      ImageCache.put("img.png", :val_a, %{colors: 64})
      ImageCache.put("img.png", :val_b, %{colors: 128})

      assert {:ok, :val_a} = ImageCache.get("img.png", %{colors: 64})
      assert {:ok, :val_b} = ImageCache.get("img.png", %{colors: 128})
    end

    test "overwrites existing entry with same key" do
      ImageCache.put("img.png", :old, %{a: 1})
      ImageCache.put("img.png", :new, %{a: 1})
      assert {:ok, :new} = ImageCache.get("img.png", %{a: 1})
    end
  end

  describe "fetch" do
    test "returns cached value without calling compute_fn" do
      ImageCache.put("cached.png", :existing)

      result =
        ImageCache.fetch("cached.png", %{}, fn ->
          raise "should not be called"
        end)

      assert {:ok, :existing} = result
    end

    test "calls compute_fn on miss and caches result" do
      result =
        ImageCache.fetch("new.png", %{}, fn ->
          {:ok, :computed}
        end)

      assert {:ok, :computed} = result
      assert {:ok, :computed} = ImageCache.get("new.png")
    end

    test "does not cache errors" do
      result =
        ImageCache.fetch("bad.png", %{}, fn ->
          {:error, :decode_failed}
        end)

      assert {:error, :decode_failed} = result
      assert :miss = ImageCache.get("bad.png")
    end
  end

  describe "evict" do
    test "removes all entries for a source_id" do
      ImageCache.put("img.png", :a, %{x: 1})
      ImageCache.put("img.png", :b, %{x: 2})
      ImageCache.put("other.png", :c, %{x: 1})

      ImageCache.evict("img.png")

      assert :miss = ImageCache.get("img.png", %{x: 1})
      assert :miss = ImageCache.get("img.png", %{x: 2})
      assert {:ok, :c} = ImageCache.get("other.png", %{x: 1})
    end
  end

  describe "clear" do
    test "removes all entries" do
      ImageCache.put("a.png", :a)
      ImageCache.put("b.png", :b)

      ImageCache.clear()

      assert ImageCache.size() == 0
    end
  end

  describe "size" do
    test "returns current entry count" do
      assert ImageCache.size() == 0
      ImageCache.put("a.png", :a)
      assert ImageCache.size() == 1
      ImageCache.put("b.png", :b)
      assert ImageCache.size() == 2
    end
  end

  describe "TTL expiry" do
    test "expired entries return :miss" do
      # Use a very short TTL for testing
      Application.put_env(:raxol, :image_cache_ttl_ms, 1)
      ImageCache.put("ttl.png", :value)

      Process.sleep(5)

      assert :miss = ImageCache.get("ttl.png")
    after
      Application.delete_env(:raxol, :image_cache_ttl_ms)
    end
  end

  describe "prune" do
    test "removes expired entries and returns count" do
      Application.put_env(:raxol, :image_cache_ttl_ms, 1)
      ImageCache.put("a.png", :a)
      ImageCache.put("b.png", :b)

      Process.sleep(5)

      pruned = ImageCache.prune()
      assert pruned == 2
      assert ImageCache.size() == 0
    after
      Application.delete_env(:raxol, :image_cache_ttl_ms)
    end
  end
end
