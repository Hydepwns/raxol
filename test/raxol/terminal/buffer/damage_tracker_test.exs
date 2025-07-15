defmodule Raxol.Terminal.Buffer.DamageTrackerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Buffer.DamageTracker

  setup do
    tracker = DamageTracker.new(3)
    %{tracker: tracker}
  end

  test "new/1 initializes with correct max_regions" do
    tracker = DamageTracker.new(5)
    assert tracker.max_regions == 5
    assert tracker.damage_regions == []
  end

  test "add_damage_region/5 adds a region", %{tracker: tracker} do
    tracker = DamageTracker.add_damage_region(tracker, 1, 2, 3, 4)
    assert tracker.damage_regions == [{1, 2, 3, 4}]
  end

  test "add_damage_regions/2 adds multiple regions", %{tracker: tracker} do
    regions = [{1, 2, 3, 4}, {5, 6, 7, 8}]
    tracker = DamageTracker.add_damage_regions(tracker, regions)

    # Check that both regions are present (order may vary due to list prepending)
    assert MapSet.new(Enum.take(tracker.damage_regions, 2)) ==
             MapSet.new(regions)
  end

  test "damage region limit is enforced", %{tracker: tracker} do
    tracker =
      tracker
      |> DamageTracker.add_damage_region(1, 2, 3, 4)
      |> DamageTracker.add_damage_region(2, 3, 4, 5)
      |> DamageTracker.add_damage_region(3, 4, 5, 6)
      |> DamageTracker.add_damage_region(4, 5, 6, 7)

    # Should be truncated to half max_regions (3/2 = 1)
    assert length(tracker.damage_regions) <= 2
  end

  test "get_damage_regions/1 returns all regions", %{tracker: tracker} do
    tracker = DamageTracker.add_damage_region(tracker, 1, 2, 3, 4)
    assert DamageTracker.get_damage_regions(tracker) == [{1, 2, 3, 4}]
  end

  test "clear_damage/1 clears all regions", %{tracker: tracker} do
    tracker = DamageTracker.add_damage_region(tracker, 1, 2, 3, 4)
    tracker = DamageTracker.clear_damage(tracker)
    assert tracker.damage_regions == []
  end

  test "damage_count/1 and has_damage?/1", %{tracker: tracker} do
    refute DamageTracker.has_damage?(tracker)
    tracker = DamageTracker.add_damage_region(tracker, 1, 2, 3, 4)
    assert DamageTracker.has_damage?(tracker)
    assert DamageTracker.damage_count(tracker) == 1
  end

  test "merge_regions/1 dedups regions", %{tracker: tracker} do
    tracker =
      tracker
      |> DamageTracker.add_damage_region(1, 2, 3, 4)
      |> DamageTracker.add_damage_region(1, 2, 3, 4)

    tracker = DamageTracker.merge_regions(tracker)
    assert tracker.damage_regions == [{1, 2, 3, 4}]
  end

  test "get_stats/1 returns correct stats", %{tracker: tracker} do
    tracker = DamageTracker.add_damage_region(tracker, 1, 2, 3, 4)
    stats = DamageTracker.get_stats(tracker)
    assert stats.damage_count == 1
    assert stats.max_regions == 3
    assert stats.has_damage == true
    assert stats.regions == [{1, 2, 3, 4}]
  end
end
