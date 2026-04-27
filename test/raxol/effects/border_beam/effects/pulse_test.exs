defmodule Raxol.Effects.BorderBeam.Effects.PulseTest do
  use ExUnit.Case, async: true

  alias Raxol.Effects.BorderBeam.Effects.Pulse
  Code.require_file("test_helper.exs", __DIR__)
  alias Raxol.Effects.BorderBeam.Effects.TestHelper, as: H

  @bounds %{x: 0, y: 0, width: 10, height: 6}

  test "all perimeter cells share the same fg color in a single frame" do
    cells = H.make_box_cells(@bounds)
    out = Pulse.apply(cells, @bounds, %{variant: :ocean, period_ms: 1000}, 250)

    fgs =
      out
      |> Map.values()
      |> Enum.map(fn {_, _, _, fg, _, _} -> fg end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    assert length(fgs) == 1
  end

  test "peak frame uses the brightest palette color (palette[0])" do
    cells = H.make_box_cells(@bounds)
    period = 1000
    peak = Pulse.apply(cells, @bounds, %{variant: :ocean, period_ms: period, strength: 1.0}, div(period, 2))
    {_, _, _, fg, _, _} = peak |> Map.values() |> hd()
    assert fg == :bright_cyan
  end

  test "trough frame uses a different palette color than peak" do
    cells = H.make_box_cells(@bounds)
    period = 1000
    peak = Pulse.apply(cells, @bounds, %{variant: :ocean, period_ms: period, strength: 1.0}, div(period, 2))
    trough = Pulse.apply(cells, @bounds, %{variant: :ocean, period_ms: period, strength: 1.0}, 0)

    {_, _, _, peak_fg, _, _} = peak |> Map.values() |> hd()
    {_, _, _, trough_fg, _, _} = trough |> Map.values() |> hd()
    refute peak_fg == trough_fg
  end

  test "interior cells are untouched" do
    cells = H.make_box_cells(@bounds)
    out = Pulse.apply(cells, @bounds, %{variant: :ocean, period_ms: 1000}, 250)

    interior = for x <- 1..8, y <- 1..4, do: {x, y}
    Enum.each(interior, fn key -> refute Map.has_key?(out, key) end)
  end

  test "peak frame is bold, trough frame is dim" do
    cells = H.make_box_cells(@bounds)
    period = 1000
    peak = Pulse.apply(cells, @bounds, %{variant: :ocean, period_ms: period, strength: 1.0}, div(period, 2))
    trough = Pulse.apply(cells, @bounds, %{variant: :ocean, period_ms: period, strength: 1.0}, 0)

    {_, _, _, _, _, peak_attrs} = peak |> Map.values() |> hd()
    {_, _, _, _, _, trough_attrs} = trough |> Map.values() |> hd()

    assert :bold in peak_attrs
    assert :dim in trough_attrs
  end

  test "negative monotonic time produces a valid result (no crash)" do
    cells = H.make_box_cells(@bounds)
    out = Pulse.apply(cells, @bounds, %{variant: :ocean, period_ms: 1000}, -1234)
    assert is_map(out)
    assert map_size(out) > 0
  end
end
