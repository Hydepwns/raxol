defmodule Raxol.UI.Charts.BrailleCanvasTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Charts.BrailleCanvas

  describe "new/2" do
    test "creates canvas with correct dimensions" do
      canvas = BrailleCanvas.new(10, 5)
      assert {20, 20} = BrailleCanvas.get_dimensions(canvas)
    end
  end

  describe "put_dot/4" do
    test "adds dot to layer" do
      canvas =
        BrailleCanvas.new(5, 5)
        |> BrailleCanvas.put_dot(0, 0, :layer_a)

      assert MapSet.member?(canvas.layers[:layer_a], {0, 0})
    end

    test "out-of-bounds dot is silently ignored" do
      canvas =
        BrailleCanvas.new(5, 5)
        |> BrailleCanvas.put_dot(100, 100, :layer_a)

      assert canvas.layers == %{}
    end

    test "negative coordinates ignored" do
      canvas =
        BrailleCanvas.new(5, 5)
        |> BrailleCanvas.put_dot(-1, 0, :layer_a)

      assert canvas.layers == %{}
    end

    test "multiple layers independent" do
      canvas =
        BrailleCanvas.new(5, 5)
        |> BrailleCanvas.put_dot(0, 0, :a)
        |> BrailleCanvas.put_dot(1, 1, :b)

      assert MapSet.member?(canvas.layers[:a], {0, 0})
      refute MapSet.member?(canvas.layers[:a], {1, 1})
      assert MapSet.member?(canvas.layers[:b], {1, 1})
    end
  end

  describe "to_cells/3" do
    test "empty canvas produces empty braille characters" do
      canvas = BrailleCanvas.new(3, 2)
      cells = BrailleCanvas.to_cells(canvas, {0, 0}, :green)

      assert length(cells) == 3 * 2

      assert Enum.all?(cells, fn {_x, _y, c, fg, bg, _a} ->
               <<cp::utf8>> = c
               cp == 0x2800 and fg == :green and bg == :default
             end)
    end

    test "single dot at (0,0) produces correct braille" do
      canvas =
        BrailleCanvas.new(1, 1)
        |> BrailleCanvas.put_dot(0, 0, :default)

      [{_x, _y, char, _fg, _bg, _a}] = BrailleCanvas.to_cells(canvas, {0, 0}, :white)
      <<cp::utf8>> = char
      # Dot at (0,0) -> bit 0x01
      assert cp == 0x2801
    end

    test "dot at (1,0) produces correct braille" do
      canvas =
        BrailleCanvas.new(1, 1)
        |> BrailleCanvas.put_dot(1, 0, :default)

      [{_x, _y, char, _fg, _bg, _a}] = BrailleCanvas.to_cells(canvas, {0, 0}, :white)
      <<cp::utf8>> = char
      # Dot at (1,0) -> bit 0x08
      assert cp == 0x2808
    end

    test "both dots in first row produce combined braille" do
      canvas =
        BrailleCanvas.new(1, 1)
        |> BrailleCanvas.put_dot(0, 0, :default)
        |> BrailleCanvas.put_dot(1, 0, :default)

      [{_x, _y, char, _fg, _bg, _a}] = BrailleCanvas.to_cells(canvas, {0, 0}, :white)
      <<cp::utf8>> = char
      assert cp == 0x2809
    end

    test "all 8 dots produce full braille" do
      canvas = BrailleCanvas.new(1, 1)

      canvas =
        Enum.reduce(0..1, canvas, fn dx, acc ->
          Enum.reduce(0..3, acc, fn dy, inner_acc ->
            BrailleCanvas.put_dot(inner_acc, dx, dy, :default)
          end)
        end)

      [{_x, _y, char, _fg, _bg, _a}] = BrailleCanvas.to_cells(canvas, {0, 0}, :white)
      <<cp::utf8>> = char
      assert cp == 0x28FF
    end

    test "origin offset applied correctly" do
      canvas = BrailleCanvas.new(2, 2)
      cells = BrailleCanvas.to_cells(canvas, {5, 3}, :green)

      assert Enum.all?(cells, fn {cx, cy, _c, _fg, _bg, _a} ->
               cx >= 5 and cx < 7 and cy >= 3 and cy < 5
             end)
    end
  end

  describe "to_cells_multicolor/3" do
    test "single layer uses that layer's color" do
      canvas =
        BrailleCanvas.new(1, 1)
        |> BrailleCanvas.put_dot(0, 0, :layer_a)

      cells =
        BrailleCanvas.to_cells_multicolor(canvas, {0, 0}, %{layer_a: :red})

      [{_x, _y, _char, fg, _bg, _a}] = cells
      assert fg == :red
    end

    test "majority layer wins color" do
      canvas =
        BrailleCanvas.new(1, 1)
        |> BrailleCanvas.put_dot(0, 0, :a)
        |> BrailleCanvas.put_dot(0, 1, :a)
        |> BrailleCanvas.put_dot(0, 2, :a)
        |> BrailleCanvas.put_dot(1, 0, :b)

      # Layer :a has 3 dots, :b has 1 -> :a wins
      cells =
        BrailleCanvas.to_cells_multicolor(canvas, {0, 0}, %{a: :red, b: :blue})

      [{_x, _y, _char, fg, _bg, _a}] = cells
      assert fg == :red
    end

    test "braille codepoint includes all layers' dots" do
      canvas =
        BrailleCanvas.new(1, 1)
        |> BrailleCanvas.put_dot(0, 0, :a)
        |> BrailleCanvas.put_dot(1, 0, :b)

      cells =
        BrailleCanvas.to_cells_multicolor(canvas, {0, 0}, %{a: :red, b: :blue})

      [{_x, _y, char, _fg, _bg, _a}] = cells
      <<cp::utf8>> = char
      # Both dots present: 0x01 | 0x08 = 0x09
      assert cp == 0x2809
    end

    test "empty canvas still returns cells" do
      canvas = BrailleCanvas.new(2, 2)

      cells =
        BrailleCanvas.to_cells_multicolor(canvas, {0, 0}, %{a: :red})

      assert length(cells) == 4
    end
  end
end
