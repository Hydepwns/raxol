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
  def add_damage_region(tracker, x, y, width, height) do
    # Store in {x, y, width, height} format as expected by tests
    region = {x, y, width, height}
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
    Enum.reduce(regions, tracker, fn {x, y, width, height}, acc ->
      add_damage_region(acc, x, y, width, height)
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
         [{x1, y1, w1, h1} | rest],
         [{x2, y2, w2, h2} | merged_tail] = merged
       ) do
    # Check if regions overlap or are adjacent
    if regions_overlap_or_adjacent({x1, y1, w1, h1}, {x2, y2, w2, h2}) do
      # Merge the regions
      merged_region = merge_two_regions({x1, y1, w1, h1}, {x2, y2, w2, h2})
      merge_adjacent_regions(rest, [merged_region | merged_tail])
    else
      merge_adjacent_regions(rest, [{x1, y1, w1, h1} | merged])
    end
  end

  defp regions_overlap_or_adjacent({x1, y1, w1, h1}, {x2, y2, w2, h2}) do
    # Check if regions overlap or are adjacent (using width/height format)
    end_x1 = x1 + w1 - 1
    end_y1 = y1 + h1 - 1
    end_x2 = x2 + w2 - 1
    end_y2 = y2 + h2 - 1

    x_overlap = x1 <= end_x2 + 1 and x2 <= end_x1 + 1
    y_overlap = y1 <= end_y2 + 1 and y2 <= end_y1 + 1

    x_overlap and y_overlap
  end

  defp merge_two_regions({x1, y1, w1, h1}, {x2, y2, w2, h2}) do
    # Find the bounding box that contains both regions
    end_x1 = x1 + w1 - 1
    end_y1 = y1 + h1 - 1
    end_x2 = x2 + w2 - 1
    end_y2 = y2 + h2 - 1

    x_min = min(x1, x2)
    y_min = min(y1, y2)
    x_max = max(end_x1, end_x2)
    y_max = max(end_y1, end_y2)

    # Return in {x, y, width, height} format
    {x_min, y_min, x_max - x_min + 1, y_max - y_min + 1}
  end
end
