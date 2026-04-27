defmodule Raxol.Effects.BorderBeam.Effects.ElectricTest do
  use ExUnit.Case, async: true

  alias Raxol.Effects.BorderBeam.Effects.Electric
  Code.require_file("test_helper.exs", __DIR__)
  alias Raxol.Effects.BorderBeam.Effects.TestHelper, as: H

  @bounds %{x: 0, y: 0, width: 12, height: 8}

  test "is deterministic within a time bucket" do
    cells = H.make_box_cells(@bounds)
    opts = %{variant: :electric, frequency: 25, bucket_ms: 100}
    a = Electric.apply(cells, @bounds, opts, 50)
    b = Electric.apply(cells, @bounds, opts, 90)
    assert a == b
  end

  test "produces different output across buckets" do
    cells = H.make_box_cells(@bounds)
    opts = %{variant: :electric, frequency: 50, bucket_ms: 50}
    a = Electric.apply(cells, @bounds, opts, 100)
    b = Electric.apply(cells, @bounds, opts, 200)
    refute a == b
  end

  test "lights only perimeter cells" do
    cells = H.make_box_cells(@bounds)
    out = Electric.apply(cells, @bounds, %{variant: :electric, frequency: 30}, 0)
    lit = H.lit_cells(out)

    interior = for x <- 1..(@bounds.width - 2), y <- 1..(@bounds.height - 2), do: {x, y}
    Enum.each(interior, fn key ->
      refute Map.has_key?(lit, key)
    end)
  end
end
