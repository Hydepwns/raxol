defmodule Raxol.Terminal.Buffer.DamageTracker do
  @moduledoc """
  Manages damage tracking for terminal buffers.

  Handles marking regions as damaged and merging overlapping regions
  for efficient redrawing.
  """

  @type region :: {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
  @type t :: %__MODULE__{
          regions: list(region())
        }

  defstruct regions: []

  @doc """
  Creates a new, empty damage tracker.
  """
  @spec new() :: t()
  def new(), do: %__MODULE__{regions: []}

  @doc """
  Marks a rectangular region as damaged.

  Merges the new region with any existing overlapping regions.
  """
  @spec mark_damaged(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
  def mark_damaged(%__MODULE__{} = tracker, x1, y1, x2, y2) do
    new_region = {x1, y1, x2, y2}
    merged_regions = merge_damage_regions([new_region | tracker.regions])
    %__MODULE__{tracker | regions: merged_regions}
  end

  @doc """
  Gets the list of distinct damaged regions.
  """
  @spec get_regions(t()) :: list(region())
  def get_regions(%__MODULE__{} = tracker) do
    tracker.regions
  end

  @doc """
  Clears all tracked damage regions.
  """
  @spec clear_regions(t()) :: t()
  def clear_regions(%__MODULE__{} = tracker) do
    %__MODULE__{tracker | regions: []}
  end

  # --- Private Helpers ---

  # Merges newly added regions by iterating through the list and combining overlaps.
  defp merge_damage_regions(regions) do
    # Simple iterative merging: compare each region with subsequent ones.
    # This is O(n^2) but likely fine for typical numbers of damage regions.
    # A more optimized approach (e.g., interval tree) could be used if needed.
    Enum.reduce(regions, [], fn region, acc ->
      merge_or_append(region, acc)
    end)
    |> Enum.reverse() # Reduce builds the list in reverse
  end

  # Helper to merge a region into a list of existing non-overlapping regions
  defp merge_or_append(new_region, existing_regions) do
    {overlapping, non_overlapping} = Enum.split_with(existing_regions, &regions_overlap?(new_region, &1))

    case overlapping do
      [] ->
        # No overlap, just add the new region
        [new_region | non_overlapping]
      _ ->
        # Merge the new region with all overlapping regions found
        merged = Enum.reduce(overlapping, new_region, &merge_two_regions/2)
        [merged | non_overlapping]
    end

  end


  defp regions_overlap?({x1, y1, x2, y2}, {rx1, ry1, rx2, ry2}) do
    # Check for overlap: !(left || right || above || below)
    not (x2 < rx1 or x1 > rx2 or y2 < ry1 or y1 > ry2)
  end

  defp merge_two_regions({x1, y1, x2, y2}, {rx1, ry1, rx2, ry2}) do
    {
      min(x1, rx1),
      min(y1, ry1),
      max(x2, rx2),
      max(y2, ry2)
    }
  end

end
