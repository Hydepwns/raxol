defmodule Raxol.Terminal.CellTest do
  use ExUnit.Case
  alias Raxol.Terminal.Cell

  describe "new/0" do
    test "creates an empty cell" do
      cell = Cell.new()
      assert Cell.is_empty?(cell)
      assert cell.char == " "
      assert cell.attributes == %{}
    end
  end

  describe "new/2" do
    test "creates a cell with character and attributes" do
      cell = Cell.new("A", %{foreground: :red, background: :blue})
      assert cell.char == "A"
      assert cell.attributes == %{foreground: :red, background: :blue}
    end
  end

  describe "get_char/1" do
    test "gets the character from a cell" do
      cell = Cell.new("A")
      assert Cell.get_char(cell) == "A"
    end
  end

  describe "set_char/2" do
    test "sets the character in a cell" do
      cell = Cell.new()
      cell = Cell.set_char(cell, "B")
      assert Cell.get_char(cell) == "B"
    end
  end

  describe "get_attribute/2" do
    test "gets an attribute from a cell" do
      cell = Cell.new("A", %{foreground: :red})
      assert Cell.get_attribute(cell, :foreground) == :red
    end

    test "returns nil for non-existent attribute" do
      cell = Cell.new("A")
      assert Cell.get_attribute(cell, :foreground) == nil
    end
  end

  describe "set_attribute/3" do
    test "sets an attribute in a cell" do
      cell = Cell.new("A")
      cell = Cell.set_attribute(cell, :foreground, :red)
      assert Cell.get_attribute(cell, :foreground) == :red
    end

    test "overwrites existing attribute" do
      cell = Cell.new("A", %{foreground: :red})
      cell = Cell.set_attribute(cell, :foreground, :blue)
      assert Cell.get_attribute(cell, :foreground) == :blue
    end
  end

  describe "remove_attribute/2" do
    test "removes an attribute from a cell" do
      cell = Cell.new("A", %{foreground: :red})
      cell = Cell.remove_attribute(cell, :foreground)
      assert Cell.get_attribute(cell, :foreground) == nil
    end

    test "does nothing for non-existent attribute" do
      cell = Cell.new("A")
      cell = Cell.remove_attribute(cell, :foreground)
      assert cell.attributes == %{}
    end
  end

  describe "is_empty?/1" do
    test "returns true for empty cell" do
      cell = Cell.new()
      assert Cell.is_empty?(cell)
    end

    test "returns false for non-empty cell" do
      cell = Cell.new("A")
      refute Cell.is_empty?(cell)
    end
  end

  describe "merge_attributes/2" do
    test "merges attributes from another cell" do
      cell1 = Cell.new("A", %{foreground: :red})
      cell2 = Cell.new("B", %{background: :blue})
      cell = Cell.merge_attributes(cell1, cell2)

      assert Cell.get_attribute(cell, :foreground) == :red
      assert Cell.get_attribute(cell, :background) == :blue
    end

    test "overwrites existing attributes" do
      cell1 = Cell.new("A", %{foreground: :red})
      cell2 = Cell.new("B", %{foreground: :blue})
      cell = Cell.merge_attributes(cell1, cell2)

      assert Cell.get_attribute(cell, :foreground) == :blue
    end
  end

  describe "copy_with_char/2" do
    test "creates a copy with new character" do
      cell = Cell.new("A", %{foreground: :red})
      new_cell = Cell.copy_with_char(cell, "B")

      assert Cell.get_char(new_cell) == "B"
      assert Cell.get_attribute(new_cell, :foreground) == :red
      assert cell != new_cell
    end
  end

  describe "copy_with_attributes/2" do
    test "creates a copy with new attributes" do
      cell = Cell.new("A", %{foreground: :red})
      new_cell = Cell.copy_with_attributes(cell, %{background: :blue})

      assert Cell.get_char(new_cell) == "A"
      assert Cell.get_attribute(new_cell, :background) == :blue
      assert Cell.get_attribute(new_cell, :foreground) == nil
      assert cell != new_cell
    end
  end

  describe "deep_copy/1" do
    test "creates a deep copy of a cell" do
      cell = Cell.new("A", %{foreground: :red})
      copy = Cell.deep_copy(cell)

      assert Cell.get_char(copy) == "A"
      assert Cell.get_attribute(copy, :foreground) == :red
      assert cell != copy

      # Modify original
      cell = Cell.set_char(cell, "B")
      cell = Cell.set_attribute(cell, :foreground, :blue)

      # Copy should remain unchanged
      assert Cell.get_char(copy) == "A"
      assert Cell.get_attribute(copy, :foreground) == :red
    end
  end

  describe "==/2" do
    test "compares cells for equality" do
      cell1 = Cell.new("A", %{foreground: :red})
      cell2 = Cell.new("A", %{foreground: :red})
      cell3 = Cell.new("B", %{foreground: :red})
      cell4 = Cell.new("A", %{foreground: :blue})

      assert cell1 == cell2
      refute cell1 == cell3
      refute cell1 == cell4
    end
  end
end
