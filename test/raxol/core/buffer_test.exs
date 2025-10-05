defmodule Raxol.Core.BufferTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Buffer

  describe "create_blank_buffer/2" do
    test "creates a buffer with specified dimensions" do
      buffer = Buffer.create_blank_buffer(80, 24)
      assert buffer.width == 80
      assert buffer.height == 24
      assert length(buffer.lines) == 24
    end

    test "initializes all cells as blank" do
      buffer = Buffer.create_blank_buffer(10, 5)
      first_line = List.first(buffer.lines)
      first_cell = List.first(first_line.cells)
      assert first_cell.char == " "
      assert first_cell.style == %{}
    end
  end

  describe "write_at/5" do
    test "writes text at specified coordinates" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Buffer.write_at(buffer, 5, 3, "Hello")
      cell = Buffer.get_cell(buffer, 5, 3)
      assert cell.char == "H"
    end

    test "applies style to written text" do
      buffer = Buffer.create_blank_buffer(80, 24)
      style = %{bold: true, fg_color: :red}
      buffer = Buffer.write_at(buffer, 0, 0, "Test", style)
      cell = Buffer.get_cell(buffer, 0, 0)
      assert cell.style == style
    end

    test "handles multi-character strings" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Buffer.write_at(buffer, 0, 0, "Hello World")

      assert Buffer.get_cell(buffer, 0, 0).char == "H"
      assert Buffer.get_cell(buffer, 5, 0).char == " "
      assert Buffer.get_cell(buffer, 10, 0).char == "d"
    end
  end

  describe "get_cell/3" do
    test "retrieves cell at coordinates" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Buffer.write_at(buffer, 10, 5, "X")
      cell = Buffer.get_cell(buffer, 10, 5)
      assert cell.char == "X"
    end

    test "returns nil for out of bounds coordinates" do
      buffer = Buffer.create_blank_buffer(80, 24)
      assert Buffer.get_cell(buffer, 100, 50) == nil
    end
  end

  describe "set_cell/5" do
    test "updates a single cell" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Buffer.set_cell(buffer, 5, 3, "X", %{bold: true})
      cell = Buffer.get_cell(buffer, 5, 3)
      assert cell.char == "X"
      assert cell.style.bold == true
    end
  end

  describe "clear/1" do
    test "resets all cells to blank" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Buffer.write_at(buffer, 0, 0, "Hello World")
      buffer = Buffer.clear(buffer)
      cell = Buffer.get_cell(buffer, 0, 0)
      assert cell.char == " "
    end
  end

  describe "resize/3" do
    test "changes buffer dimensions" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Buffer.resize(buffer, 100, 30)
      assert buffer.width == 100
      assert buffer.height == 30
    end

    test "preserves existing content when growing" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Buffer.write_at(buffer, 0, 0, "Test")
      buffer = Buffer.resize(buffer, 100, 30)
      cell = Buffer.get_cell(buffer, 0, 0)
      assert cell.char == "T"
    end

    test "truncates content when shrinking" do
      buffer = Buffer.create_blank_buffer(80, 24)
      buffer = Buffer.write_at(buffer, 70, 20, "X")
      buffer = Buffer.resize(buffer, 40, 12)
      assert buffer.width == 40
      assert buffer.height == 12
    end
  end

  describe "to_string/1" do
    test "converts buffer to string representation" do
      buffer = Buffer.create_blank_buffer(10, 3)
      buffer = Buffer.write_at(buffer, 0, 0, "Hello")
      buffer = Buffer.write_at(buffer, 0, 1, "World")

      output = Buffer.to_string(buffer)
      assert String.contains?(output, "Hello")
      assert String.contains?(output, "World")
    end
  end
end
