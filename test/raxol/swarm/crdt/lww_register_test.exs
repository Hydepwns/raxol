defmodule Raxol.Swarm.CRDT.LWWRegisterTest do
  use ExUnit.Case, async: true

  alias Raxol.Swarm.CRDT.LWWRegister

  describe "new/2" do
    test "creates a register with value and node" do
      reg = LWWRegister.new(:hello, :node_a)
      assert LWWRegister.value(reg) == :hello
      assert reg.node == :node_a
    end
  end

  describe "update/2" do
    test "updates value and advances timestamp" do
      reg = LWWRegister.new(:old, :node_a)
      updated = LWWRegister.update(reg, :new)
      assert LWWRegister.value(updated) == :new
      assert updated.timestamp >= reg.timestamp
    end
  end

  describe "merge/2" do
    test "keeps the register with the higher timestamp" do
      old = LWWRegister.new(:old, :node_a)
      Process.sleep(1)
      new = LWWRegister.new(:new, :node_b)

      assert LWWRegister.value(LWWRegister.merge(old, new)) == :new
      assert LWWRegister.value(LWWRegister.merge(new, old)) == :new
    end

    test "breaks ties by lexicographic node name" do
      # Force same timestamp by constructing directly
      a = %LWWRegister{value: :a, timestamp: 1000, node: :node_a}
      b = %LWWRegister{value: :b, timestamp: 1000, node: :node_b}

      # node_b > node_a lexicographically
      merged = LWWRegister.merge(a, b)
      assert LWWRegister.value(merged) == :b
    end

    test "is commutative" do
      a = LWWRegister.new(:a, :node_a)
      Process.sleep(1)
      b = LWWRegister.new(:b, :node_b)

      assert LWWRegister.merge(a, b) == LWWRegister.merge(b, a)
    end

    test "is idempotent" do
      reg = LWWRegister.new(:val, :node_a)
      assert LWWRegister.merge(reg, reg) == reg
    end
  end
end
