defmodule Raxol.Effects.BorderBeam.Effects.CloudsTest do
  use ExUnit.Case, async: true

  alias Raxol.Effects.BorderBeam.Effects.Clouds
  Code.require_file("test_helper.exs", __DIR__)
  alias Raxol.Effects.BorderBeam.Effects.TestHelper, as: H

  @bounds %{x: 0, y: 0, width: 12, height: 8}

  test "never replaces border characters" do
    cells = H.make_box_cells(@bounds)
    out = Clouds.apply(cells, @bounds, %{variant: :ocean}, 0)
    assert H.replaced_chars(out) == 0
  end

  test "is deterministic for a given now_ms" do
    cells = H.make_box_cells(@bounds)
    out1 = Clouds.apply(cells, @bounds, %{variant: :ocean, duration_ms: 6000}, 1500)
    out2 = Clouds.apply(cells, @bounds, %{variant: :ocean, duration_ms: 6000}, 1500)
    assert out1 == out2
  end

  test "lights every perimeter cell" do
    cells = H.make_box_cells(@bounds)
    out = Clouds.apply(cells, @bounds, %{variant: :ocean}, 0)
    lit = H.lit_cells(out)

    perim_count =
      2 * @bounds.width + 2 * (@bounds.height - 2)

    assert map_size(lit) == perim_count
  end
end
