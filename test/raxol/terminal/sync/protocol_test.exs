defmodule Raxol.Terminal.Sync.ProtocolTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Sync.Protocol

  describe "message creation" do
    test "creates sync message" do
      message =
        Protocol.create_sync_message("test_split", :split, %{content: "test"})

      assert message.type == :sync
      assert message.component_id == "test_split"
      assert message.component_type == :split
      assert message.state == %{content: "test"}
      assert is_integer(message.metadata.version)
      assert is_integer(message.metadata.timestamp)
      assert message.metadata.consistency == :strong
    end

    test "creates ack message" do
      message = Protocol.create_ack_message("test_split", :split, 123)
      assert message.type == :ack
      assert message.component_id == "test_split"
      assert message.component_type == :split
      assert message.metadata.version == 123
      assert is_integer(message.metadata.timestamp)
    end

    test "creates conflict message" do
      current_state = %{content: "current", version: 1}
      incoming_state = %{content: "incoming", version: 2}

      message =
        Protocol.create_conflict_message(
          "test_split",
          :split,
          current_state,
          incoming_state
        )

      assert message.type == :conflict
      assert message.component_id == "test_split"
      assert message.component_type == :split
      assert message.states.current == current_state
      assert message.states.incoming == incoming_state
      assert is_integer(message.metadata.timestamp)
    end

    test "creates resolve message" do
      resolved_state = %{content: "resolved", version: 3}

      message =
        Protocol.create_resolve_message("test_split", :split, resolved_state, 3)

      assert message.type == :resolve
      assert message.component_id == "test_split"
      assert message.component_type == :split
      assert message.state == resolved_state
      assert message.metadata.version == 3
      assert is_integer(message.metadata.timestamp)
    end
  end

  describe "message validation" do
    test "validates complete message" do
      message =
        Protocol.create_sync_message("test_split", :split, %{content: "test"})

      assert :ok ==
               Protocol.handle_sync_message(message, %{metadata: %{version: 0}})
    end

    test "rejects invalid message" do
      # Missing required fields
      message = %{type: :sync}

      assert {:error, :missing_component_id} ==
               Protocol.handle_sync_message(message, %{metadata: %{version: 0}})
    end
  end

  describe "sync message handling" do
    test "accepts newer version with strong consistency" do
      message =
        Protocol.create_sync_message("test_split", :split, %{content: "new"},
          consistency: :strong
        )

      current_state = %{metadata: %{version: 1, consistency: :strong}}

      assert {:ok, %{content: "new"}, _version} =
               Protocol.handle_sync_message(message, current_state)
    end

    test "rejects older version with strong consistency" do
      message =
        Protocol.create_sync_message("test_split", :split, %{content: "old"},
          consistency: :strong
        )

      current_state = %{metadata: %{version: 2, consistency: :strong}}

      assert {:error, :version_mismatch} =
               Protocol.handle_sync_message(message, current_state)
    end

    test "accepts newer version with eventual consistency" do
      message =
        Protocol.create_sync_message("test_tab", :tab, %{content: "new"},
          consistency: :eventual
        )

      current_state = %{metadata: %{version: 1, consistency: :eventual}}

      assert {:ok, %{content: "new"}, _version} =
               Protocol.handle_sync_message(message, current_state)
    end

    test "reports conflict with same version" do
      message =
        Protocol.create_sync_message("test_tab", :tab, %{content: "conflict"},
          consistency: :eventual
        )

      current_state = %{metadata: %{version: 1, consistency: :eventual}}

      assert {:error, :conflict} =
               Protocol.handle_sync_message(message, current_state)
    end
  end

  describe "ack message handling" do
    test "accepts matching version" do
      message = Protocol.create_ack_message("test_split", :split, 123)
      current_state = %{metadata: %{version: 123}}
      assert :ok == Protocol.handle_ack_message(message, current_state)
    end

    test "rejects mismatched version" do
      message = Protocol.create_ack_message("test_split", :split, 123)
      current_state = %{metadata: %{version: 456}}

      assert {:error, :version_mismatch} =
               Protocol.handle_ack_message(message, current_state)
    end
  end

  describe "conflict message handling" do
    test "resolves conflict with newer version" do
      current_state = %{content: "current", version: 1}
      incoming_state = %{content: "incoming", version: 2}

      message =
        Protocol.create_conflict_message(
          "test_split",
          :split,
          current_state,
          incoming_state
        )

      assert {:ok, ^incoming_state} =
               Protocol.handle_conflict_message(message, current_state)
    end

    test "keeps current state with older version" do
      current_state = %{content: "current", version: 2}
      incoming_state = %{content: "incoming", version: 1}

      message =
        Protocol.create_conflict_message(
          "test_split",
          :split,
          current_state,
          incoming_state
        )

      assert {:ok, ^current_state} =
               Protocol.handle_conflict_message(message, current_state)
    end

    test "reports unresolved conflict with same version" do
      current_state = %{content: "current", version: 1}
      incoming_state = %{content: "incoming", version: 1}

      message =
        Protocol.create_conflict_message(
          "test_split",
          :split,
          current_state,
          incoming_state
        )

      assert {:error, :unresolved_conflict} =
               Protocol.handle_conflict_message(message, current_state)
    end
  end

  describe "resolve message handling" do
    test "accepts newer version" do
      resolved_state = %{content: "resolved", version: 3}

      message =
        Protocol.create_resolve_message("test_split", :split, resolved_state, 3)

      current_state = %{metadata: %{version: 2}}

      assert {:ok, ^resolved_state} =
               Protocol.handle_resolve_message(message, current_state)
    end

    test "rejects older version" do
      resolved_state = %{content: "resolved", version: 1}

      message =
        Protocol.create_resolve_message("test_split", :split, resolved_state, 1)

      current_state = %{metadata: %{version: 2}}

      assert {:error, :version_mismatch} =
               Protocol.handle_resolve_message(message, current_state)
    end
  end

  describe "consistency levels" do
    test "enforces strong consistency for splits" do
      message =
        Protocol.create_sync_message("test_split", :split, %{content: "test"})

      assert message.metadata.consistency == :strong
    end

    test "enforces strong consistency for windows" do
      message =
        Protocol.create_sync_message("test_window", :window, %{content: "test"})

      assert message.metadata.consistency == :strong
    end

    test "uses eventual consistency for tabs" do
      message =
        Protocol.create_sync_message("test_tab", :tab, %{content: "test"})

      assert message.metadata.consistency == :eventual
    end

    test "allows overriding consistency level" do
      message =
        Protocol.create_sync_message("test_split", :split, %{content: "test"},
          consistency: :eventual
        )

      assert message.metadata.consistency == :eventual
    end
  end
end
