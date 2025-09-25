defmodule Raxol.Terminal.Buffer.DamageTracker do
  @moduledoc """
  Tracks damage regions in a terminal buffer for efficient rendering.
  Damage regions indicate areas that have changed and need to be redrawn.
  """

  @type region ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(),
           non_neg_integer()}
  @type t :: %__MODULE__{
          regions: [region()],
          max_regions: non_neg_integer()
        }

  defstruct regions: [],
            max_regions: 100

  @doc """
  Creates a new damage tracker with a maximum region limit.
  """
  @spec new(non_neg_integer()) :: t()
  def new(max_regions \\ 100) do
    %__MODULE__{
      regions: [],
      max_regions: max_regions
    }
  end

  @doc """
  Adds a damage region to the tracker.
  """
  @spec add_damage_region(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: t()
  def add_damage_region(tracker, x, y, width, height) do
    new_region = {x, y, width, height}

    # Add region and enforce limit
    regions = [new_region | tracker.regions]

    regions =
      if length(regions) > tracker.max_regions do
        Enum.take(regions, tracker.max_regions)
      else
        regions
      end

    %{tracker | regions: regions}
  end

  @doc """
  Adds multiple damage regions at once.
  """
  @spec add_damage_regions(t(), [region()]) :: t()
  def add_damage_regions(tracker, new_regions) do
    Enum.reduce(new_regions, tracker, fn {x, y, width, height}, acc ->
      add_damage_region(acc, x, y, width, height)
    end)
  end

  @doc """
  Gets all damage regions.
  """
  @spec get_damage_regions(t()) :: [region()]
  def get_damage_regions(tracker) do
    tracker.regions
  end

  @doc """
  Clears all damage regions.
  """
  @spec clear_damage(t()) :: t()
  def clear_damage(tracker) do
    %{tracker | regions: []}
  end

  @doc """
  Returns the count of damage regions.
  """
  @spec damage_count(t()) :: non_neg_integer()
  def damage_count(tracker) do
    length(tracker.regions)
  end

  @doc """
  Checks if there are any damage regions.
  """
  @spec has_damage?(t()) :: boolean()
  def has_damage?(tracker) do
    tracker.regions != []
  end

  @doc """
  Merges overlapping or adjacent regions to reduce redundancy.
  """
  @spec merge_regions(t()) :: t()
  def merge_regions(tracker) do
    merged_regions =
      tracker.regions
      |> Enum.sort()
      |> merge_sorted_regions()

    %{tracker | regions: merged_regions}
  end

  # Private functions

  defp merge_sorted_regions([]), do: []
  defp merge_sorted_regions([region]), do: [region]

  defp merge_sorted_regions([r1, r2 | rest]) do
    if regions_overlap?(r1, r2) or regions_adjacent?(r1, r2) do
      merged = merge_two_regions(r1, r2)
      merge_sorted_regions([merged | rest])
    else
      [r1 | merge_sorted_regions([r2 | rest])]
    end
  end

  defp regions_overlap?({x1, y1, w1, h1}, {x2, y2, w2, h2}) do
    not (x1 + w1 <= x2 or x2 + w2 <= x1 or y1 + h1 <= y2 or y2 + h2 <= y1)
  end

  defp regions_adjacent?({x1, y1, w1, h1}, {x2, y2, w2, h2}) do
    # Check if regions share an edge
    # Right edge
    # Left edge
    # Bottom edge
    # Top edge
    (x1 + w1 == x2 and y1 == y2 and h1 == h2) or
      (x2 + w2 == x1 and y1 == y2 and h1 == h2) or
      (y1 + h1 == y2 and x1 == x2 and w1 == w2) or
      (y2 + h2 == y1 and x1 == x2 and w1 == w2)
  end

  defp merge_two_regions({x1, y1, w1, h1}, {x2, y2, w2, h2}) do
    min_x = min(x1, x2)
    min_y = min(y1, y2)
    max_x = max(x1 + w1, x2 + w2)
    max_y = max(y1 + h1, y2 + h2)

    {min_x, min_y, max_x - min_x, max_y - min_y}
  end
end
