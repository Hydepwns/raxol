defmodule Raxol.Terminal.Operations.TextOperationsTest do
  use ExUnit.Case
  alias Raxol.Terminal.{Operations.TextOperations, TestHelper}

  describe "write_string/5" do
    test "writes string at specified position" do
      emulator = TestHelper.create_test_emulator()
      emulator = TextOperations.write_string(emulator, 0, 0, "test", %{})
      assert TextOperations.get_line(emulator, 0) == "test"
    end

    test "writes string with style" do
      emulator = TestHelper.create_test_emulator()
      style = %{fg: :red, bg: :blue}
      emulator = TextOperations.write_string(emulator, 0, 0, "test", style)
      cell = TextOperations.get_cell_at(emulator, 0, 0)
      assert cell.style == style
    end

    test "writes string at different positions" do
      emulator = TestHelper.create_test_emulator()
      emulator = TextOperations.write_string(emulator, 5, 3, "test", %{})
      assert TextOperations.get_line(emulator, 3) == "     test"
    end
  end

  describe "get_text_in_region/5" do
    test "gets text within specified region" do
      emulator = TestHelper.create_test_emulator()
      emulator = TextOperations.write_string(emulator, 0, 0, "line1", %{})
      emulator = TextOperations.write_string(emulator, 0, 1, "line2", %{})
      text = TextOperations.get_text_in_region(emulator, 0, 0, 4, 1)
      assert text == "line1\nline2"
    end

    test "handles empty region" do
      emulator = TestHelper.create_test_emulator()
      text = TextOperations.get_text_in_region(emulator, 0, 0, 0, 0)
      assert text == ""
    end

    test "handles out of bounds region" do
      emulator = TestHelper.create_test_emulator()
      text = TextOperations.get_text_in_region(emulator, 100, 100, 200, 200)
      assert text == ""
    end
  end

  describe "get_content/1" do
    test "gets entire screen content" do
      emulator = TestHelper.create_test_emulator()
      emulator = TextOperations.write_string(emulator, 0, 0, "line1", %{})
      emulator = TextOperations.write_string(emulator, 0, 1, "line2", %{})
      content = TextOperations.get_content(emulator)
      assert content == "line1\nline2"
    end

    test "returns empty string for empty screen" do
      emulator = TestHelper.create_test_emulator()
      content = TextOperations.get_content(emulator)
      assert content == ""
    end
  end

  describe "get_line/2" do
    test "gets content of specified line" do
      emulator = TestHelper.create_test_emulator()
      emulator = TextOperations.write_string(emulator, 0, 0, "test", %{})
      line = TextOperations.get_line(emulator, 0)
      assert line == "test"
    end

    test "returns empty string for empty line" do
      emulator = TestHelper.create_test_emulator()
      line = TextOperations.get_line(emulator, 0)
      assert line == ""
    end

    test "handles out of bounds line" do
      emulator = TestHelper.create_test_emulator()
      line = TextOperations.get_line(emulator, 100)
      assert line == ""
    end
  end

  describe "get_cell_at/3" do
    test "gets cell at specified position" do
      emulator = TestHelper.create_test_emulator()
      style = %{fg: :red, bg: :blue}
      emulator = TextOperations.write_string(emulator, 0, 0, "test", style)
      cell = TextOperations.get_cell_at(emulator, 0, 0)
      assert cell.char == "t"
      assert cell.style == style
    end

    test "returns empty cell for empty position" do
      emulator = TestHelper.create_test_emulator()
      cell = TextOperations.get_cell_at(emulator, 0, 0)
      assert cell.char == " "
      assert cell.style == %{}
    end

    test "handles out of bounds position" do
      emulator = TestHelper.create_test_emulator()
      cell = TextOperations.get_cell_at(emulator, 100, 100)
      assert cell.char == " "
      assert cell.style == %{}
    end
  end
end
