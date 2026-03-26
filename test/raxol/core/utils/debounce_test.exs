defmodule Raxol.Core.Utils.DebounceTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Utils.Debounce

  describe "new/0" do
    test "creates empty debounce state" do
      debounce = Debounce.new()

      assert %Debounce{timers: %{}, ids: %{}} = debounce
    end
  end

  describe "schedule/4" do
    test "returns updated state and a timer reference" do
      debounce = Debounce.new()
      {debounce, ref} = Debounce.schedule(debounce, :save, 100)

      assert is_reference(ref)
      assert Map.has_key?(debounce.timers, :save)
      assert Map.has_key?(debounce.ids, :save)
    end

    test "tracks the timer ref under the given key" do
      debounce = Debounce.new()
      {debounce, ref} = Debounce.schedule(debounce, :save, 100)

      assert debounce.timers[:save] == ref
    end

    test "assigns a positive integer id for the key" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 100)

      assert is_integer(debounce.ids[:save])
      assert debounce.ids[:save] > 0
    end

    test "cancels existing timer when rescheduling the same key" do
      debounce = Debounce.new()
      {debounce, ref1} = Debounce.schedule(debounce, :save, 500)
      {debounce, ref2} = Debounce.schedule(debounce, :save, 500)

      refute ref1 == ref2
      assert debounce.timers[:save] == ref2

      # The old timer should have been cancelled -- its ref should no longer fire
      assert Process.cancel_timer(ref1) == false
    end

    test "generates a new id when rescheduling the same key" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)
      id1 = debounce.ids[:save]

      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)
      id2 = debounce.ids[:save]

      refute id1 == id2
    end

    test "supports multiple independent keys" do
      debounce = Debounce.new()
      {debounce, ref_save} = Debounce.schedule(debounce, :save, 200)
      {debounce, ref_sync} = Debounce.schedule(debounce, :sync, 200)

      assert debounce.timers[:save] == ref_save
      assert debounce.timers[:sync] == ref_sync
      refute ref_save == ref_sync
    end

    test "delivers {:debounce, key, id} message after delay" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 10)
      id = debounce.ids[:save]

      assert_receive {:debounce, :save, ^id}, 200
    end

    test "delivers {:debounce, key, id, data} when data option is provided" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 10, data: %{changed: true})
      id = debounce.ids[:save]

      assert_receive {:debounce, :save, ^id, %{changed: true}}, 200
    end

    test "does not deliver message from cancelled reschedule" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 10)
      old_id = debounce.ids[:save]

      # Reschedule with a longer delay -- the old timer is cancelled
      {_debounce, _ref} = Debounce.schedule(debounce, :save, 500)

      # The old message should not arrive
      refute_receive {:debounce, :save, ^old_id}, 100
    end
  end

  describe "cancel/2" do
    test "removes the key from timers and ids" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)

      debounce = Debounce.cancel(debounce, :save)

      refute Map.has_key?(debounce.timers, :save)
      refute Map.has_key?(debounce.ids, :save)
    end

    test "prevents the message from being delivered" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 10)
      id = debounce.ids[:save]

      _debounce = Debounce.cancel(debounce, :save)

      refute_receive {:debounce, :save, ^id}, 100
    end

    test "is a no-op for a key that was never scheduled" do
      debounce = Debounce.new()
      result = Debounce.cancel(debounce, :nonexistent)

      assert result == debounce
    end

    test "does not affect other keys" do
      debounce = Debounce.new()
      {debounce, ref_sync} = Debounce.schedule(debounce, :sync, 500)
      {debounce, _ref_save} = Debounce.schedule(debounce, :save, 500)

      debounce = Debounce.cancel(debounce, :save)

      assert debounce.timers[:sync] == ref_sync
      assert Map.has_key?(debounce.ids, :sync)
    end
  end

  describe "clear/2" do
    test "removes the key from timers and ids" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)

      debounce = Debounce.clear(debounce, :save)

      refute Map.has_key?(debounce.timers, :save)
      refute Map.has_key?(debounce.ids, :save)
    end

    test "is safe to call for a key that does not exist" do
      debounce = Debounce.new()
      result = Debounce.clear(debounce, :nonexistent)

      assert %Debounce{} = result
    end

    test "does not cancel the timer (unlike cancel/2)" do
      # clear/2 is meant to be called after the timer has already fired,
      # so it only cleans up state -- it does not call safe_cancel.
      # We verify the ref is still valid (not cancelled) after clear.
      debounce = Debounce.new()
      {debounce, ref} = Debounce.schedule(debounce, :save, 500)

      _debounce = Debounce.clear(debounce, :save)

      # The timer ref should still be active since clear does not cancel it
      remaining = Process.cancel_timer(ref)
      assert is_integer(remaining) and remaining > 0
    end
  end

  describe "valid?/3" do
    test "returns true when id matches the current id for the key" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)
      id = debounce.ids[:save]

      assert Debounce.valid?(debounce, :save, id)
    end

    test "returns false when id does not match" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)

      refute Debounce.valid?(debounce, :save, -1)
    end

    test "returns false after rescheduling with a new id" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)
      old_id = debounce.ids[:save]

      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)

      refute Debounce.valid?(debounce, :save, old_id)
    end

    test "returns false for a key that was never scheduled" do
      debounce = Debounce.new()

      refute Debounce.valid?(debounce, :save, 42)
    end

    test "returns false after cancel" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)
      id = debounce.ids[:save]

      debounce = Debounce.cancel(debounce, :save)

      refute Debounce.valid?(debounce, :save, id)
    end

    test "returns false after clear" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)
      id = debounce.ids[:save]

      debounce = Debounce.clear(debounce, :save)

      refute Debounce.valid?(debounce, :save, id)
    end
  end

  describe "pending?/2" do
    test "returns true when key has a scheduled timer" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)

      assert Debounce.pending?(debounce, :save)
    end

    test "returns false when key was never scheduled" do
      debounce = Debounce.new()

      refute Debounce.pending?(debounce, :save)
    end

    test "returns false after cancel" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)
      debounce = Debounce.cancel(debounce, :save)

      refute Debounce.pending?(debounce, :save)
    end

    test "returns false after clear" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)
      debounce = Debounce.clear(debounce, :save)

      refute Debounce.pending?(debounce, :save)
    end
  end

  describe "cancel_all/1" do
    test "returns empty debounce state" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)
      {debounce, _ref} = Debounce.schedule(debounce, :sync, 500)
      {debounce, _ref} = Debounce.schedule(debounce, :flush, 500)

      result = Debounce.cancel_all(debounce)

      assert result.timers == %{}
      assert result.ids == %{}
    end

    test "cancels all pending timers" do
      debounce = Debounce.new()
      {debounce, ref1} = Debounce.schedule(debounce, :save, 500)
      {debounce, ref2} = Debounce.schedule(debounce, :sync, 500)

      _result = Debounce.cancel_all(debounce)

      assert Process.cancel_timer(ref1) == false
      assert Process.cancel_timer(ref2) == false
    end

    test "prevents all pending messages from being delivered" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 10)
      {debounce, _ref} = Debounce.schedule(debounce, :sync, 10)

      _result = Debounce.cancel_all(debounce)

      refute_receive {:debounce, :save, _}, 100
      refute_receive {:debounce, :sync, _}, 50
    end

    test "is safe on empty debounce state" do
      debounce = Debounce.new()
      result = Debounce.cancel_all(debounce)

      assert result.timers == %{}
      assert result.ids == %{}
    end
  end

  describe "pending_keys/1" do
    test "returns empty list for new debounce state" do
      debounce = Debounce.new()

      assert Debounce.pending_keys(debounce) == []
    end

    test "returns all scheduled keys" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)
      {debounce, _ref} = Debounce.schedule(debounce, :sync, 500)

      keys = Debounce.pending_keys(debounce)

      assert Enum.sort(keys) == [:save, :sync]
    end

    test "excludes cancelled keys" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)
      {debounce, _ref} = Debounce.schedule(debounce, :sync, 500)
      debounce = Debounce.cancel(debounce, :save)

      assert Debounce.pending_keys(debounce) == [:sync]
    end

    test "excludes cleared keys" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)
      {debounce, _ref} = Debounce.schedule(debounce, :sync, 500)
      debounce = Debounce.clear(debounce, :sync)

      assert Debounce.pending_keys(debounce) == [:save]
    end
  end

  describe "fire_now/2" do
    test "returns {:fire, key, debounce} when key is pending" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)

      assert {:fire, :save, new_debounce} = Debounce.fire_now(debounce, :save)
      refute Map.has_key?(new_debounce.timers, :save)
      refute Map.has_key?(new_debounce.ids, :save)
    end

    test "returns {:nothing, debounce} when key is not pending" do
      debounce = Debounce.new()

      assert {:nothing, ^debounce} = Debounce.fire_now(debounce, :save)
    end

    test "cancels the timer so the delayed message is not delivered" do
      debounce = Debounce.new()
      {debounce, ref} = Debounce.schedule(debounce, :save, 10)

      {:fire, :save, _debounce} = Debounce.fire_now(debounce, :save)

      # Timer should be cancelled
      assert Process.cancel_timer(ref) == false
      refute_receive {:debounce, :save, _}, 100
    end

    test "does not affect other pending keys" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)
      {debounce, ref_sync} = Debounce.schedule(debounce, :sync, 500)

      {:fire, :save, debounce} = Debounce.fire_now(debounce, :save)

      assert debounce.timers[:sync] == ref_sync
      assert Debounce.pending?(debounce, :sync)
    end
  end

  describe "end-to-end debounce flow" do
    test "schedule, receive, validate, and clear" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 10)
      id = debounce.ids[:save]

      assert_receive {:debounce, :save, ^id}, 200

      assert Debounce.valid?(debounce, :save, id)
      debounce = Debounce.clear(debounce, :save)

      refute Debounce.pending?(debounce, :save)
      assert debounce.timers == %{}
      assert debounce.ids == %{}
    end

    test "rapid rescheduling only delivers the last message" do
      debounce = Debounce.new()

      # Schedule and reschedule rapidly 5 times
      {debounce, _ref} = Debounce.schedule(debounce, :save, 10)
      {debounce, _ref} = Debounce.schedule(debounce, :save, 10)
      {debounce, _ref} = Debounce.schedule(debounce, :save, 10)
      {debounce, _ref} = Debounce.schedule(debounce, :save, 10)
      {debounce, _ref} = Debounce.schedule(debounce, :save, 10)
      final_id = debounce.ids[:save]

      # Only the final message should arrive
      assert_receive {:debounce, :save, ^final_id}, 200

      # No other :save messages should be in the mailbox
      refute_receive {:debounce, :save, _}, 50
    end

    test "stale message is detected via valid?/3" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 10)
      stale_id = debounce.ids[:save]

      # Reschedule with longer delay -- old timer may still deliver
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)

      # Even if a stale message somehow arrives, valid? rejects it
      refute Debounce.valid?(debounce, :save, stale_id)
    end

    test "fire_now followed by schedule works correctly" do
      debounce = Debounce.new()
      {debounce, _ref} = Debounce.schedule(debounce, :save, 500)

      {:fire, :save, debounce} = Debounce.fire_now(debounce, :save)
      refute Debounce.pending?(debounce, :save)

      # Re-schedule after firing
      {debounce, _ref} = Debounce.schedule(debounce, :save, 10)
      new_id = debounce.ids[:save]

      assert Debounce.pending?(debounce, :save)
      assert_receive {:debounce, :save, ^new_id}, 200
    end
  end
end
