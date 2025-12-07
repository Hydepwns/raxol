defmodule Raxol.Terminal.CellCached do
  @moduledoc """
  Cached version of Cell operations for performance optimization.

  This module provides cached versions of common Cell operations
  to improve performance by avoiding redundant computations.
  """

  alias Raxol.Terminal.Cell

  @doc """
  Creates a new cell with caching.
  """
  def new(char, style \\ nil) do
    # NOTE: Direct cell creation without caching. Future enhancement will add
    # cell pooling and reuse to reduce allocation overhead.
    Cell.new(char, style)
  end

  @doc """
  Creates multiple cells in batch.
  """
  def batch_new(pairs) do
    Enum.map(pairs, fn {char, style} ->
      new(char, style)
    end)
  end

  @doc """
  Merges styles with caching.
  """
  def merge_styles(parent, child) when is_map(parent) and is_map(child) do
    Map.merge(parent, child)
  end

  def merge_styles(_parent, child), do: child

  @doc """
  Warms up the cache with common values.
  """
  def warm_cache do
    # Stub for now
    :ok
  end
end
