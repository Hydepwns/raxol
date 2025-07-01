defmodule Raxol.Terminal.Split.SyncTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Split.Sync

  setup do
    {:ok, pid} = Sync.start_link()
    %{pid: pid}
  end

  describe "event broadcasting" do
    test "broadcasts events to subscribers", %{pid: pid} do
      test_pid = self()
      split_id = 1
      event_type = :test_event
      payload = %{data: "test"}

      # Subscribe to events
      :ok =
        GenServer.call(pid, {:subscribe, split_id, fn event ->
          send(test_pid, {:event_received, event})
        end})

      # Broadcast event
      :ok = GenServer.cast(pid, {:broadcast_event, split_id, event_type, payload})

      # Verify event was received
      assert_receive {:event_received, event}
      assert event.split_id == split_id
      assert event.type == event_type
      assert event.payload == payload
      assert event.timestamp
    end

    test "handles multiple subscribers", %{pid: pid} do
      test_pid = self()
      split_id = 1
      event_type = :test_event
      payload = %{data: "test"}

      # Subscribe multiple times
      :ok =
        GenServer.call(pid, {:subscribe, split_id, fn event ->
          send(test_pid, {:event_received_1, event})
        end})

      :ok =
        GenServer.call(pid, {:subscribe, split_id, fn event ->
          send(test_pid, {:event_received_2, event})
        end})

      # Broadcast event
      :ok = GenServer.cast(pid, {:broadcast_event, split_id, event_type, payload})

      # Verify both subscribers received the event
      assert_receive {:event_received_1, event1}
      assert_receive {:event_received_2, event2}
      assert event1 == event2
    end
  end

  describe "shared state management" do
    test "updates and retrieves shared state", %{pid: pid} do
      split_id = 1
      initial_state = %{key: "value"}
      state_updates = %{new_key: "new_value"}

      # Update state
      updated_state = GenServer.call(pid, {:update_shared_state, split_id, initial_state})
      assert updated_state == initial_state

      # Update state again
      final_state = GenServer.call(pid, {:update_shared_state, split_id, state_updates})
      assert final_state == Map.merge(initial_state, state_updates)

      # Retrieve state
      retrieved_state = GenServer.call(pid, {:get_shared_state, split_id})
      assert retrieved_state == final_state
    end

    test "handles non-existent state", %{pid: pid} do
      split_id = 999
      state = GenServer.call(pid, {:get_shared_state, split_id})
      assert state == %{}
    end
  end

  describe "subscription management" do
    test "unsubscribes from events", %{pid: pid} do
      test_pid = self()
      split_id = 1

      # Subscribe
      :ok =
        GenServer.call(pid, {:subscribe, split_id, fn event ->
          send(test_pid, {:event_received, event})
        end})

      # Unsubscribe
      :ok = GenServer.call(pid, {:unsubscribe, split_id})

      # Broadcast event
      :ok = GenServer.cast(pid, {:broadcast_event, split_id, :test_event, %{data: "test"}})

      # Verify no event was received
      refute_receive {:event_received, _}
    end
  end
end
