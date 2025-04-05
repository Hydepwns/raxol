defmodule Raxol.Terminal.Cursor.ManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Cursor.Manager

  describe "new/0" do
    test "creates a new cursor manager with default values" do
      cursor = Manager.new()
      assert cursor.position == {0, 0}
      assert cursor.saved_position == nil
      assert cursor.style == :block
      assert cursor.state == :visible
      assert cursor.shape == {1, 1}
      assert cursor.blink_rate == 530
      assert cursor.custom_shape == nil
      assert cursor.history == []
      assert cursor.history_index == 0
      assert cursor.history_limit == 100
    end
  end

  describe "move_to/3" do
    test "moves the cursor to a new position" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 5)
      assert cursor.position == {10, 5}
    end
  end

  describe "save_position/1" do
    test "saves the current cursor position" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 5)
      cursor = Manager.save_position(cursor)
      assert cursor.saved_position == {10, 5}
    end
  end

  describe "restore_position/1" do
    test "restores the saved cursor position" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 5)
      cursor = Manager.save_position(cursor)
      cursor = Manager.move_to(cursor, 0, 0)
      cursor = Manager.restore_position(cursor)
      assert cursor.position == {10, 5}
    end

    test "returns cursor unchanged if no saved position" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 5)
      restored = Manager.restore_position(cursor)
      assert restored.position == {10, 5}
    end
  end

  describe "set_style/2" do
    test "sets the cursor style to block" do
      cursor = Manager.new()
      cursor = Manager.set_style(cursor, :block)
      assert cursor.style == :block
      assert cursor.shape == {1, 1}
      assert cursor.custom_shape == nil
    end

    test "sets the cursor style to underline" do
      cursor = Manager.new()
      cursor = Manager.set_style(cursor, :underline)
      assert cursor.style == :underline
      assert cursor.shape == {1, 1}
      assert cursor.custom_shape == nil
    end

    test "sets the cursor style to bar" do
      cursor = Manager.new()
      cursor = Manager.set_style(cursor, :bar)
      assert cursor.style == :bar
      assert cursor.shape == {1, 1}
      assert cursor.custom_shape == nil
    end
  end

  describe "set_custom_shape/3" do
    test "sets a custom cursor shape" do
      cursor = Manager.new()
      cursor = Manager.set_custom_shape(cursor, "█", {2, 1})
      assert cursor.style == :custom
      assert cursor.custom_shape == "█"
      assert cursor.shape == {2, 1}
    end
  end

  describe "set_state/2" do
    test "sets the cursor state to visible" do
      cursor = Manager.new()
      cursor = Manager.set_state(cursor, :visible)
      assert cursor.state == :visible
    end

    test "sets the cursor state to hidden" do
      cursor = Manager.new()
      cursor = Manager.set_state(cursor, :hidden)
      assert cursor.state == :hidden
    end

    test "sets the cursor state to blinking" do
      cursor = Manager.new()
      cursor = Manager.set_state(cursor, :blinking)
      assert cursor.state == :blinking
    end
  end

  describe "update_blink/1" do
    test "returns true for visible cursor" do
      cursor = Manager.new()
      cursor = Manager.set_state(cursor, :visible)
      {_cursor, visible} = Manager.update_blink(cursor)
      assert visible == true
    end

    test "returns false for hidden cursor" do
      cursor = Manager.new()
      cursor = Manager.set_state(cursor, :hidden)
      {_cursor, visible} = Manager.update_blink(cursor)
      assert visible == false
    end

    test "toggles visibility for blinking cursor" do
      cursor = Manager.new()
      cursor = Manager.set_state(cursor, :blinking)
      
      # First update should be visible
      {cursor, visible1} = Manager.update_blink(cursor)
      assert visible1 == true
      
      # Wait for half a blink cycle
      Process.sleep(300)
      
      # Second update should be hidden
      {_cursor, visible2} = Manager.update_blink(cursor)
      assert visible2 == false
    end
  end

  describe "add_to_history/1" do
    test "adds the current cursor state to history" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 5)
      cursor = Manager.set_style(cursor, :underline)
      cursor = Manager.add_to_history(cursor)
      
      assert length(cursor.history) == 1
      assert cursor.history_index == 1
      
      state = hd(cursor.history)
      assert state.position == {10, 5}
      assert state.style == :underline
    end
  end

  describe "restore_from_history/1" do
    test "restores the cursor state from history" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 5)
      cursor = Manager.set_style(cursor, :underline)
      cursor = Manager.add_to_history(cursor)
      
      cursor = Manager.move_to(cursor, 0, 0)
      cursor = Manager.set_style(cursor, :block)
      
      cursor = Manager.restore_from_history(cursor)
      assert cursor.position == {10, 5}
      assert cursor.style == :underline
    end

    test "returns cursor unchanged if history is empty" do
      cursor = Manager.new()
      cursor = Manager.move_to(cursor, 10, 5)
      restored = Manager.restore_from_history(cursor)
      assert restored.position == {10, 5}
    end
  end
end 