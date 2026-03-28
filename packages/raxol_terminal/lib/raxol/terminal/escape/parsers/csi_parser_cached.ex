defmodule Raxol.Terminal.Escape.Parsers.CSIParserCached do
  @moduledoc """
  Cached version of CSI parser for performance optimization.

  This module provides cached parsing of CSI sequences to avoid
  redundant parsing operations.
  """

  alias Raxol.Terminal.Escape.Parsers.CSIParser

  @doc """
  Parses a CSI sequence with caching.
  """
  def parse(sequence) do
    # NOTE: Direct parsing without caching. Future enhancement will add
    # memoization for frequently-used CSI sequences to improve performance.
    CSIParser.parse(sequence)
  end

  @doc """
  Warms up the cache with common sequences.
  """
  def warm_cache do
    # Stub for now
    :ok
  end
end
