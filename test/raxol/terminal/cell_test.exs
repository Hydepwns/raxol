defmodule Raxol.Terminal.CellTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Cell

  describe "new/2" do
    test "creates a new cell with default values" do
      cell = Cell.new()
      assert Cell.get_char(cell) == ""
      assert Cell.get_style(cell) == TextFormatting.new()
    end

    test "creates a new cell with character and style" do
      style =
        TextFormatting.new()
        |> TextFormatting.set_attribute(:bold)
        |> TextFormatting.set_foreground(:red)

      cell = Cell.new("A", style)
      assert Cell.get_char(cell) == "A"
      assert Cell.get_style(cell) == style
    end
  end

  describe "get_char/1" do
    test "gets the character from a cell" do
      cell = Cell.new("A")
      assert Cell.get_char(cell) == "A"
    end
  end

  describe "get_style/1" do
    test "gets the style from a cell" do
      style =
        TextFormatting.new()
        |> TextFormatting.set_attribute(:bold)
        |> TextFormatting.set_foreground(:red)

      cell = Cell.new("A", style)
      assert Cell.get_style(cell) == style
    end
  end

  describe "set_char/2" do
    test "sets the character in a cell" do
      cell = Cell.new("A")
      cell = Cell.set_char(cell, "B")
      assert Cell.get_char(cell) == "B"
    end
  end

  describe "set_style/2" do
    test "sets the style in a cell" do
      cell = Cell.new("A")

      style =
        TextFormatting.new()
        |> TextFormatting.set_attribute(:bold)
        |> TextFormatting.set_foreground(:red)

      cell = Cell.set_style(cell, style)
      assert Cell.get_style(cell) == style
    end
  end

  describe "merge_style/2" do
    test "merges styles in a cell" do
      style1 =
        TextFormatting.new()
        |> TextFormatting.set_attribute(:bold)
        |> TextFormatting.set_foreground(:red)

      style2 =
        TextFormatting.new()
        |> TextFormatting.set_attribute(:italic)
        |> TextFormatting.set_background(:blue)

      cell = Cell.new("A", style1)
      cell = Cell.merge_style(cell, style2)

      assert Cell.has_attribute?(cell, :bold)
      assert Cell.has_attribute?(cell, :italic)
      assert Cell.get_style(cell).foreground == :red
      assert Cell.get_style(cell).background == :blue
    end
  end

  describe "has_attribute?/2" do
    test "checks if a cell has a specific attribute" do
      cell = Cell.new("A")

      cell =
        Cell.set_style(
          cell,
          TextFormatting.set_attribute(TextFormatting.new(), :bold)
        )

      assert Cell.has_attribute?(cell, :bold)
      refute Cell.has_attribute?(cell, :italic)
    end
  end

  describe "has_decoration?/2" do
    test "checks if a cell has a specific decoration" do
      cell = Cell.new("A")

      cell =
        Cell.set_style(
          cell,
          TextFormatting.set_decoration(TextFormatting.new(), :underline)
        )

      assert Cell.has_decoration?(cell, :underline)
      refute Cell.has_decoration?(cell, :overline)
    end
  end

  describe "double_width?/1" do
    test "checks if a cell is in double-width mode" do
      cell = Cell.new("A")

      cell =
        Cell.set_style(
          cell,
          TextFormatting.set_double_width(TextFormatting.new(), true)
        )

      assert Cell.double_width?(cell)

      cell =
        Cell.set_style(
          cell,
          TextFormatting.set_double_width(TextFormatting.new(), false)
        )

      refute Cell.double_width?(cell)
    end
  end

  describe "double_height?/1" do
    test "checks if a cell is in double-height mode" do
      cell = Cell.new("A")

      cell =
        Cell.set_style(
          cell,
          TextFormatting.set_double_height(TextFormatting.new(), true)
        )

      assert Cell.double_height?(cell)

      cell =
        Cell.set_style(
          cell,
          TextFormatting.set_double_height(TextFormatting.new(), false)
        )

      refute Cell.double_height?(cell)
    end
  end

  describe "empty?/1" do
    test "checks if a cell is empty" do
      assert Cell.empty?(Cell.new())
      refute Cell.empty?(Cell.new("A"))
    end
  end

  describe "with_attributes/2" do
    test "creates a new cell with merged attributes" do
      cell = Cell.new("A")

      style =
        TextFormatting.new()
        |> TextFormatting.set_attribute(:bold)
        |> TextFormatting.set_foreground(:red)

      new_cell = Cell.with_attributes(cell, style)
      assert Cell.get_char(new_cell) == "A"
      assert Cell.get_style(new_cell) == style
    end
  end

  describe "with_char/2" do
    test "creates a new cell with a different character" do
      cell = Cell.new("A")

      style =
        TextFormatting.new()
        |> TextFormatting.set_attribute(:bold)
        |> TextFormatting.set_foreground(:red)

      cell = Cell.set_style(cell, style)
      new_cell = Cell.with_char(cell, "B")

      assert Cell.get_char(new_cell) == "B"
      assert Cell.get_style(new_cell) == style
    end
  end

  describe "copy/1" do
    test "creates a deep copy of a cell" do
      style =
        TextFormatting.new()
        |> TextFormatting.set_attribute(:bold)
        |> TextFormatting.set_foreground(:red)

      cell = Cell.new("A", style)
      copy = Cell.copy(cell)

      assert Cell.get_char(copy) == "A"
      assert Cell.get_style(copy) == style
      assert copy != cell
    end
  end

  describe "equals?/2" do
    test "checks if two cells are equal" do
      style1 =
        TextFormatting.new()
        |> TextFormatting.set_attribute(:bold)
        |> TextFormatting.set_foreground(:red)

      style2 =
        TextFormatting.new()
        |> TextFormatting.set_attribute(:bold)
        |> TextFormatting.set_foreground(:red)

      cell1 = Cell.new("A", style1)
      cell2 = Cell.new("A", style2)
      cell3 = Cell.new("B", style1)

      assert Cell.equals?(cell1, cell2)
      refute Cell.equals?(cell1, cell3)
    end
  end
end
