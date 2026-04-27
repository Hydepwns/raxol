defmodule Raxol.Effects.BorderBeam.Effects.StrokeTest do
  use ExUnit.Case, async: true

  alias Raxol.Effects.BorderBeam.Effects.Stroke
  Code.require_file("test_helper.exs", __DIR__)
  alias Raxol.Effects.BorderBeam.Effects.TestHelper, as: H

  @bounds %{x: 0, y: 0, width: 10, height: 6}

  test "lights some perimeter cells but never an interior cell" do
    cells = H.make_box_cells(@bounds)
    out = Stroke.apply(cells, @bounds, %{variant: :ocean, strength: 0.9, duration_ms: 1500}, 0)

    interior = for x <- 1..8, y <- 1..4, do: {x, y}
    Enum.each(interior, fn key ->
      assert is_nil(elem(Map.get(out, key, {nil, nil, nil, nil, nil, []}), 3)),
        "interior cell #{inspect(key)} got an fg color"
    end)

    assert map_size(H.lit_cells(out)) > 0
  end

  test "is deterministic for a given now_ms" do
    cells = H.make_box_cells(@bounds)
    out1 = Stroke.apply(cells, @bounds, %{variant: :ocean, duration_ms: 1500}, 1234)
    out2 = Stroke.apply(cells, @bounds, %{variant: :ocean, duration_ms: 1500}, 1234)
    assert out1 == out2
  end

  test "head color matches first palette color" do
    cells = H.make_box_cells(@bounds)
    out = Stroke.apply(cells, @bounds, %{variant: :ocean, duration_ms: 1500, strength: 1.0}, 0)

    head_color =
      out
      |> Map.values()
      |> Enum.map(fn {_, _, _, fg, _, attrs} -> {fg, attrs} end)
      |> Enum.find(fn {_fg, attrs} -> :bold in attrs end)

    assert {:bright_cyan, _attrs} = head_color
  end

  test "size :line produces a much shorter trail than :full" do
    cells = H.make_box_cells(@bounds)
    full = Stroke.apply(cells, @bounds, %{size: :full, duration_ms: 1500}, 0)
    line = Stroke.apply(cells, @bounds, %{size: :line, duration_ms: 1500}, 0)

    assert map_size(H.lit_cells(full)) > map_size(H.lit_cells(line))
  end

  test "negative monotonic time produces a valid result (no crash)" do
    # System.monotonic_time can be negative; rem(neg, pos) returns neg in
    # Elixir, which would cause elem/2 on a tuple to crash. Integer.mod
    # wraps non-negatively. Regression test for the silent-frame-skip
    # glitch on apps started early in BEAM lifetime.
    cells = H.make_box_cells(@bounds)
    out = Stroke.apply(cells, @bounds, %{variant: :ocean, duration_ms: 1500}, -1234)
    assert map_size(H.lit_cells(out)) > 0
  end
end
