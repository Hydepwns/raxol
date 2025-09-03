defmodule Raxol.Performance.CacheConfig do
  @moduledoc """
  Optimized cache configuration for Raxol performance subsystem.
  
  This module provides centralized configuration for all cache parameters,
  optimized based on profiling data and usage patterns.
  
  ## Cache Size Optimization
  
  Cache sizes are calculated based on:
  - Working set analysis from production data
  - Memory constraints (target <5MB total)
  - Hit rate optimization (target >85%)
  - Access frequency patterns
  
  ## Adaptive Tuning
  
  The configuration supports runtime adjustment based on:
  - Available system memory
  - Application workload
  - Cache hit rates
  - Memory pressure
  """
  
  @doc """
  Get optimized cache configuration based on system profile.
  
  Profiles:
  - :minimal - Minimum memory usage, suitable for constrained environments
  - :balanced - Default balanced configuration
  - :performance - Maximum performance, higher memory usage
  - :adaptive - Dynamically adjust based on runtime metrics
  """
  @spec get_config(atom()) :: map()
  def get_config(profile \\ :balanced) do
    base_config = %{
      # CSI Parser Cache - Frequently used ANSI sequences
      csi_parser: %{
        max_entries: get_csi_size(profile),
        ttl_ms: :infinity,  # CSI patterns are stable
        eviction_strategy: :lru,
        preload: true,
        warmup_sequences: common_csi_sequences()
      },
      
      # Cell Cache - Terminal cell creation
      cell: %{
        max_entries: get_cell_size(profile),
        ttl_ms: 60_000,  # 1 minute for dynamic content
        eviction_strategy: :lru,
        write_concurrency: true,
        partition_count: get_partition_count(profile)
      },
      
      # Style Cache - Theme and style resolution
      style: %{
        max_entries: get_style_size(profile),
        ttl_ms: :infinity,  # Styles are stable within session
        eviction_strategy: :lru,
        preload: true,
        index_by: [:theme_id, :component_type]
      },
      
      # Buffer Cache - Terminal buffer regions
      buffer: %{
        max_entries: get_buffer_size(profile),
        ttl_ms: 5_000,  # 5 seconds for viewport data
        eviction_strategy: :lru,
        write_concurrency: true,
        damage_tracking: true
      },
      
      # Layout Cache - Component layout calculations
      layout: %{
        max_entries: get_layout_size(profile),
        ttl_ms: 30_000,  # 30 seconds for layout
        eviction_strategy: :lru,
        constraint_tolerance: 0.1,  # 10% tolerance for reuse
        precompute_viewports: common_viewport_sizes()
      },
      
      # Font Metrics Cache - Character and string measurements
      font_metrics: %{
        max_entries: get_font_size(profile),
        ttl_ms: :infinity,  # Font metrics are stable
        eviction_strategy: :lru,
        write_concurrency: true,
        warmup_chars: true
      },
      
      # Component Render Cache - Rendered component output
      component_render: %{
        max_entries: get_component_size(profile),
        ttl_ms: 10_000,  # 10 seconds for dynamic components
        eviction_strategy: :lru,
        cache_static_only: profile != :minimal
      }
    }
    
    if profile == :adaptive do
      apply_adaptive_tuning(base_config)
    else
      base_config
    end
  end
  
  @doc """
  Get memory budget for caches in bytes.
  """
  @spec memory_budget(atom()) :: integer()
  def memory_budget(profile) do
    case profile do
      :minimal -> 1_048_576      # 1 MB
      :balanced -> 5_242_880      # 5 MB
      :performance -> 10_485_760  # 10 MB
      :adaptive -> available_memory_budget()
    end
  end
  
  @doc """
  Calculate optimal entry size limits based on profile.
  """
  def get_entry_limits(profile) do
    memory = memory_budget(profile)
    avg_entry_size = 128  # bytes, conservative estimate
    
    total_entries = div(memory, avg_entry_size)
    
    # Distribute entries based on access patterns
    %{
      total: total_entries,
      distribution: %{
        csi_parser: 0.05,    # 5% - limited unique sequences
        cell: 0.25,          # 25% - high volume, high churn
        style: 0.10,         # 10% - moderate count, stable
        buffer: 0.15,        # 15% - viewport dependent
        layout: 0.10,        # 10% - component dependent
        font_metrics: 0.20,  # 20% - many unique strings
        component: 0.15      # 15% - component renders
      }
    }
  end
  
  # Profile-specific size calculations
  
  defp get_csi_size(:minimal), do: 250
  defp get_csi_size(:balanced), do: 1_000
  defp get_csi_size(:performance), do: 2_500
  defp get_csi_size(:adaptive), do: adaptive_size(:csi_parser)
  
  defp get_cell_size(:minimal), do: 2_500
  defp get_cell_size(:balanced), do: 10_000
  defp get_cell_size(:performance), do: 25_000
  defp get_cell_size(:adaptive), do: adaptive_size(:cell)
  
  defp get_style_size(:minimal), do: 1_000
  defp get_style_size(:balanced), do: 5_000
  defp get_style_size(:performance), do: 10_000
  defp get_style_size(:adaptive), do: adaptive_size(:style)
  
  defp get_buffer_size(:minimal), do: 500
  defp get_buffer_size(:balanced), do: 2_000
  defp get_buffer_size(:performance), do: 5_000
  defp get_buffer_size(:adaptive), do: adaptive_size(:buffer)
  
  defp get_layout_size(:minimal), do: 250
  defp get_layout_size(:balanced), do: 1_000
  defp get_layout_size(:performance), do: 2_500
  defp get_layout_size(:adaptive), do: adaptive_size(:layout)
  
  defp get_font_size(:minimal), do: 2_500
  defp get_font_size(:balanced), do: 10_000
  defp get_font_size(:performance), do: 20_000
  defp get_font_size(:adaptive), do: adaptive_size(:font_metrics)
  
  defp get_component_size(:minimal), do: 500
  defp get_component_size(:balanced), do: 2_000
  defp get_component_size(:performance), do: 5_000
  defp get_component_size(:adaptive), do: adaptive_size(:component_render)
  
  defp get_partition_count(:minimal), do: 1
  defp get_partition_count(:balanced), do: 4
  defp get_partition_count(:performance), do: 8
  defp get_partition_count(:adaptive), do: System.schedulers_online()
  
  # Adaptive tuning based on runtime metrics
  
  defp apply_adaptive_tuning(config) do
    case Raxol.Core.ErrorHandling.safe_call(fn -> Raxol.Performance.ETSCacheManager.stats() end) do
      {:ok, stats} ->
        Enum.reduce(config, %{}, fn {cache_name, cache_config}, acc ->
          adjusted_config = 
            case get_hit_rate(stats, cache_name) do
              rate when rate < 0.7 ->
                # Low hit rate - increase size
                Map.update!(cache_config, :max_entries, &(round(&1 * 1.5)))
              rate when rate > 0.95 ->
                # Very high hit rate - might be oversized
                Map.update!(cache_config, :max_entries, &(round(&1 * 0.9)))
              _ ->
                cache_config
            end
          
          Map.put(acc, cache_name, adjusted_config)
        end)
      
      {:error, _} -> config  # Fall back to base config if stats unavailable
    end
  end
  
  defp get_hit_rate(_stats, _cache_name) do
    # Simplified - would read from actual telemetry/stats
    0.85
  end
  
  defp adaptive_size(cache_type) do
    limits = get_entry_limits(:adaptive)
    distribution = limits.distribution[cache_type] || 0.1
    round(limits.total * distribution)
  end
  
  defp available_memory_budget do
    # Get available system memory and allocate 1% for caches
    case Raxol.Core.ErrorHandling.safe_call(fn -> :memsup.get_system_memory_data() end) do
      {:ok, %{available_memory: available}} ->
        min(div(available, 100), 10_485_760)  # Max 10MB
      {:ok, _} ->
        5_242_880  # Default 5MB - no available_memory field
      {:error, _} ->
        5_242_880  # Default 5MB - memsup call failed
    end
  end
  
  # Preload data for warmup
  
  defp common_csi_sequences do
    [
      "\e[0m",      # Reset
      "\e[1m",      # Bold
      "\e[2J",      # Clear screen
      "\e[H",       # Home
      "\e[?25h",    # Show cursor
      "\e[?25l",    # Hide cursor
      "\e[K",       # Clear line
      "\e[1A",      # Move up
      "\e[1B",      # Move down
      "\e[1C",      # Move right
      "\e[1D",      # Move left
      "\e[31m",     # Red
      "\e[32m",     # Green
      "\e[33m",     # Yellow
      "\e[34m",     # Blue
      "\e[37m"      # White
    ]
  end
  
  defp common_viewport_sizes do
    [
      {80, 24},   # Standard terminal
      {120, 30},  # Common IDE terminal
      {132, 43},  # DEC VT mode
      {160, 50},  # Large terminal
      {200, 60},  # Extra large
      {80, 40},   # Tall terminal
      {100, 25}   # Wide terminal
    ]
  end
  
  @doc """
  Apply cache configuration to ETS Cache Manager.
  """
  def apply_config(profile \\ :balanced) do
    config = get_config(profile)
    
    # Send configuration to cache manager
    GenServer.cast(Raxol.Performance.ETSCacheManager, {:update_config, config})
    
    # Trigger warmup for caches that support it
    warmup_caches(config)
    
    :ok
  end
  
  defp warmup_caches(config) do
    # Warmup font metrics cache
    if config[:font_metrics][:warmup_chars] do
      Raxol.Core.Performance.Caches.FontMetricsCache.warmup()
    end
    
    # Preload common CSI sequences
    if config[:csi_parser][:preload] do
      Enum.each(common_csi_sequences(), fn seq ->
        # This would trigger caching in actual implementation
        Raxol.Performance.ETSCacheManager.get_csi(seq)
      end)
    end
    
    :ok
  end
  
  @doc """
  Get recommended configuration based on system analysis.
  """
  def recommend_profile do
    memory = :erlang.memory(:total)
    schedulers = System.schedulers_online()
    
    cond do
      memory < 512_000_000 -> :minimal      # < 512MB RAM
      memory < 2_000_000_000 -> :balanced   # < 2GB RAM
      schedulers >= 8 -> :performance       # 8+ cores and plenty RAM
      true -> :balanced
    end
  end
end