defmodule Raxol.Terminal.Buffer.DamageTracker do
  @moduledoc """
  Tracks damaged regions in the buffer for efficient rendering.

  This module is responsible for:
  - Tracking which regions of the buffer have changed
  - Managing damage region limits to prevent memory bloat
  - Providing damage information for rendering optimization
  - Cleaning up old damage regions
  """

  @type damage_region ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(),
           non_neg_integer()}
  @type damage_tracker :: %{
          damage_regions: [damage_region()],
          max_regions: non_neg_integer()
        }
  @type t :: damage_tracker()

  @doc """
  Creates a new damage tracker.
  """
  @spec new(non_neg_integer()) :: damage_tracker()
  def new(max_regions \\ 100) do
    %{
      damage_regions: [],
      max_regions: max_regions
    }
  end

  @doc """
  Adds a damage region to the tracker.
  """
  @spec add_damage_region(
          damage_tracker(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: damage_tracker()
  def add_damage_region(tracker, x1, y1, x2, y2) do
    # Store in {x1, y1, x2, y2} format as expected by tests
    region = {x1, y1, x2, y2}
    damage_regions = [region | tracker.damage_regions]

    # Limit damage regions to prevent memory bloat
    limited_regions =
      if length(damage_regions) > tracker.max_regions do
        Enum.take(damage_regions, div(tracker.max_regions, 2))
      else
        damage_regions
      end

    # Merge overlapping regions for efficiency
    merged_tracker = %{tracker | damage_regions: limited_regions}
    merge_regions(merged_tracker)
  end

  @doc """
  Adds multiple damage regions at once.
  """
  @spec add_damage_regions(damage_tracker(), [damage_region()]) ::
          damage_tracker()
  def add_damage_regions(tracker, regions) do
    Enum.reduce(regions, tracker, fn {x1, y1, x2, y2}, acc ->
      add_damage_region(acc, x1, y1, x2, y2)
    end)
  end

  @doc """
  Gets all damage regions.
  """
  @spec get_damage_regions(damage_tracker()) :: [damage_region()]
  def get_damage_regions(tracker) do
    tracker.damage_regions
  end

  @doc """
  Clears all damage regions.
  """
  @spec clear_damage(damage_tracker()) :: damage_tracker()
  def clear_damage(tracker) do
    %{tracker | damage_regions: []}
  end

  @doc """
  Gets the number of damage regions.
  """
  @spec damage_count(damage_tracker()) :: non_neg_integer()
  def damage_count(tracker) do
    length(tracker.damage_regions)
  end

  @doc """
  Checks if there are any damage regions.
  """
  @spec has_damage?(damage_tracker()) :: boolean()
  def has_damage?(tracker) do
    tracker.damage_regions != []
  end

  @doc """
  Merges overlapping damage regions for efficiency.
  """
  @spec merge_regions(damage_tracker()) :: damage_tracker()
  def merge_regions(tracker) do
    merged_regions = merge_overlapping_regions(tracker.damage_regions)
    %{tracker | damage_regions: merged_regions}
  end

  @doc """
  Gets damage statistics.
  """
  @spec get_stats(damage_tracker()) :: map()
  def get_stats(tracker) do
    %{
      damage_count: damage_count(tracker),
      max_regions: tracker.max_regions,
      has_damage: has_damage?(tracker),
      regions: tracker.damage_regions
    }
  end

  @doc """
  Cleans up the damage tracker, clearing all damage regions.
  """
  @spec cleanup(damage_tracker()) :: damage_tracker()
  def cleanup(tracker) do
    clear_damage(tracker)
  end

  # Private helper functions

  defp merge_overlapping_regions(regions) do
    regions
    |> Enum.sort()
    |> merge_adjacent_regions([])
  end

  defp merge_adjacent_regions([], merged), do: Enum.reverse(merged)

  defp merge_adjacent_regions([region | rest], []),
    do: merge_adjacent_regions(rest, [region])

  defp merge_adjacent_regions(
         [{x1, y1, x2, y2} | rest],
         [{x3, y3, x4, y4} | merged_tail] = merged
       ) do
    # Check if regions overlap or are adjacent
    if regions_overlap_or_adjacent({x1, y1, x2, y2}, {x3, y3, x4, y4}) do
      # Merge the regions
      merged_region = merge_two_regions({x1, y1, x2, y2}, {x3, y3, x4, y4})
      merge_adjacent_regions(rest, [merged_region | merged_tail])
    else
      merge_adjacent_regions(rest, [{x1, y1, x2, y2} | merged])
    end
  end

  defp regions_overlap_or_adjacent({x1, y1, x2, y2}, {x3, y3, x4, y4}) do
    # Check if regions overlap or are adjacent (using x1,y1,x2,y2 format)
    x_overlap = x1 <= x4 + 1 and x3 <= x2 + 1
    y_overlap = y1 <= y4 + 1 and y3 <= y2 + 1

    x_overlap and y_overlap
  end

  defp merge_two_regions({x1, y1, x2, y2}, {x3, y3, x4, y4}) do
    # Find the bounding box that contains both regions
    x_min = min(x1, x3)
    y_min = min(y1, y3)
    x_max = max(x2, x4)
    y_max = max(y2, y4)

    # Return in {x1, y1, x2, y2} format
    {x_min, y_min, x_max, y_max}
  end
end
