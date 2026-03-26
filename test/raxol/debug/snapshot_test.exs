defmodule Raxol.Debug.SnapshotTest do
  use ExUnit.Case, async: true

  alias Raxol.Debug.Snapshot

  describe "new/4" do
    test "creates a snapshot with the given fields" do
      snap = Snapshot.new(0, :increment, %{count: 0}, %{count: 1})

      assert snap.index == 0
      assert snap.message == :increment
      assert snap.model_before == %{count: 0}
      assert snap.model_after == %{count: 1}
      assert is_integer(snap.timestamp_us)
    end

    test "assigns monotonically increasing timestamps" do
      s1 = Snapshot.new(0, :a, %{}, %{})
      s2 = Snapshot.new(1, :b, %{}, %{})
      assert s2.timestamp_us >= s1.timestamp_us
    end
  end

  describe "changed?/1" do
    test "returns true when model changed" do
      snap = Snapshot.new(0, :inc, %{count: 0}, %{count: 1})
      assert Snapshot.changed?(snap)
    end

    test "returns false when model is unchanged" do
      model = %{count: 0}
      snap = Snapshot.new(0, :noop, model, model)
      refute Snapshot.changed?(snap)
    end
  end

  describe "summary/1" do
    test "includes index and change count" do
      snap = Snapshot.new(5, :increment, %{count: 0}, %{count: 1})
      summary = Snapshot.summary(snap)

      assert summary =~ "#5"
      assert summary =~ "1 changes"
    end

    test "shows 0 changes for no-op update" do
      model = %{count: 0}
      snap = Snapshot.new(0, :noop, model, model)
      assert Snapshot.summary(snap) =~ "0 changes"
    end
  end

  describe "diff/2 with maps" do
    test "detects changed values" do
      changes = Snapshot.diff(%{a: 1, b: 2}, %{a: 1, b: 3})
      assert [{:changed, [:b], 2, 3}] = changes
    end

    test "detects added keys" do
      changes = Snapshot.diff(%{a: 1}, %{a: 1, b: 2})
      assert [{:added, [:b], 2}] = changes
    end

    test "detects removed keys" do
      changes = Snapshot.diff(%{a: 1, b: 2}, %{a: 1})
      assert [{:removed, [:b], 2}] = changes
    end

    test "returns empty list for identical maps" do
      assert [] = Snapshot.diff(%{a: 1, b: 2}, %{a: 1, b: 2})
    end

    test "recurses into nested maps" do
      a = %{user: %{name: "Alice", age: 30}}
      b = %{user: %{name: "Alice", age: 31}}
      changes = Snapshot.diff(a, b)
      assert [{:changed, [:user, :age], 30, 31}] = changes
    end

    test "handles deeply nested changes" do
      a = %{a: %{b: %{c: 1}}}
      b = %{a: %{b: %{c: 2}}}
      changes = Snapshot.diff(a, b)
      assert [{:changed, [:a, :b, :c], 1, 2}] = changes
    end

    test "does not recurse into structs" do
      a = %{ts: ~U[2026-01-01 00:00:00Z]}
      b = %{ts: ~U[2026-01-02 00:00:00Z]}
      changes = Snapshot.diff(a, b)
      assert [{:changed, [:ts], ~U[2026-01-01 00:00:00Z], ~U[2026-01-02 00:00:00Z]}] = changes
    end

    test "handles multiple changes at once" do
      a = %{x: 1, y: 2, z: 3}
      b = %{x: 10, y: 2, z: 30}
      changes = Snapshot.diff(a, b)

      assert length(changes) == 2
      assert {:changed, [:x], 1, 10} in changes
      assert {:changed, [:z], 3, 30} in changes
    end

    test "handles mixed adds, removes, and changes" do
      a = %{keep: 1, change: 2, remove: 3}
      b = %{keep: 1, change: 20, add: 4}
      changes = Snapshot.diff(a, b)

      assert length(changes) == 3
      assert {:changed, [:change], 2, 20} in changes
      assert {:removed, [:remove], 3} in changes
      assert {:added, [:add], 4} in changes
    end
  end

  describe "diff/2 with snapshots" do
    test "diffs model_after of two snapshots" do
      s1 = Snapshot.new(0, :a, %{}, %{count: 1})
      s2 = Snapshot.new(1, :b, %{count: 1}, %{count: 2})
      changes = Snapshot.diff(s1, s2)
      assert [{:changed, [:count], 1, 2}] = changes
    end

    test "diffs snapshot against a plain map" do
      snap = Snapshot.new(0, :a, %{}, %{count: 1})
      changes = Snapshot.diff(snap, %{count: 5})
      assert [{:changed, [:count], 1, 5}] = changes
    end
  end

  describe "diff/2 with non-map values" do
    test "detects change for non-map values" do
      a = %{val: [1, 2, 3]}
      b = %{val: [1, 2, 4]}
      changes = Snapshot.diff(a, b)
      assert [{:changed, [:val], [1, 2, 3], [1, 2, 4]}] = changes
    end
  end
end
