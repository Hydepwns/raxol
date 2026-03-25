defmodule Raxol.Sensor.HUDTest do
  use ExUnit.Case, async: true

  alias Raxol.Sensor.HUD

  describe "render_gauge/3" do
    test "renders a gauge with correct cell format" do
      cells = HUD.render_gauge({0, 0, 30, 1}, 50.0)

      assert length(cells) > 0
      assert Enum.all?(cells, fn cell -> tuple_size(cell) == 6 end)
    end

    test "gauge at 0% is green" do
      cells = HUD.render_gauge({0, 0, 30, 1}, 0.0)
      assert Enum.all?(cells, fn {_x, _y, _c, fg, _bg, _a} -> fg == :green end)
    end

    test "gauge at 70% is yellow" do
      cells = HUD.render_gauge({0, 0, 30, 1}, 70.0)
      assert Enum.all?(cells, fn {_x, _y, _c, fg, _bg, _a} -> fg == :yellow end)
    end

    test "gauge at 90% is red" do
      cells = HUD.render_gauge({0, 0, 30, 1}, 90.0)
      assert Enum.all?(cells, fn {_x, _y, _c, fg, _bg, _a} -> fg == :red end)
    end

    test "gauge with label" do
      cells = HUD.render_gauge({0, 0, 40, 1}, 50.0, label: "FUEL")
      chars = Enum.map(cells, fn {_x, _y, c, _fg, _bg, _a} -> c end) |> Enum.join()
      assert String.contains?(chars, "FUEL")
    end

    test "gauge clamps to region width" do
      cells = HUD.render_gauge({5, 3, 20, 1}, 50.0)
      assert Enum.all?(cells, fn {x, y, _c, _fg, _bg, _a} -> x >= 5 and y == 3 end)
      assert length(cells) <= 20
    end

    test "gauge clamps value to 0-100% range" do
      cells_neg = HUD.render_gauge({0, 0, 30, 1}, -10.0)
      chars = Enum.map(cells_neg, fn {_x, _y, c, _fg, _bg, _a} -> c end) |> Enum.join()
      assert String.contains?(chars, "0%")

      cells_over = HUD.render_gauge({0, 0, 30, 1}, 150.0)
      chars2 = Enum.map(cells_over, fn {_x, _y, c, _fg, _bg, _a} -> c end) |> Enum.join()
      assert String.contains?(chars2, "100%")
    end

    test "custom thresholds" do
      # With threshold at 0.3 warn, 0.5 crit
      cells = HUD.render_gauge({0, 0, 30, 1}, 35.0, thresholds: {0.3, 0.5})
      assert Enum.all?(cells, fn {_x, _y, _c, fg, _bg, _a} -> fg == :yellow end)
    end
  end

  describe "render_sparkline/3" do
    test "renders sparkline with correct cell format" do
      values = [1.0, 2.0, 3.0, 4.0, 5.0, 4.0, 3.0, 2.0]
      cells = HUD.render_sparkline({0, 0, 20, 1}, values)

      assert length(cells) > 0
      assert Enum.all?(cells, fn cell -> tuple_size(cell) == 6 end)
    end

    test "empty values returns empty" do
      assert HUD.render_sparkline({0, 0, 20, 1}, []) == []
    end

    test "sparkline uses cyan color" do
      cells = HUD.render_sparkline({0, 0, 20, 1}, [1.0, 2.0, 3.0])
      assert Enum.all?(cells, fn {_x, _y, _c, fg, _bg, _a} -> fg == :cyan end)
    end

    test "sparkline with label" do
      cells = HUD.render_sparkline({0, 0, 30, 1}, [1.0, 2.0], label: "CPU")
      chars = Enum.map(cells, fn {_x, _y, c, _fg, _bg, _a} -> c end) |> Enum.join()
      assert String.starts_with?(chars, "CPU")
    end

    test "sparkline uses block characters" do
      values = [0.0, 0.5, 1.0]
      cells = HUD.render_sparkline({0, 0, 20, 1}, values)

      chars = Enum.map(cells, fn {_x, _y, c, _fg, _bg, _a} -> c end)
      # Should contain at least one spark char
      spark_chars = ~w(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
      assert Enum.any?(chars, fn c -> c in spark_chars end)
    end
  end

  describe "render_threat/4" do
    test "renders threat with correct cell format" do
      cells = HUD.render_threat({0, 0, 40, 1}, :high, 45.0)

      assert length(cells) > 0
      assert Enum.all?(cells, fn cell -> tuple_size(cell) == 6 end)
    end

    test "threat none is green" do
      cells = HUD.render_threat({0, 0, 40, 1}, :none, 0.0)
      assert Enum.all?(cells, fn {_x, _y, _c, fg, _bg, _a} -> fg == :green end)
    end

    test "threat high is red" do
      cells = HUD.render_threat({0, 0, 40, 1}, :high, 90.0)
      assert Enum.all?(cells, fn {_x, _y, _c, fg, _bg, _a} -> fg == :red end)
    end

    test "threat medium is yellow" do
      cells = HUD.render_threat({0, 0, 40, 1}, :medium, 180.0)
      assert Enum.all?(cells, fn {_x, _y, _c, fg, _bg, _a} -> fg == :yellow end)
    end

    test "bearing formatted as 3-digit" do
      cells = HUD.render_threat({0, 0, 40, 1}, :high, 5.0)
      chars = Enum.map(cells, fn {_x, _y, c, _fg, _bg, _a} -> c end) |> Enum.join()
      assert String.contains?(chars, "005deg")
    end

    test "clamps to region width" do
      cells = HUD.render_threat({0, 0, 15, 1}, :high, 45.0)
      assert length(cells) <= 15
    end
  end

  describe "render_minimap/3" do
    test "renders minimap with border" do
      entities = [%{x: 0.5, y: 0.5}]
      cells = HUD.render_minimap({0, 0, 10, 8}, entities)

      assert length(cells) > 0
      assert Enum.all?(cells, fn cell -> tuple_size(cell) == 6 end)

      # Should have border chars
      chars = Enum.map(cells, fn {_x, _y, c, _fg, _bg, _a} -> c end)
      assert "┌" in chars
      assert "┘" in chars
    end

    test "minimap without border" do
      entities = [%{x: 0.0, y: 0.0}]
      cells = HUD.render_minimap({0, 0, 5, 5}, entities, border: false)

      chars = Enum.map(cells, fn {_x, _y, c, _fg, _bg, _a} -> c end)
      refute "┌" in chars
    end

    test "empty entities produces blank braille" do
      cells = HUD.render_minimap({0, 0, 5, 5}, [])
      # All braille chars should be empty (U+2800)
      braille_cells =
        Enum.filter(cells, fn {_x, _y, c, fg, _bg, _a} -> fg == :green and c != "" end)

      assert Enum.all?(braille_cells, fn {_x, _y, c, _fg, _bg, _a} ->
               <<cp::utf8>> = c
               cp == 0x2800
             end)
    end

    test "entity within bounds produces non-empty braille" do
      entities = [%{x: 0.5, y: 0.5}]
      cells = HUD.render_minimap({0, 0, 10, 8}, entities)

      braille_cells =
        Enum.filter(cells, fn {_x, _y, _c, fg, _bg, _a} -> fg == :green end)

      # At least one non-empty braille char
      assert Enum.any?(braille_cells, fn {_x, _y, c, _fg, _bg, _a} ->
               <<cp::utf8>> = c
               cp != 0x2800
             end)
    end

    test "cells stay within region bounds" do
      cells = HUD.render_minimap({5, 3, 10, 8}, [%{x: 0.5, y: 0.5}])

      assert Enum.all?(cells, fn {cx, cy, _c, _fg, _bg, _a} ->
               cx >= 5 and cx < 15 and cy >= 3 and cy < 11
             end)
    end
  end
end
