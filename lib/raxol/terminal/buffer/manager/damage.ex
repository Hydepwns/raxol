defmodule Raxol.Terminal.Buffer.Manager.Damage do
  @moduledoc """
  Handles damage tracking for the terminal buffer.
  Provides functionality for tracking and managing damaged regions.
  """

  alias Raxol.Terminal.Buffer.Manager.State
  alias Raxol.Terminal.Buffer.DamageTracker

  @doc """
  Marks a region of the buffer as damaged.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Damage.mark_region(state, 0, 0, 10, 5)
      iex> length(Damage.get_regions(state))
      1
  """
  def mark_region(%State{} = state, x1, y1, x2, y2) do
    new_tracker =
      DamageTracker.mark_damaged(state.damage_tracker, x1, y1, x2, y2)

    %{state | damage_tracker: new_tracker}
  end

  @doc """
  Gets all damaged regions.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Damage.mark_region(state, 0, 0, 10, 5)
      iex> regions = Damage.get_regions(state)
      iex> length(regions)
      1
  """
  def get_regions(%State{} = state) do
    DamageTracker.get_regions(state.damage_tracker)
  end

  @doc """
  Clears all damage regions.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Damage.mark_region(state, 0, 0, 10, 5)
      iex> state = Damage.clear_regions(state)
      iex> length(Damage.get_regions(state))
      0
  """
  def clear_regions(%State{} = state) do
    new_tracker = DamageTracker.clear_regions(state.damage_tracker)
    %{state | damage_tracker: new_tracker}
  end

  @doc """
  Marks the entire visible region as damaged.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Damage.mark_all(state)
      iex> length(Damage.get_regions(state))
      1
  """
  def mark_all(%State{} = state) do
    {width, height} = State.get_dimensions(state)
    mark_region(state, 0, 0, width - 1, height - 1)
  end

  @doc """
  Marks a line as damaged.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Damage.mark_line(state, 5)
      iex> length(Damage.get_regions(state))
      1
  """
  def mark_line(%State{} = state, y) do
    {width, _} = State.get_dimensions(state)
    mark_region(state, 0, y, width - 1, y)
  end

  @doc """
  Marks a column as damaged.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = Damage.mark_column(state, 10)
      iex> length(Damage.get_regions(state))
      1
  """
  def mark_column(%State{} = state, x) do
    {_, height} = State.get_dimensions(state)
    mark_region(state, x, 0, x, height - 1)
  end

  #  @doc """
  #  Merges overlapping damage regions.
  #
  #  ## Examples
  #
  #      iex> state = State.new(80, 24)
  #      iex> state = Damage.mark_region(state, 0, 0, 10, 5)
  #      iex> state = Damage.mark_region(state, 5, 0, 15, 5)
  #      iex> state = Damage.merge_regions(state)
  #      iex> length(Damage.get_regions(state))
  #      1
  #  """
  #  def merge_regions(%State{} = state) do
  #    # Get all damage regions
  #    regions = DamageTracker.get_regions(state.damage_tracker)
  #
  #    # Sort regions by start position
  #    sorted_regions = Enum.sort_by(regions, fn {start, _end} -> start end)
  #
  #    # Merge overlapping regions
  #    merged_regions =
  #      Enum.reduce(sorted_regions, [], fn
  #        region, [] ->
  #          [region]
  #
  #        {start2, end2}, [{start1, end1} | rest] ->
  #          if start2 <= end1 + 1 do
  #            [{start1, max(end1, end2)} | rest]
  #          else
  #            [{start2, end2}, {start1, end1} | rest]
  #          end
  #      end)
  #
  #    # Create new tracker with merged regions
  #    new_tracker = DamageTracker.clear_regions(state.damage_tracker)
  #    Enum.reduce(merged_regions, new_tracker, fn {start, end_pos}, acc ->
  #      DamageTracker.add_region(acc, start, end_pos)
  #    end)
  #  end
end
