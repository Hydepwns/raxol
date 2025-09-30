defmodule Raxol.Performance.ETSCacheManager do
  @moduledoc """
  High-performance ETS cache manager for Raxol hot paths.

  Provides dedicated caches for performance-critical operations:
  - ANSI parser cache
  - Cell creation cache
  - Theme/style resolution cache
  - Buffer operations cache
  - Layout calculation cache

  Uses ETS tables with optimized access patterns and LRU eviction.
  """

  use Raxol.Core.Behaviours.BaseManager

  require Raxol.Core.Runtime.Log

  @csi_parser_cache :raxol_csi_parser_cache
  @cell_cache :raxol_cell_cache
  @style_cache :raxol_style_cache
  @buffer_cache :raxol_buffer_cache
  @layout_cache :raxol_layout_cache
  @font_metrics_cache :raxol_font_metrics_cache

  @max_csi_entries 1000
  @max_cell_entries 10000
  @max_style_entries 5000
  @max_buffer_entries 2000
  @max_layout_entries 1000
  @max_font_metrics_entries 10000

  # Client API

  @doc """
  Cache a parsed CSI sequence.
  """
  def cache_csi(sequence, result) do
    _ =
      :ets.insert(
        @csi_parser_cache,
        {sequence, result, System.monotonic_time()}
      )

    _ = enforce_cache_limit(@csi_parser_cache, @max_csi_entries)
    result
  end

  @doc """
  Get a cached CSI parse result.
  """
  def get_csi(sequence) do
    case :ets.lookup(@csi_parser_cache, sequence) do
      [{^sequence, result, _timestamp}] ->
        # Update timestamp on access for LRU
        _ =
          :ets.update_element(
            @csi_parser_cache,
            sequence,
            {3, System.monotonic_time()}
          )

        {:ok, result}

      [] ->
        :miss
    end
  end

  @doc """
  Cache a cell creation.
  """
  def cache_cell(char, style_hash, cell) do
    key = {char, style_hash}
    _ = :ets.insert(@cell_cache, {key, cell, System.monotonic_time()})
    _ = enforce_cache_limit(@cell_cache, @max_cell_entries)
    cell
  end

  @doc """
  Get a cached cell.
  """
  def get_cell(char, style_hash) do
    key = {char, style_hash}

    case :ets.lookup(@cell_cache, key) do
      [{^key, cell, _timestamp}] ->
        _ = :ets.update_element(@cell_cache, key, {3, System.monotonic_time()})
        {:ok, cell}

      [] ->
        :miss
    end
  end

  @doc """
  Cache a style resolution.
  """
  def cache_style(theme_id, component_type, attrs_hash, resolved_style) do
    key = {theme_id, component_type, attrs_hash}

    _ =
      :ets.insert(@style_cache, {key, resolved_style, System.monotonic_time()})

    _ = enforce_cache_limit(@style_cache, @max_style_entries)
    resolved_style
  end

  @doc """
  Get a cached style resolution.
  """
  def get_style(theme_id, component_type, attrs_hash) do
    key = {theme_id, component_type, attrs_hash}

    case :ets.lookup(@style_cache, key) do
      [{^key, style, _timestamp}] ->
        _ = :ets.update_element(@style_cache, key, {3, System.monotonic_time()})
        {:ok, style}

      [] ->
        :miss
    end
  end

  @doc """
  Cache a buffer region.
  """
  def cache_buffer_region(buffer_id, x, y, width, height, data) do
    key = {:region, buffer_id, x, y, width, height}
    _ = :ets.insert(@buffer_cache, {key, data, System.monotonic_time()})
    _ = enforce_cache_limit(@buffer_cache, @max_buffer_entries)
    data
  end

  @doc """
  Get a cached buffer region.
  """
  def get_buffer_region(buffer_id, x, y, width, height) do
    key = {:region, buffer_id, x, y, width, height}

    case :ets.lookup(@buffer_cache, key) do
      [{^key, data, _timestamp}] ->
        _ =
          :ets.update_element(@buffer_cache, key, {3, System.monotonic_time()})

        {:ok, data}

      [] ->
        :miss
    end
  end

  @doc """
  Cache a layout calculation.
  Supports both full tree layouts and partial node layouts.
  """
  def cache_layout(tree_hash, constraints, result) do
    key = {tree_hash, constraints}
    _ = :ets.insert(@layout_cache, {key, result, System.monotonic_time()})
    _ = enforce_cache_limit(@layout_cache, @max_layout_entries)
    result
  end

  @doc """
  Get a cached layout.
  Supports constraint matching for responsive layouts.
  """
  def get_layout(tree_hash, constraints) do
    key = {tree_hash, constraints}

    case :ets.lookup(@layout_cache, key) do
      [{^key, result, _timestamp}] ->
        _ =
          :ets.update_element(@layout_cache, key, {3, System.monotonic_time()})

        {:ok, result}

      [] ->
        # Try to find a compatible cached layout
        find_compatible_layout(tree_hash, constraints)
    end
  end

  @doc """
  Batch cache multiple layouts.
  Useful for pre-computing common viewport sizes.
  """
  def cache_layouts_batch(layouts) do
    _ =
      Enum.each(layouts, fn {tree_hash, constraints, result} ->
        cache_layout(tree_hash, constraints, result)
      end)
  end

  defp find_compatible_layout(tree_hash, constraints) do
    # Look for layouts with same tree but similar constraints
    pattern = {{tree_hash, :_}, :_, :_}
    candidates = :ets.match_object(@layout_cache, pattern)

    case find_best_match(candidates, constraints) do
      {key, result, _timestamp} ->
        # Update timestamp for LRU
        _ =
          :ets.update_element(@layout_cache, key, {3, System.monotonic_time()})

        {:ok, result}

      nil ->
        :miss
    end
  end

  @doc """
  Cache font metrics calculation.
  """
  def cache_font_metrics(key, result) do
    _ = :ets.insert(@font_metrics_cache, {key, result, System.monotonic_time()})
    _ = enforce_cache_limit(@font_metrics_cache, @max_font_metrics_entries)
    result
  end

  @doc """
  Get cached font metrics.
  """
  def get_font_metrics(key) do
    case :ets.lookup(@font_metrics_cache, key) do
      [{^key, result, _timestamp}] ->
        _ =
          :ets.update_element(
            @font_metrics_cache,
            key,
            {3, System.monotonic_time()}
          )

        {:ok, result}

      [] ->
        :miss
    end
  end

  defp find_best_match([], _), do: nil

  defp find_best_match(candidates, target_constraints) do
    # Find layout with closest matching constraints
    Enum.find(candidates, fn {{_tree_hash, cached_constraints}, _result, _ts} ->
      constraints_compatible?(cached_constraints, target_constraints)
    end)
  end

  defp constraints_compatible?(cached, target)
       when is_list(cached) and is_list(target) do
    # Simple compatibility check - can be made more sophisticated
    cached_map = Map.new(cached)
    target_map = Map.new(target)

    # Check if dimensions are within 10% tolerance
    width_compatible?(cached_map[:width], target_map[:width]) and
      height_compatible?(cached_map[:height], target_map[:height])
  end

  defp constraints_compatible?(_, _), do: false

  defp width_compatible?(nil, _), do: true
  defp width_compatible?(_, nil), do: true

  defp width_compatible?(w1, w2) do
    max_val = Enum.max([w1, w2])
    abs(w1 - w2) / max_val <= 0.1
  end

  defp height_compatible?(nil, _), do: true
  defp height_compatible?(_, nil), do: true

  defp height_compatible?(h1, h2) do
    max_val = Enum.max([h1, h2])
    abs(h1 - h2) / max_val <= 0.1
  end

  @doc """
  Clear all caches.
  """
  def clear_all do
    GenServer.call(__MODULE__, :clear_all)
  end

  @doc """
  Clear a specific cache.
  """
  def clear_cache(cache_name) do
    GenServer.call(__MODULE__, {:clear_cache, cache_name})
  end

  @doc """
  Get cache statistics.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # BaseManager Implementation

  @impl true
  def init_manager(_opts) do
    # Create ETS tables with optimal settings for each cache type
    # Use try/catch to handle case where tables already exist
    _ =
      create_table_safe(@csi_parser_cache, [
        :set,
        :public,
        :named_table,
        read_concurrency: true
      ])

    _ =
      create_table_safe(@cell_cache, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])

    _ =
      create_table_safe(@style_cache, [
        :set,
        :public,
        :named_table,
        read_concurrency: true
      ])

    _ =
      create_table_safe(@buffer_cache, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])

    _ =
      create_table_safe(@layout_cache, [
        :set,
        :public,
        :named_table,
        read_concurrency: true
      ])

    _ =
      create_table_safe(@font_metrics_cache, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])

    # Track hit/miss statistics
    stats = %{
      csi: %{hits: 0, misses: 0},
      cell: %{hits: 0, misses: 0},
      style: %{hits: 0, misses: 0},
      buffer: %{hits: 0, misses: 0},
      layout: %{hits: 0, misses: 0},
      font_metrics: %{hits: 0, misses: 0}
    }

    {:ok, %{stats: stats}}
  end

  @impl true
  def handle_manager_call(:clear_all, _from, state) do
    _ = :ets.delete_all_objects(@csi_parser_cache)
    _ = :ets.delete_all_objects(@cell_cache)
    _ = :ets.delete_all_objects(@style_cache)
    _ = :ets.delete_all_objects(@buffer_cache)
    _ = :ets.delete_all_objects(@layout_cache)
    _ = :ets.delete_all_objects(@font_metrics_cache)

    {:reply, :ok, state}
  end

  def handle_manager_call({:clear_cache, cache_name}, _from, state) do
    table = get_table_name(cache_name)
    _ = :ets.delete_all_objects(table)
    {:reply, :ok, state}
  end

  def handle_manager_call(:stats, _from, state) do
    stats = %{
      csi_parser: table_stats(@csi_parser_cache),
      cell: table_stats(@cell_cache),
      style: table_stats(@style_cache),
      buffer: table_stats(@buffer_cache),
      layout: table_stats(@layout_cache),
      font_metrics: table_stats(@font_metrics_cache),
      hit_rates: state.stats
    }

    {:reply, stats, state}
  end

  # Private functions

  defp enforce_cache_limit(table, max_entries) do
    case :ets.info(table, :size) do
      size when size > max_entries ->
        # Evict oldest entries (LRU)
        evict_count = div(size - max_entries, 2) + 1
        evict_lru_entries(table, evict_count)

      _ ->
        :ok
    end
  end

  defp evict_lru_entries(table, count) do
    # Get all entries sorted by timestamp (oldest first)
    entries =
      :ets.tab2list(table)
      |> Enum.sort_by(fn {_key, _value, timestamp} -> timestamp end)
      |> Enum.take(count)

    # Delete the oldest entries
    _ =
      Enum.each(entries, fn {key, _, _} ->
        :ets.delete(table, key)
      end)
  end

  defp table_stats(table) do
    %{
      size: :ets.info(table, :size),
      memory_bytes: :ets.info(table, :memory) * :erlang.system_info(:wordsize),
      keypos: :ets.info(table, :keypos),
      type: :ets.info(table, :type)
    }
  end

  defp get_table_name(:csi_parser), do: @csi_parser_cache
  defp get_table_name(:cell), do: @cell_cache
  defp get_table_name(:style), do: @style_cache
  defp get_table_name(:buffer), do: @buffer_cache
  defp get_table_name(:layout), do: @layout_cache
  defp get_table_name(:font_metrics), do: @font_metrics_cache
  defp get_table_name(name), do: name

  defp create_table_safe(table_name, options) do
    try do
      :ets.new(table_name, options)
    rescue
      ArgumentError ->
        # Table already exists, just return the table name
        table_name
    end
  end
end
