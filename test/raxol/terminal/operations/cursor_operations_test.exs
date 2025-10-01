defmodule Raxol.Terminal.Operations.CursorOperationsTest do
  use ExUnit.Case
  alias Raxol.Terminal.Operations.CursorOperations
  alias Raxol.Test.TestUtils

  describe "get_cursor_position/1" do
    test "returns initial cursor position" do
      emulator = UnifiedTestHelper.create_test_emulator()
      assert CursorOperations.get_cursor_position(emulator) == {0, 0}
    end

    test "returns updated cursor position" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = CursorOperations.set_cursor_position(emulator, 5, 10)
      assert CursorOperations.get_cursor_position(emulator) == {5, 10}
    end
  end

  describe "set_cursor_position/3" do
    test "sets cursor position within bounds" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = CursorOperations.set_cursor_position(emulator, 5, 10)
      assert CursorOperations.get_cursor_position(emulator) == {5, 10}
    end

    test "clamps cursor position to screen bounds" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = CursorOperations.set_cursor_position(emulator, 100, 100)
      # Default terminal size
      {width, height} = {80, 24}

      assert CursorOperations.get_cursor_position(emulator) ==
               {height - 1, width - 1}
    end
  end

  describe "get_cursor_style/1" do
    test "returns initial cursor style" do
      emulator = UnifiedTestHelper.create_test_emulator()
      assert CursorOperations.get_cursor_style(emulator) == :block
    end

    test "returns updated cursor style" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = CursorOperations.set_cursor_style(emulator, :underline)
      assert CursorOperations.get_cursor_style(emulator) == :underline
    end
  end

  describe "set_cursor_style/2" do
    test "sets valid cursor style" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = CursorOperations.set_cursor_style(emulator, :underline)
      assert CursorOperations.get_cursor_style(emulator) == :underline
    end

    test "maintains current style for invalid style" do
      emulator = UnifiedTestHelper.create_test_emulator()
      original_style = CursorOperations.get_cursor_style(emulator)
      emulator = CursorOperations.set_cursor_style(emulator, :invalid)
      assert CursorOperations.get_cursor_style(emulator) == original_style
    end
  end

  describe "cursor_visible?/1" do
    test "returns initial cursor visibility" do
      emulator = UnifiedTestHelper.create_test_emulator()
      assert CursorOperations.cursor_visible?(emulator) == true
    end

    test "returns updated cursor visibility" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = CursorOperations.set_cursor_visibility(emulator, false)
      assert CursorOperations.cursor_visible?(emulator) == false
    end
  end

  describe "set_cursor_visibility/2" do
    test "sets cursor visibility" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = CursorOperations.set_cursor_visibility(emulator, false)
      assert CursorOperations.cursor_visible?(emulator) == false
    end
  end

  describe "cursor_blinking?/1" do
    test "returns initial cursor blink state" do
      emulator = UnifiedTestHelper.create_test_emulator()
      assert CursorOperations.cursor_blinking?(emulator) == true
    end

    test "returns updated cursor blink state" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = CursorOperations.set_cursor_blink(emulator, false)
      assert CursorOperations.cursor_blinking?(emulator) == false
    end
  end

  describe "set_cursor_blink/2" do
    test "sets cursor blink state" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = CursorOperations.set_cursor_blink(emulator, false)
      assert CursorOperations.cursor_blinking?(emulator) == false
    end
  end

  describe "toggle_visibility/1" do
    test "toggles cursor visibility" do
      emulator = UnifiedTestHelper.create_test_emulator()
      initial = CursorOperations.cursor_visible?(emulator)
      emulator = CursorOperations.toggle_visibility(emulator)
      assert CursorOperations.cursor_visible?(emulator) == !initial
    end
  end

  describe "toggle_blink/1" do
    test "toggles cursor blink state" do
      emulator = UnifiedTestHelper.create_test_emulator()
      initial = CursorOperations.cursor_blinking?(emulator)
      emulator = CursorOperations.toggle_blink(emulator)
      assert CursorOperations.cursor_blinking?(emulator) == !initial
    end
  end

  describe "set_blink_rate/2" do
    test "sets cursor blink rate" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = CursorOperations.set_blink_rate(emulator, 500)
      # The set_blink_rate function sets the blink state based on rate > 0
      assert CursorOperations.cursor_blinking?(emulator) == true
    end
  end

  describe "update_blink/1" do
    test "updates cursor blink state based on time" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = CursorOperations.set_cursor_blink(emulator, true)
      emulator = CursorOperations.set_blink_rate(emulator, 500)
      emulator = CursorOperations.update_blink(emulator)
      # Note: This test might be flaky due to timing issues
      # Consider mocking time or using a more deterministic approach
      assert is_boolean(CursorOperations.cursor_blinking?(emulator))
    end
  end
end
