defmodule Raxol.Terminal.Operations.ScrollOperationsTest do
  use ExUnit.Case
  alias Raxol.Terminal.{Operations.ScrollOperations, TestHelper}
  alias Raxol.Test.UnifiedTestHelper

  # Add a simple test to verify the test infrastructure
  test "test infrastructure is working" do
    emulator = UnifiedTestHelper.create_test_emulator()

    # Verify emulator has required fields
    assert emulator.height == 24
    assert emulator.width == 80

    # Verify main screen buffer has required fields
    assert emulator.main_screen_buffer.height == 24
    assert emulator.main_screen_buffer.width == 80

    # Verify alternate screen buffer has required fields
    assert emulator.alternate_screen_buffer.height == 24
    assert emulator.alternate_screen_buffer.width == 80
  end

  describe "get_scroll_region/1" do
    test "returns full screen region by default" do
      emulator = UnifiedTestHelper.create_test_emulator()
      region = ScrollOperations.get_scroll_region(emulator)
      # Assuming 24 lines (0-23)
      assert region == {0, 23}
    end

    test "returns custom scroll region" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = ScrollOperations.set_scroll_region(emulator, 5, 15)
      region = ScrollOperations.get_scroll_region(emulator)
      assert region == {5, 15}
    end
  end

  describe "set_scroll_region/3" do
    test "sets scroll region within bounds" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = ScrollOperations.set_scroll_region(emulator, 5, 15)
      region = ScrollOperations.get_scroll_region(emulator)
      assert region == {5, 15}
    end

    test "clamps scroll region to screen bounds" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = ScrollOperations.set_scroll_region(emulator, -5, 30)
      region = ScrollOperations.get_scroll_region(emulator)
      # Assuming 24 lines (0-23)
      assert region == {0, 23}
    end

    test "swaps start and end if start > end" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = ScrollOperations.set_scroll_region(emulator, 15, 5)
      region = ScrollOperations.get_scroll_region(emulator)
      assert region == {5, 15}
    end
  end

  describe "scroll_up/2" do
    test "scrolls up within scroll region" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = ScrollOperations.write_string(emulator, 0, 5, "line1", %{})
      emulator = ScrollOperations.write_string(emulator, 0, 6, "line2", %{})
      emulator = ScrollOperations.set_scroll_region(emulator, 5, 7)
      emulator = ScrollOperations.scroll_up(emulator, 1)
      assert ScrollOperations.get_line(emulator, 5) == "line2"
      assert ScrollOperations.get_line(emulator, 6) == ""
    end

    test "does not scroll outside scroll region" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = ScrollOperations.write_string(emulator, 0, 4, "before", %{})
      emulator = ScrollOperations.write_string(emulator, 0, 5, "line1", %{})
      emulator = ScrollOperations.write_string(emulator, 0, 6, "line2", %{})
      emulator = ScrollOperations.write_string(emulator, 0, 7, "after", %{})
      emulator = ScrollOperations.set_scroll_region(emulator, 5, 6)
      emulator = ScrollOperations.scroll_up(emulator, 1)
      assert ScrollOperations.get_line(emulator, 4) == "before"
      assert ScrollOperations.get_line(emulator, 7) == "after"
    end
  end

  describe "scroll_down/2" do
    test "scrolls down within scroll region" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = ScrollOperations.write_string(emulator, 0, 5, "line1", %{})
      emulator = ScrollOperations.write_string(emulator, 0, 6, "line2", %{})
      emulator = ScrollOperations.set_scroll_region(emulator, 5, 7)
      emulator = ScrollOperations.scroll_down(emulator, 1)
      assert ScrollOperations.get_line(emulator, 6) == "line1"
      assert ScrollOperations.get_line(emulator, 7) == "line2"
    end

    test "does not scroll outside scroll region" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = ScrollOperations.write_string(emulator, 0, 4, "before", %{})
      emulator = ScrollOperations.write_string(emulator, 0, 5, "line1", %{})
      emulator = ScrollOperations.write_string(emulator, 0, 6, "line2", %{})
      emulator = ScrollOperations.write_string(emulator, 0, 7, "after", %{})
      emulator = ScrollOperations.set_scroll_region(emulator, 5, 6)
      emulator = ScrollOperations.scroll_down(emulator, 1)
      assert ScrollOperations.get_line(emulator, 4) == "before"
      assert ScrollOperations.get_line(emulator, 7) == "after"
    end
  end

  describe "scroll_to/2" do
    test "scrolls to specified line" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = ScrollOperations.write_string(emulator, 0, 5, "line1", %{})
      emulator = ScrollOperations.write_string(emulator, 0, 6, "line2", %{})
      emulator = ScrollOperations.write_string(emulator, 0, 7, "line3", %{})
      emulator = ScrollOperations.set_scroll_region(emulator, 5, 7)
      emulator = ScrollOperations.scroll_to(emulator, 6)
      assert ScrollOperations.get_line(emulator, 5) == "line2"
      assert ScrollOperations.get_line(emulator, 6) == "line3"
    end

    test "clamps scroll position to region bounds" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = ScrollOperations.set_scroll_region(emulator, 5, 7)
      emulator = ScrollOperations.scroll_to(emulator, 10)
      region = ScrollOperations.get_scroll_region(emulator)
      assert region == {5, 7}
    end
  end

  describe "get_scroll_position/1" do
    test "returns current scroll position" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = ScrollOperations.set_scroll_region(emulator, 5, 7)
      emulator = ScrollOperations.scroll_to(emulator, 6)
      position = ScrollOperations.get_scroll_position(emulator)
      assert position == 6
    end
  end

  describe "reset_scroll_region/1" do
    test "resets scroll region to full screen" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = ScrollOperations.set_scroll_region(emulator, 5, 15)
      emulator = ScrollOperations.reset_scroll_region(emulator)
      region = ScrollOperations.get_scroll_region(emulator)
      # Assuming 24 lines (0-23)
      assert region == {0, 23}
    end
  end
end
