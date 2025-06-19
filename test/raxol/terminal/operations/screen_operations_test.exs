defmodule Raxol.Terminal.Operations.ScreenOperationsTest do
  use ExUnit.Case
  alias Raxol.Terminal.{Operations.ScreenOperations, TestHelper}

  describe "clear_screen/1" do
    test "clears entire screen" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScreenOperations.write_string(emulator, 0, 0, "test", %{})
      emulator = ScreenOperations.clear_screen(emulator)
      assert ScreenOperations.get_content(emulator) == ""
    end
  end

  describe "clear_line/1" do
    test "clears current line" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScreenOperations.write_string(emulator, 0, 0, "test", %{})
      emulator = ScreenOperations.clear_line(emulator)
      assert ScreenOperations.get_line(emulator, 0) == ""
    end
  end

  describe "erase_display/1" do
    test "erases entire display" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScreenOperations.write_string(emulator, 0, 0, "test", %{})
      emulator = ScreenOperations.erase_display(emulator)
      assert ScreenOperations.get_content(emulator) == ""
    end
  end

  describe "erase_in_display/1" do
    test "erases from cursor to end of screen" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScreenOperations.write_string(emulator, 0, 0, "test1", %{})
      emulator = ScreenOperations.write_string(emulator, 0, 1, "test2", %{})
      emulator = ScreenOperations.set_cursor_position(emulator, 0, 0)
      emulator = ScreenOperations.erase_in_display(emulator)
      assert ScreenOperations.get_line(emulator, 0) == ""
      assert ScreenOperations.get_line(emulator, 1) == "test2"
    end
  end

  describe "erase_line/1" do
    test "erases entire line" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScreenOperations.write_string(emulator, 0, 0, "test", %{})
      emulator = ScreenOperations.erase_line(emulator)
      assert ScreenOperations.get_line(emulator, 0) == ""
    end
  end

  describe "erase_in_line/1" do
    test "erases from cursor to end of line" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScreenOperations.write_string(emulator, 0, 0, "test1 test2", %{})
      emulator = ScreenOperations.set_cursor_position(emulator, 5, 0)
      emulator = ScreenOperations.erase_in_line(emulator)
      assert ScreenOperations.get_line(emulator, 0) == "test1"
    end
  end

  describe "erase_from_cursor_to_end/1" do
    test "erases from cursor to end of screen" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScreenOperations.write_string(emulator, 0, 0, "test1", %{})
      emulator = ScreenOperations.write_string(emulator, 0, 1, "test2", %{})
      emulator = ScreenOperations.set_cursor_position(emulator, 0, 0)
      emulator = ScreenOperations.erase_from_cursor_to_end(emulator)
      assert ScreenOperations.get_line(emulator, 0) == ""
      assert ScreenOperations.get_line(emulator, 1) == "test2"
    end
  end

  describe "erase_from_start_to_cursor/1" do
    test "erases from start to cursor" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScreenOperations.write_string(emulator, 0, 0, "test1 test2", %{})
      emulator = ScreenOperations.set_cursor_position(emulator, 5, 0)
      emulator = ScreenOperations.erase_from_start_to_cursor(emulator)
      assert ScreenOperations.get_line(emulator, 0) == "test2"
    end
  end

  describe "erase_chars/2" do
    test "erases specified number of characters" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScreenOperations.write_string(emulator, 0, 0, "test1 test2", %{})
      emulator = ScreenOperations.set_cursor_position(emulator, 5, 0)
      emulator = ScreenOperations.erase_chars(emulator, 3)
      assert ScreenOperations.get_line(emulator, 0) == "test1st2"
    end
  end

  describe "delete_chars/2" do
    test "deletes specified number of characters" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScreenOperations.write_string(emulator, 0, 0, "test1 test2", %{})
      emulator = ScreenOperations.set_cursor_position(emulator, 5, 0)
      emulator = ScreenOperations.delete_chars(emulator, 3)
      assert ScreenOperations.get_line(emulator, 0) == "test1st2"
    end
  end

  describe "insert_chars/2" do
    test "inserts specified number of spaces" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScreenOperations.write_string(emulator, 0, 0, "test1 test2", %{})
      emulator = ScreenOperations.set_cursor_position(emulator, 5, 0)
      emulator = ScreenOperations.insert_chars(emulator, 3)
      assert ScreenOperations.get_line(emulator, 0) == "test1   test2"
    end
  end

  describe "delete_lines/2" do
    test "deletes specified number of lines" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScreenOperations.write_string(emulator, 0, 0, "line1", %{})
      emulator = ScreenOperations.write_string(emulator, 0, 1, "line2", %{})
      emulator = ScreenOperations.write_string(emulator, 0, 2, "line3", %{})
      emulator = ScreenOperations.set_cursor_position(emulator, 0, 0)
      emulator = ScreenOperations.delete_lines(emulator, 2)
      assert ScreenOperations.get_line(emulator, 0) == "line3"
      assert ScreenOperations.get_line(emulator, 1) == ""
      assert ScreenOperations.get_line(emulator, 2) == ""
    end
  end

  describe "insert_lines/2" do
    test "inserts specified number of blank lines" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScreenOperations.write_string(emulator, 0, 0, "line1", %{})
      emulator = ScreenOperations.write_string(emulator, 0, 1, "line2", %{})
      emulator = ScreenOperations.set_cursor_position(emulator, 0, 0)
      emulator = ScreenOperations.insert_lines(emulator, 2)
      assert ScreenOperations.get_line(emulator, 0) == ""
      assert ScreenOperations.get_line(emulator, 1) == ""
      assert ScreenOperations.get_line(emulator, 2) == "line1"
      assert ScreenOperations.get_line(emulator, 3) == "line2"
    end
  end

  describe "prepend_lines/2" do
    test "prepends specified number of blank lines" do
      emulator = TestHelper.create_test_emulator()
      emulator = ScreenOperations.write_string(emulator, 0, 0, "line1", %{})
      emulator = ScreenOperations.write_string(emulator, 0, 1, "line2", %{})
      emulator = ScreenOperations.set_cursor_position(emulator, 0, 0)
      emulator = ScreenOperations.prepend_lines(emulator, 2)
      assert ScreenOperations.get_line(emulator, 0) == "line1"
      assert ScreenOperations.get_line(emulator, 1) == "line2"
      assert ScreenOperations.get_line(emulator, 2) == ""
      assert ScreenOperations.get_line(emulator, 3) == ""
    end
  end
end
