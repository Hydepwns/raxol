defmodule Raxol.Terminal.Operations.SelectionOperationsTest do
  use ExUnit.Case
  alias Raxol.Terminal.Operations.SelectionOperations

  describe "get_selection/1" do
    test "returns empty string when no selection" do
      emulator = UnifiedTestHelper.create_test_emulator()
      selection = SelectionOperations.get_selection(emulator)
      assert selection == ""
    end

    test "returns selected text" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = SelectionOperations.write_string(emulator, 0, 0, "test", %{})
      emulator = SelectionOperations.start_selection(emulator, 0, 0)
      emulator = SelectionOperations.update_selection(emulator, 3, 0)
      selection = SelectionOperations.get_selection(emulator)
      assert selection == "test"
    end
  end

  describe "get_selection_start/1" do
    test "returns nil when no selection" do
      emulator = UnifiedTestHelper.create_test_emulator()
      start = SelectionOperations.get_selection_start(emulator)
      assert start == nil
    end

    test "returns selection start coordinates" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = SelectionOperations.start_selection(emulator, 5, 3)
      start = SelectionOperations.get_selection_start(emulator)
      assert start == {5, 3}
    end
  end

  describe "get_selection_end/1" do
    test "returns nil when no selection" do
      emulator = UnifiedTestHelper.create_test_emulator()
      end_pos = SelectionOperations.get_selection_end(emulator)
      assert end_pos == nil
    end

    test "returns selection end coordinates" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = SelectionOperations.start_selection(emulator, 0, 0)
      emulator = SelectionOperations.update_selection(emulator, 5, 3)
      end_pos = SelectionOperations.get_selection_end(emulator)
      assert end_pos == {5, 3}
    end
  end

  describe "get_selection_boundaries/1" do
    test "returns nil when no selection" do
      emulator = UnifiedTestHelper.create_test_emulator()
      boundaries = SelectionOperations.get_selection_boundaries(emulator)
      assert boundaries == nil
    end

    test "returns selection boundaries" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = SelectionOperations.start_selection(emulator, 0, 0)
      emulator = SelectionOperations.update_selection(emulator, 5, 3)
      boundaries = SelectionOperations.get_selection_boundaries(emulator)
      assert boundaries == {{0, 0}, {5, 3}}
    end
  end

  describe "start_selection/3" do
    test "starts selection at specified position" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = SelectionOperations.start_selection(emulator, 5, 3)
      start = SelectionOperations.get_selection_start(emulator)
      assert start == {5, 3}
    end

    test "clears existing selection" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = SelectionOperations.start_selection(emulator, 0, 0)
      emulator = SelectionOperations.update_selection(emulator, 5, 3)
      emulator = SelectionOperations.start_selection(emulator, 1, 1)
      start = SelectionOperations.get_selection_start(emulator)
      end_pos = SelectionOperations.get_selection_end(emulator)
      assert start == {1, 1}
      assert end_pos == nil
    end
  end

  describe "update_selection/3" do
    test "updates selection end position" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = SelectionOperations.start_selection(emulator, 0, 0)
      emulator = SelectionOperations.update_selection(emulator, 5, 3)
      end_pos = SelectionOperations.get_selection_end(emulator)
      assert end_pos == {5, 3}
    end

    test "does nothing when no selection started" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = SelectionOperations.update_selection(emulator, 5, 3)
      end_pos = SelectionOperations.get_selection_end(emulator)
      assert end_pos == nil
    end
  end

  describe "clear_selection/1" do
    test "clears existing selection" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = SelectionOperations.start_selection(emulator, 0, 0)
      emulator = SelectionOperations.update_selection(emulator, 5, 3)
      emulator = SelectionOperations.clear_selection(emulator)
      start = SelectionOperations.get_selection_start(emulator)
      end_pos = SelectionOperations.get_selection_end(emulator)
      assert start == nil
      assert end_pos == nil
    end

    test "does nothing when no selection" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = SelectionOperations.clear_selection(emulator)
      start = SelectionOperations.get_selection_start(emulator)
      end_pos = SelectionOperations.get_selection_end(emulator)
      assert start == nil
      assert end_pos == nil
    end
  end

  describe "selection_active?/1" do
    test "returns false when no selection" do
      emulator = UnifiedTestHelper.create_test_emulator()
      assert SelectionOperations.selection_active?(emulator) == false
    end

    test "returns true when selection exists" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = SelectionOperations.start_selection(emulator, 0, 0)
      emulator = SelectionOperations.update_selection(emulator, 5, 3)
      assert SelectionOperations.selection_active?(emulator) == true
    end
  end

  describe "in_selection?/3" do
    test "returns false when no selection" do
      emulator = UnifiedTestHelper.create_test_emulator()
      assert SelectionOperations.in_selection?(emulator, 0, 0) == false
    end

    test "returns true for position within selection" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = SelectionOperations.start_selection(emulator, 0, 0)
      emulator = SelectionOperations.update_selection(emulator, 5, 3)
      assert SelectionOperations.in_selection?(emulator, 2, 1) == true
    end

    test "returns false for position outside selection" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = SelectionOperations.start_selection(emulator, 0, 0)
      emulator = SelectionOperations.update_selection(emulator, 5, 3)
      assert SelectionOperations.in_selection?(emulator, 10, 10) == false
    end
  end
end
