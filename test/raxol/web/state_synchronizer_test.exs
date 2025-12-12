defmodule Raxol.Web.StateSynchronizerTest do
  use ExUnit.Case, async: true

  alias Raxol.Web.StateSynchronizer
  alias Raxol.Web.StateSynchronizer.{VectorClock, Operation}

  describe "VectorClock" do
    test "new creates empty clock" do
      vc = VectorClock.new()

      assert vc.clock == %{}
    end

    test "increment adds or updates node entry" do
      vc = VectorClock.new()
        |> VectorClock.increment("node1")
        |> VectorClock.increment("node1")
        |> VectorClock.increment("node2")

      assert vc.clock["node1"] == 2
      assert vc.clock["node2"] == 1
    end

    test "merge combines two clocks" do
      vc1 = VectorClock.new()
        |> VectorClock.increment("node1")
        |> VectorClock.increment("node1")

      vc2 = VectorClock.new()
        |> VectorClock.increment("node1")
        |> VectorClock.increment("node2")
        |> VectorClock.increment("node2")

      merged = VectorClock.merge(vc1, vc2)

      assert merged.clock["node1"] == 2
      assert merged.clock["node2"] == 2
    end

    test "compare detects equal clocks" do
      vc1 = VectorClock.new() |> VectorClock.increment("node1")
      vc2 = VectorClock.new() |> VectorClock.increment("node1")

      assert VectorClock.compare(vc1, vc2) == :equal
    end

    test "compare detects less than" do
      vc1 = VectorClock.new() |> VectorClock.increment("node1")
      vc2 = VectorClock.new()
        |> VectorClock.increment("node1")
        |> VectorClock.increment("node1")

      assert VectorClock.compare(vc1, vc2) == :less
    end

    test "compare detects greater than" do
      vc1 = VectorClock.new()
        |> VectorClock.increment("node1")
        |> VectorClock.increment("node1")
      vc2 = VectorClock.new() |> VectorClock.increment("node1")

      assert VectorClock.compare(vc1, vc2) == :greater
    end

    test "compare detects concurrent" do
      vc1 = VectorClock.new() |> VectorClock.increment("node1")
      vc2 = VectorClock.new() |> VectorClock.increment("node2")

      assert VectorClock.compare(vc1, vc2) == :concurrent
    end

    test "happened_before? returns correct result" do
      vc1 = VectorClock.new() |> VectorClock.increment("node1")
      vc2 = VectorClock.new()
        |> VectorClock.increment("node1")
        |> VectorClock.increment("node1")

      assert VectorClock.happened_before?(vc1, vc2) == true
      assert VectorClock.happened_before?(vc2, vc1) == false
    end
  end

  describe "new/2" do
    test "creates new synchronizer" do
      {:ok, sync} = StateSynchronizer.new("session1")

      assert sync.session_id == "session1"
      assert is_binary(sync.node_id)
      assert sync.state == %{}
      assert sync.pending_ops == []
      assert sync.history == []
    end

    test "accepts custom options" do
      {:ok, sync} = StateSynchronizer.new("session1",
        node_id: "custom_node",
        initial_state: %{key: "value"}
      )

      assert sync.node_id == "custom_node"
      assert sync.state == %{key: "value"}
    end
  end

  describe "apply_local/2" do
    test "applies set operation" do
      {:ok, sync} = StateSynchronizer.new("session1")

      {:ok, sync} = StateSynchronizer.apply_local(sync, {:set, "cursor", {5, 10}})

      assert sync.state["cursor"] == {5, 10}
      assert length(sync.pending_ops) == 1
      assert length(sync.history) == 1
    end

    test "applies delete operation" do
      {:ok, sync} = StateSynchronizer.new("session1", initial_state: %{"key" => "value"})

      {:ok, sync} = StateSynchronizer.apply_local(sync, {:delete, "key"})

      assert Map.has_key?(sync.state, "key") == false
    end

    test "applies merge operation" do
      {:ok, sync} = StateSynchronizer.new("session1", initial_state: %{"a" => 1})

      {:ok, sync} = StateSynchronizer.apply_local(sync, {:merge, %{"b" => 2, "c" => 3}})

      assert sync.state["a"] == 1
      assert sync.state["b"] == 2
      assert sync.state["c"] == 3
    end

    test "increments vector clock" do
      {:ok, sync} = StateSynchronizer.new("session1", node_id: "node1")

      {:ok, sync} = StateSynchronizer.apply_local(sync, {:set, "key", "value"})

      assert sync.vector_clock.clock["node1"] == 1

      {:ok, sync} = StateSynchronizer.apply_local(sync, {:set, "key2", "value2"})

      assert sync.vector_clock.clock["node1"] == 2
    end

    test "adds operation to pending" do
      {:ok, sync} = StateSynchronizer.new("session1")

      {:ok, sync} = StateSynchronizer.apply_local(sync, {:set, "k1", "v1"})
      {:ok, sync} = StateSynchronizer.apply_local(sync, {:set, "k2", "v2"})

      assert length(sync.pending_ops) == 2
    end
  end

  describe "apply_remote/2" do
    test "applies remote operation" do
      {:ok, sync1} = StateSynchronizer.new("session1", node_id: "node1")
      {:ok, sync2} = StateSynchronizer.new("session1", node_id: "node2")

      # Create operation on node1
      {:ok, sync1} = StateSynchronizer.apply_local(sync1, {:set, "key", "value"})

      # Get the operation
      [op] = sync1.history

      # Apply to node2
      {:ok, sync2} = StateSynchronizer.apply_remote(sync2, op)

      assert sync2.state["key"] == "value"
    end

    test "skips already seen operations" do
      {:ok, sync1} = StateSynchronizer.new("session1", node_id: "node1")
      {:ok, sync2} = StateSynchronizer.new("session1", node_id: "node2")

      {:ok, sync1} = StateSynchronizer.apply_local(sync1, {:set, "key", "value"})
      [op] = sync1.history

      {:ok, sync2} = StateSynchronizer.apply_remote(sync2, op)
      {:ok, sync2_again} = StateSynchronizer.apply_remote(sync2, op)

      # History should only have one entry for this operation
      matching_ops = Enum.filter(sync2_again.history, fn o -> o.id == op.id end)
      assert length(matching_ops) == 1
    end
  end

  describe "merge/2" do
    test "merges two synchronizers" do
      {:ok, sync1} = StateSynchronizer.new("session1", node_id: "node1")
      {:ok, sync2} = StateSynchronizer.new("session1", node_id: "node2")

      {:ok, sync1} = StateSynchronizer.apply_local(sync1, {:set, "key1", "value1"})
      {:ok, sync2} = StateSynchronizer.apply_local(sync2, {:set, "key2", "value2"})

      {:ok, merged} = StateSynchronizer.merge(sync1, sync2)

      assert merged.state["key1"] == "value1"
      assert merged.state["key2"] == "value2"
    end

    test "merges vector clocks" do
      {:ok, sync1} = StateSynchronizer.new("session1", node_id: "node1")
      {:ok, sync2} = StateSynchronizer.new("session1", node_id: "node2")

      {:ok, sync1} = StateSynchronizer.apply_local(sync1, {:set, "k1", "v1"})
      {:ok, sync1} = StateSynchronizer.apply_local(sync1, {:set, "k2", "v2"})
      {:ok, sync2} = StateSynchronizer.apply_local(sync2, {:set, "k3", "v3"})

      {:ok, merged} = StateSynchronizer.merge(sync1, sync2)

      assert merged.vector_clock.clock["node1"] == 2
      assert merged.vector_clock.clock["node2"] == 1
    end

    test "merges with plain map" do
      {:ok, sync} = StateSynchronizer.new("session1", initial_state: %{"a" => 1})

      {:ok, merged} = StateSynchronizer.merge(sync, %{"b" => 2})

      assert merged.state["a"] == 1
      assert merged.state["b"] == 2
    end
  end

  describe "resolve_conflict/2" do
    test "resolves conflict by timestamp" do
      op1 = %Operation{
        id: "op1",
        timestamp: 1000,
        node_id: "node1"
      }

      op2 = %Operation{
        id: "op2",
        timestamp: 2000,
        node_id: "node2"
      }

      resolved = StateSynchronizer.resolve_conflict(op1, op2)

      assert resolved.id == "op2"
    end

    test "uses node_id as tiebreaker" do
      op1 = %Operation{
        id: "op1",
        timestamp: 1000,
        node_id: "node_a"
      }

      op2 = %Operation{
        id: "op2",
        timestamp: 1000,
        node_id: "node_b"
      }

      resolved = StateSynchronizer.resolve_conflict(op1, op2)

      # node_b > node_a alphabetically
      assert resolved.id == "op2"
    end
  end

  describe "get_state/1" do
    test "returns current state" do
      {:ok, sync} = StateSynchronizer.new("session1", initial_state: %{key: "value"})

      state = StateSynchronizer.get_state(sync)

      assert state == %{key: "value"}
    end
  end

  describe "get_pending_ops/1" do
    test "returns pending operations in order" do
      {:ok, sync} = StateSynchronizer.new("session1")

      {:ok, sync} = StateSynchronizer.apply_local(sync, {:set, "k1", "v1"})
      {:ok, sync} = StateSynchronizer.apply_local(sync, {:set, "k2", "v2"})

      ops = StateSynchronizer.get_pending_ops(sync)

      assert length(ops) == 2
      # First op should be k1
      assert hd(ops).data == {:set, "k1", "v1"}
    end
  end

  describe "clear_pending/1" do
    test "clears pending operations" do
      {:ok, sync} = StateSynchronizer.new("session1")

      {:ok, sync} = StateSynchronizer.apply_local(sync, {:set, "key", "value"})

      assert length(sync.pending_ops) == 1

      sync = StateSynchronizer.clear_pending(sync)

      assert sync.pending_ops == []
    end
  end

  describe "subscribe/2 and unsubscribe/2" do
    test "adds subscriber" do
      {:ok, sync} = StateSynchronizer.new("session1")

      {:ok, sync} = StateSynchronizer.subscribe(sync, self())

      assert self() in sync.subscribers
    end

    test "removes subscriber" do
      {:ok, sync} = StateSynchronizer.new("session1")

      {:ok, sync} = StateSynchronizer.subscribe(sync, self())
      sync = StateSynchronizer.unsubscribe(sync, self())

      assert self() not in sync.subscribers
    end
  end

  describe "get_vector_clock/1" do
    test "returns current vector clock" do
      {:ok, sync} = StateSynchronizer.new("session1", node_id: "node1")

      {:ok, sync} = StateSynchronizer.apply_local(sync, {:set, "key", "value"})

      vc = StateSynchronizer.get_vector_clock(sync)

      assert vc.clock["node1"] == 1
    end
  end

  describe "serialize/1 and deserialize/1" do
    test "round-trips synchronizer state" do
      {:ok, sync} = StateSynchronizer.new("session1", node_id: "node1")

      {:ok, sync} = StateSynchronizer.apply_local(sync, {:set, "key1", "value1"})
      {:ok, sync} = StateSynchronizer.apply_local(sync, {:set, "key2", "value2"})

      binary = StateSynchronizer.serialize(sync)
      {:ok, restored} = StateSynchronizer.deserialize(binary)

      assert restored.session_id == "session1"
      assert restored.node_id == "node1"
      assert restored.state["key1"] == "value1"
      assert restored.state["key2"] == "value2"
      assert length(restored.history) == 2
    end

    test "deserialize returns error for invalid data" do
      assert {:error, _} = StateSynchronizer.deserialize("invalid")
    end
  end
end
