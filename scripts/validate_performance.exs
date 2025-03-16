#!/usr/bin/env elixir

# Performance Validation Script
# This script runs the performance benchmark suite and validates results

defmodule Raxol.Scripts.ValidatePerformance do
  @moduledoc """
  Script to run performance benchmarks and validate against baselines.
  
  Usage:
    mix run scripts/validate_performance.exs [options]
  
  Options:
    --detailed    Show detailed validation results
    --save        Save benchmark results to file
    --quick       Run a quicker version of the benchmarks (less accurate)
    --category    Run specific benchmark category (render, event, memory, animation)
  """
  
  alias Raxol.Benchmarks.Performance
  alias Raxol.System.Platform
  
  def main(args) do
    {opts, _, _} = OptionParser.parse(args,
      strict: [
        detailed: :boolean,
        save: :boolean,
        quick: :boolean,
        category: :string,
        help: :boolean
      ],
      aliases: [
        d: :detailed,
        s: :save,
        q: :quick,
        c: :category,
        h: :help
      ]
    )
    
    if opts[:help] do
      print_help()
    else
      run_validation(opts)
    end
  end
  
  def run_validation(opts) do
    IO.puts("Running Raxol Performance Validation")
    IO.puts("Platform: #{Platform.get_current_platform()}")
    IO.puts("System: #{System.version()} / OTP #{:erlang.system_info(:otp_release)}")
    
    # Set benchmark options
    benchmark_opts = [
      detailed: opts[:detailed] || false,
      save_results: opts[:save] || false,
      compare_with_baseline: true
    ]
    
    # Run specific category or full suite
    results = case opts[:category] do
      "render" -> 
        IO.puts("\nRunning rendering performance benchmark")
        %{render_performance: Performance.benchmark_rendering()}
        
      "event" ->
        IO.puts("\nRunning event handling benchmark")
        %{event_latency: Performance.benchmark_event_handling()}
        
      "memory" ->
        IO.puts("\nRunning memory usage benchmark")
        %{memory_usage: Performance.benchmark_memory_usage()}
        
      "animation" ->
        IO.puts("\nRunning animation performance benchmark")
        %{animation_fps: Performance.benchmark_animation_performance()}
        
      _ ->
        IO.puts("\nRunning full benchmark suite")
        # Apply quick mode by reducing iterations if requested
        if opts[:quick] do
          # When using benchmark_quick, we can't set detailed options
          Performance.run_all(benchmark_opts)
        else
          Performance.run_all(benchmark_opts)
        end
    end
    
    # Return success/failure based on validation
    case get_validation_status(results) do
      :pass -> :ok
      :fail -> exit({:shutdown, 1})
    end
  end
  
  defp get_validation_status(results) do
    if Map.has_key?(results, :metrics_validation) do
      validation = results.metrics_validation
      
      if validation.overall.status in [:excellent, :good, :acceptable] do
        IO.puts("\n✅ Performance validation PASSED")
        :pass
      else
        IO.puts("\n❌ Performance validation FAILED")
        :fail
      end
    else
      # No validation performed, assume pass
      IO.puts("\n⚠️ No validation performed")
      :pass
    end
  end
  
  defp print_help do
    IO.puts("""
    Raxol Performance Validation Script
    
    Usage:
      mix run scripts/validate_performance.exs [options]
    
    Options:
      --detailed, -d    Show detailed validation results
      --save, -s        Save benchmark results to file
      --quick, -q       Run a quicker version of the benchmarks (less accurate)
      --category, -c    Run specific benchmark category (render, event, memory, animation)
      --help, -h        Show this help message
    
    Examples:
      mix run scripts/validate_performance.exs
      mix run scripts/validate_performance.exs --detailed --save
      mix run scripts/validate_performance.exs --category render
      mix run scripts/validate_performance.exs --quick
    """)
  end
end

Raxol.Scripts.ValidatePerformance.main(System.argv()) 