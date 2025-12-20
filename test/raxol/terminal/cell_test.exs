defmodule Raxol.Terminal.CellTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Cell

  describe "Cell" do
    test "new/0 creates an empty cell" do
      cell = Cell.new()
      assert cell.char == " "
      assert cell.style == TextFormatting.new()
    end

    test "new/1 creates a cell with a character" do
      cell = Cell.new("A")
      assert cell.char == "A"
      assert cell.style == TextFormatting.new()
    end

    test "new/2 creates a new cell with character and style" do
      style =
        TextFormatting.new()
        |> TextFormatting.apply_attribute(:bold)
        |> TextFormatting.apply_attribute(:reverse)

      cell = Cell.new("A", style)
      assert cell.char == "A"
      assert cell.style == style
      assert Cell.has_attribute?(cell, :bold)
      assert Cell.has_attribute?(cell, :reverse)
    end

    test "get_char/1 returns the cell's character" do
      cell = Cell.new("A")
      assert Cell.get_char(cell) == "A"
    end

    test "get_style/1 returns the cell's style" do
      style = TextFormatting.new()
      # Use space as default char
      cell = Cell.new(" ", style)
      assert Cell.get_style(cell) == style
    end

    test "set_char/2 updates the cell's character" do
      cell = Cell.new()
      new_cell = Cell.set_char(cell, "B")
      assert new_cell.char == "B"
      # Style should be preserved
      assert new_cell.style == cell.style
    end

    test "set_style/2 updates the cell's style" do
      cell = Cell.new("A")

      new_style =
        TextFormatting.new() |> TextFormatting.apply_attribute(:underline)

      new_cell = Cell.set_style(cell, new_style)
      # Character should be preserved
      assert new_cell.char == cell.char
      assert new_cell.style == new_style
      assert Cell.has_attribute?(new_cell, :underline)
    end

    test "merge_style/2 merges the given style into the cell's style" do
      initial_style =
        TextFormatting.new() |> TextFormatting.apply_attribute(:bold)

      cell = Cell.new("A", initial_style)

      merge_style =
        TextFormatting.new() |> TextFormatting.apply_attribute(:underline)

      merged_cell = Cell.merge_style(cell, merge_style)
      assert merged_cell.char == "A"
      assert Cell.has_attribute?(merged_cell, :bold)
      assert Cell.has_attribute?(merged_cell, :underline)
    end

    test "has_attribute?/2 checks if the cell has a specific attribute" do
      style = TextFormatting.new() |> TextFormatting.apply_attribute(:bold)
      cell = Cell.new("A", style)
      assert Cell.has_attribute?(cell, :bold)
      refute Cell.has_attribute?(cell, :underline)
    end

    test "double_width?/1 checks if the cell is double width" do
      double_width_style =
        TextFormatting.new() |> TextFormatting.set_double_width()

      double_width_cell = Cell.new("W", double_width_style)
      assert Cell.double_width?(double_width_cell)

      # Create a cell without double width explicitly
      single_width_style = TextFormatting.new()
      single_width_cell = Cell.new("S", single_width_style)
      refute Cell.double_width?(single_width_cell)

      # Default cell should not be double width
      default_cell = Cell.new()
      refute Cell.double_width?(default_cell)
    end

    test "double_height?/1 checks if the cell is double height" do
      double_height_style =
        TextFormatting.new() |> TextFormatting.set_double_height_top()

      double_height_cell = Cell.new("H", double_height_style)
      assert Cell.double_height?(double_height_cell)

      # Create a cell without double height explicitly
      single_height_style = TextFormatting.new()
      single_height_cell = Cell.new("S", single_height_style)
      refute Cell.double_height?(single_height_cell)

      # Default cell should not be double height
      default_cell = Cell.new()
      refute Cell.double_height?(default_cell)
    end

    test "empty?/1 checks if the cell is empty" do
      empty_cell = Cell.new()
      assert Cell.empty?(empty_cell)

      non_empty_cell_char = Cell.new("A")
      refute Cell.empty?(non_empty_cell_char)

      non_empty_cell_style =
        Cell.new(
          " ",
          TextFormatting.new() |> TextFormatting.apply_attribute(:bold)
        )

      refute Cell.empty?(non_empty_cell_style)
    end

    test "with_attributes/2 returns a new cell with merged attributes" do
      initial_style =
        TextFormatting.new() |> TextFormatting.apply_attribute(:bold)

      cell = Cell.new("A", initial_style)
      new_cell = Cell.with_attributes(cell, [:underline, :reverse])

      assert new_cell.char == "A"
      assert Cell.has_attribute?(new_cell, :bold)
      assert Cell.has_attribute?(new_cell, :underline)
      assert Cell.has_attribute?(new_cell, :reverse)
      # Ensure original cell is unchanged
      assert Cell.has_attribute?(cell, :bold)
      refute Cell.has_attribute?(cell, :underline)
    end

    test "with_char/2 returns a new cell with the specified character" do
      style = TextFormatting.new() |> TextFormatting.apply_attribute(:bold)
      cell = Cell.new("A", style)
      new_cell = Cell.with_char(cell, "B")

      assert new_cell.char == "B"
      # Style should be preserved
      assert new_cell.style == style
      assert Cell.has_attribute?(new_cell, :bold)
      # Ensure original cell is unchanged
      assert cell.char == "A"
    end

    test "copy/1 creates a deep copy of the cell" do
      original_style =
        TextFormatting.new() |> TextFormatting.apply_attribute(:bold)

      original_cell = Cell.new("A", original_style)
      copied_cell = Cell.copy(original_cell)

      assert copied_cell.char == original_cell.char
      assert copied_cell.style == original_cell.style
      assert Cell.has_attribute?(copied_cell, :bold)

      # Modify the original cell and check if the copy is affected
      modified_original_cell = Cell.set_char(original_cell, "B")

      modified_original_cell =
        Cell.merge_style(
          modified_original_cell,
          TextFormatting.new() |> TextFormatting.apply_attribute(:underline)
        )

      # Check if copied cell remains unchanged
      assert copied_cell.char == "A"
      assert Cell.has_attribute?(copied_cell, :bold)
      refute Cell.has_attribute?(copied_cell, :underline)

      # Instead of assigning to an unused variable, just make the calls
      Cell.set_char(copied_cell, "C")
      |> Cell.merge_style(
        TextFormatting.new()
        |> TextFormatting.apply_attribute(:reverse)
      )

      # Check if original cell remains unchanged (after its initial modification)
      assert modified_original_cell.char == "B"
      assert Cell.has_attribute?(modified_original_cell, :bold)
      assert Cell.has_attribute?(modified_original_cell, :underline)
      refute Cell.has_attribute?(modified_original_cell, :reverse)
    end

    test "equals?/2 compares cells based on character and style" do
      style1 = TextFormatting.new() |> TextFormatting.apply_attribute(:bold)
      style2 = TextFormatting.new() |> TextFormatting.apply_attribute(:bold)

      style3 =
        TextFormatting.new() |> TextFormatting.apply_attribute(:underline)

      cell1 = Cell.new("A", style1)
      # Same char and style attributes
      cell2 = Cell.new("A", style2)
      # Different char
      cell3 = Cell.new("B", style1)
      # Different style
      cell4 = Cell.new("A", style3)

      assert Cell.equals?(cell1, cell2)
      refute Cell.equals?(cell1, cell3)
      refute Cell.equals?(cell1, cell4)
      refute Cell.equals?(cell1, nil)
      refute Cell.equals?(nil, cell1)
      # Consider if nil comparison is intended behavior
      assert Cell.equals?(nil, nil)
    end
  end
end
