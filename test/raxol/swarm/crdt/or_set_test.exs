defmodule Raxol.Swarm.CRDT.ORSetTest do
  use ExUnit.Case, async: true

  alias Raxol.Swarm.CRDT.ORSet

  describe "basic operations" do
    test "new set is empty" do
      set = ORSet.new()
      assert ORSet.to_list(set) == []
      assert ORSet.size(set) == 0
    end

    test "add makes element a member" do
      set = ORSet.new() |> ORSet.add(:x, :node_a)
      assert ORSet.member?(set, :x)
      assert ORSet.to_list(set) == [:x]
    end

    test "remove makes element not a member" do
      set =
        ORSet.new()
        |> ORSet.add(:x, :node_a)
        |> ORSet.remove(:x)

      refute ORSet.member?(set, :x)
      assert ORSet.size(set) == 0
    end

    test "removing non-existent element is a no-op" do
      set = ORSet.new()
      assert ORSet.remove(set, :x) == set
    end

    test "multiple elements" do
      set =
        ORSet.new()
        |> ORSet.add(:a, :node_a)
        |> ORSet.add(:b, :node_a)
        |> ORSet.add(:c, :node_a)

      assert ORSet.size(set) == 3
      assert Enum.sort(ORSet.to_list(set)) == [:a, :b, :c]
    end
  end

  describe "merge/2" do
    test "merges additions from two nodes" do
      a = ORSet.new() |> ORSet.add(:x, :node_a)
      b = ORSet.new() |> ORSet.add(:y, :node_b)

      merged = ORSet.merge(a, b)
      assert ORSet.member?(merged, :x)
      assert ORSet.member?(merged, :y)
    end

    test "concurrent add wins over remove (add-wins)" do
      # Both start from same base with :x
      base = ORSet.new() |> ORSet.add(:x, :node_a)

      # node_a removes :x
      removed = ORSet.remove(base, :x)

      # node_b concurrently adds :x (new dot)
      readded = ORSet.add(base, :x, :node_b)

      # Merge: the new dot from node_b survives the remove
      merged = ORSet.merge(removed, readded)
      assert ORSet.member?(merged, :x)
    end

    test "is commutative" do
      a = ORSet.new() |> ORSet.add(:x, :node_a) |> ORSet.add(:y, :node_a)
      b = ORSet.new() |> ORSet.add(:y, :node_b) |> ORSet.add(:z, :node_b)

      merged_ab = ORSet.merge(a, b)
      merged_ba = ORSet.merge(b, a)

      assert Enum.sort(ORSet.to_list(merged_ab)) ==
               Enum.sort(ORSet.to_list(merged_ba))
    end

    test "is idempotent" do
      set = ORSet.new() |> ORSet.add(:x, :node_a)
      merged = ORSet.merge(set, set)

      assert ORSet.to_list(merged) == ORSet.to_list(set)
    end

    test "is associative" do
      a = ORSet.new() |> ORSet.add(:x, :node_a)
      b = ORSet.new() |> ORSet.add(:y, :node_b)
      c = ORSet.new() |> ORSet.add(:z, :node_c)

      ab_c = ORSet.merge(ORSet.merge(a, b), c)
      a_bc = ORSet.merge(a, ORSet.merge(b, c))

      assert Enum.sort(ORSet.to_list(ab_c)) == Enum.sort(ORSet.to_list(a_bc))
    end

    test "remove after merge is respected" do
      a = ORSet.new() |> ORSet.add(:x, :node_a)
      b = ORSet.new() |> ORSet.add(:x, :node_b)

      merged = ORSet.merge(a, b) |> ORSet.remove(:x)
      refute ORSet.member?(merged, :x)
    end
  end
end
