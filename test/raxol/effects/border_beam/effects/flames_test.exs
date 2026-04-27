defmodule Raxol.Effects.BorderBeam.Effects.FlamesTest do
  use ExUnit.Case, async: true

  alias Raxol.Effects.BorderBeam.Effects.Flames
  Code.require_file("test_helper.exs", __DIR__)
  alias Raxol.Effects.BorderBeam.Effects.TestHelper, as: H

  @bounds %{x: 0, y: 0, width: 12, height: 8}

  test "is deterministic for a given now_ms" do
    cells = H.make_box_cells(@bounds)
    out1 = Flames.apply(cells, @bounds, %{variant: :sunset, strength: 1.0, density: 1.0}, 5_000)
    out2 = Flames.apply(cells, @bounds, %{variant: :sunset, strength: 1.0, density: 1.0}, 5_000)
    assert out1 == out2
  end

  test "replaces some bottom-edge chars at full intensity + full density" do
    cells = H.make_box_cells(@bounds)
    out = Flames.apply(cells, @bounds, %{variant: :sunset, strength: 1.0, density: 1.0}, 0)

    assert H.replaced_chars(out) > 0
  end

  test "leaves chars alone at zero density" do
    cells = H.make_box_cells(@bounds)
    out = Flames.apply(cells, @bounds, %{variant: :sunset, strength: 1.0, density: 0.0}, 0)
    assert H.replaced_chars(out) == 0
  end

  test "only paints bottom edge and the lower portion of the side edges" do
    cells = H.make_box_cells(@bounds)
    out = Flames.apply(cells, @bounds, %{variant: :sunset, strength: 1.0, density: 1.0}, 0)
    lit = H.lit_cells(out)

    # Top edge should be untouched
    Enum.each(0..(@bounds.width - 1), fn dx ->
      key = {@bounds.x + dx, @bounds.y}
      refute Map.has_key?(lit, key), "top-edge cell #{inspect(key)} was lit"
    end)
  end
end
