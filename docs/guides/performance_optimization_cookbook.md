# Performance Optimization Cookbook

## Overview

This cookbook provides practical strategies for optimizing Raxol applications across all performance dimensions: rendering speed, memory usage, parser efficiency, and user experience responsiveness.

## Quick Performance Wins

### 1. Enable Differential Rendering

**Problem**: Full screen redraws on every update cause flickering and high CPU usage.

**Solution**: Use Raxol's built-in differential rendering:

```elixir
defmodule MyApp.Dashboard do
  use Raxol.UI, framework: :react
  import Raxol.LiveView, only: [assign: 2, assign: 3]

  def mount(_params, _session, socket) do
    socket = 
      socket
      |> assign(:enable_diff_rendering, true)
      |> assign(:damage_tracking, :optimized)
      
    {:ok, socket}
  end
  
  def render(assigns) do
    ~H"""
    <.container class="dashboard" diff_key="main">
      <.panel 
        title="CPU Usage" 
        value={@cpu_usage}
        diff_key="cpu"
        should_update={@cpu_changed}
      />
    </.container>
    """
  end
end
```

**Impact**: 60-80% reduction in render time for complex UIs.

### 2. Implement Smart Buffer Pooling

**Problem**: Frequent buffer allocations cause memory fragmentation.

**Solution**: Use Raxol's buffer pool:

```elixir
defmodule MyApp.BufferManager do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Configure buffer pool
    pool_config = %{
      initial_size: 50,
      max_size: 200,
      buffer_size: 8192,
      prealloc_strategy: :lazy
    }
    
    {:ok, pool_config}
  end
  
  def get_buffer() do
    GenServer.call(__MODULE__, :get_buffer)
  end
  
  def return_buffer(buffer) do
    GenServer.cast(__MODULE__, {:return_buffer, buffer})
  end
end
```

**Impact**: 40% reduction in memory allocations.

## Rendering Performance

### Batch Updates

**Anti-pattern**:
```elixir
# DON'T: Individual updates
def handle_info({:cpu_update, value}, socket) do
  {:noreply, assign(socket, :cpu, value)}
end

def handle_info({:memory_update, value}, socket) do
  {:noreply, assign(socket, :memory, value)}
end
```

**Best practice**:
```elixir
# DO: Batched updates
def handle_info(:system_update, socket) do
  updates = collect_system_metrics()
  
  socket = 
    socket
    |> assign(:cpu, updates.cpu)
    |> assign(:memory, updates.memory)
    |> assign(:disk, updates.disk)
    |> assign(:last_update, System.monotonic_time())
    
  {:noreply, socket}
end
```

### Optimize Component Hierarchies

**Anti-pattern**:
```elixir
# DON'T: Deep nesting with frequent updates
def render(assigns) do
  ~H"""
  <.container>
    <.wrapper>
      <.inner_wrapper>
        <.content_area>
          <.data_display value={@frequently_changing_value} />
        </.content_area>
      </.inner_wrapper>
    </.wrapper>
  </.container>
  """
end
```

**Best practice**:
```elixir
# DO: Flat hierarchy with isolated updates
def render(assigns) do
  ~H"""
  <.container class="dashboard-grid">
    <.data_display 
      value={@frequently_changing_value}
      diff_boundary={true}
      update_strategy={:isolated}
    />
  </.container>
  """
end
```

## Memory Optimization

### ETS Table Strategies

```elixir
defmodule MyApp.CacheManager do
  use GenServer
  
  @table_name :raxol_cache
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  def init(_) do
    # Optimize ETS table configuration
    :ets.new(@table_name, [
      :set,
      :named_table,
      :public,
      {:read_concurrency, true},
      {:write_concurrency, true},
      {:decentralized_counters, true}
    ])
    
    {:ok, %{}}
  end
  
  def cache_render_result(key, result) do
    # Use compressed storage for large render trees
    compressed = :erlang.term_to_binary(result, [:compressed])
    :ets.insert(@table_name, {key, compressed, System.monotonic_time()})
  end
  
  def get_cached_result(key, max_age_ms) do
    case :ets.lookup(@table_name, key) do
      [{^key, compressed_data, timestamp}] ->
        if System.monotonic_time() - timestamp < max_age_ms * 1_000_000 do
          {:ok, :erlang.binary_to_term(compressed_data)}
        else
          {:error, :expired}
        end
        
      [] ->
        {:error, :not_found}
    end
  end
end
```

### Memory Pressure Detection

```elixir
defmodule MyApp.MemoryMonitor do
  use GenServer
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  def init(_) do
    schedule_memory_check()
    {:ok, %{high_memory_mode: false}}
  end
  
  def handle_info(:check_memory, state) do
    memory_usage = get_memory_usage()
    high_memory_threshold = 0.8 # 80% of available memory
    
    new_state = 
      if memory_usage > high_memory_threshold do
        trigger_memory_optimization()
        %{state | high_memory_mode: true}
      else
        %{state | high_memory_mode: false}
      end
    
    schedule_memory_check()
    {:noreply, new_state}
  end
  
  defp trigger_memory_optimization do
    # Clear render caches
    MyApp.CacheManager.clear_old_entries()
    
    # Reduce buffer pool size
    Raxol.Terminal.BufferPool.shrink()
    
    # Force garbage collection
    :erlang.garbage_collect()
  end
  
  defp get_memory_usage do
    {total_mem, allocated_mem, _} = :memsup.get_memory_data()
    allocated_mem / total_mem
  end
  
  defp schedule_memory_check do
    Process.send_after(self(), :check_memory, 5_000)
  end
end
```

## Parser Performance

### State Machine Optimization

```elixir
defmodule MyApp.OptimizedParser do
  @moduledoc """
  Optimized ANSI parser with state caching and predictive parsing.
  Target: <3.3μs per operation
  """
  
  # Pre-compile common sequences
  @common_sequences %{
    "\e[H" => {:cursor_home, []},
    "\e[2J" => {:clear_screen, []},
    "\e[K" => {:clear_line, []},
    "\e[0m" => {:reset_attributes, []}
  }
  
  # Use binary pattern matching for hot paths
  def parse_sequence(<<"\e[", rest::binary>>, state) do
    case parse_csi_sequence(rest, state) do
      {:ok, command, new_state} -> 
        {:ok, command, cache_state(new_state)}
      error -> 
        error
    end
  end
  
  # Fast path for common sequences
  def parse_sequence(sequence, state) when is_binary(sequence) do
    case Map.get(@common_sequences, sequence) do
      nil -> parse_sequence_slow(sequence, state)
      command -> {:ok, command, state}
    end
  end
  
  defp parse_csi_sequence(data, state) do
    # Use iodata for efficient string building
    parse_csi_sequence(data, state, _params = [], _intermediate = [])
  end
  
  defp parse_csi_sequence(<<char, rest::binary>>, state, params, intermediate) 
       when char >= ?0 and char <= ?9 do
    # Parse numeric parameters efficiently
    {param, remaining} = parse_number(<<char, rest::binary>>)
    parse_csi_sequence(remaining, state, [param | params], intermediate)
  end
  
  # Cache frequently used parser states
  defp cache_state(state) do
    state_key = :erlang.phash2(state, 1000)
    :persistent_term.put({:parser_state, state_key}, state)
    state
  end
end
```

### Predictive Parsing

```elixir
defmodule MyApp.PredictiveParser do
  @moduledoc """
  Parser with sequence prediction for common patterns.
  """
  
  use GenServer
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  def init(_) do
    # Load sequence patterns from historical data
    patterns = load_sequence_patterns()
    {:ok, %{patterns: patterns, predictions: %{}}}
  end
  
  def parse_with_prediction(data, context) do
    GenServer.call(__MODULE__, {:parse, data, context})
  end
  
  def handle_call({:parse, data, context}, _from, state) do
    # Try prediction first
    case predict_next_sequence(data, context, state.patterns) do
      {:ok, predicted_commands} ->
        {:reply, {:predicted, predicted_commands}, state}
        
      :no_prediction ->
        # Fall back to regular parsing
        result = MyApp.OptimizedParser.parse_sequence(data, context)
        {:reply, result, update_patterns(state, data, result)}
    end
  end
  
  defp predict_next_sequence(data, context, patterns) do
    pattern_key = {context.last_command, String.slice(data, 0, 4)}
    
    case Map.get(patterns, pattern_key) do
      nil -> :no_prediction
      predicted_sequence -> {:ok, predicted_sequence}
    end
  end
  
  defp update_patterns(state, data, parse_result) do
    # Machine learning could be added here to improve predictions
    %{state | patterns: state.patterns}
  end
  
  defp load_sequence_patterns do
    # Load from persistent storage or start with common patterns
    %{
      {:clear_screen, "\e[2J"} => [{:cursor_home, []}, {:clear_screen, []}],
      {:cursor_move, "\e["} => [{:cursor_move, [1, 1]}]
    }
  end
end
```

## Component Performance

### Lazy Loading and Code Splitting

```elixir
defmodule MyApp.LazyComponent do
  use Raxol.UI, framework: :react
  import Raxol.LiveView, only: [assign: 2, assign: 3, assign_new: 2, update: 3]
  
  # Lazy load heavy components
  def mount(_params, _session, socket) do
    socket = 
      socket
      |> assign(:loaded_components, MapSet.new())
      |> assign(:component_cache, %{})
      
    {:ok, socket}
  end
  
  def render(assigns) do
    ~H"""
    <div class="lazy-container">
      <%= if component_loaded?(@loaded_components, :heavy_chart) do %>
        <.live_component 
          module={MyApp.Components.HeavyChart}
          id="heavy_chart"
          data={@chart_data}
        />
      <% else %>
        <div class="loading-placeholder" phx-hook="LazyLoader" data-component="heavy_chart">
          Loading chart...
        </div>
      <% end %>
    </div>
    """
  end
  
  def handle_event("load_component", %{"component" => component}, socket) do
    component_atom = String.to_existing_atom(component)
    
    socket = 
      socket
      |> update(:loaded_components, &MapSet.put(&1, component_atom))
      |> preload_component_data(component_atom)
    
    {:noreply, socket}
  end
  
  defp component_loaded?(loaded_components, component) do
    MapSet.member?(loaded_components, component)
  end
  
  defp preload_component_data(socket, :heavy_chart) do
    # Only load data when component is needed
    chart_data = expensive_chart_calculation()
    assign(socket, :chart_data, chart_data)
  end
end
```

## Real-Time Updates

### Adaptive Frame Rate

```elixir
defmodule MyApp.AdaptiveFrameRate do
  use GenServer
  
  @default_fps 60
  @min_fps 10
  @max_fps 120
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  def init(_) do
    state = %{
      current_fps: @default_fps,
      frame_times: :queue.new(),
      last_frame: System.monotonic_time(:microsecond)
    }
    
    schedule_frame()
    {:ok, state}
  end
  
  def handle_info(:frame, state) do
    current_time = System.monotonic_time(:microsecond)
    frame_duration = current_time - state.last_frame
    
    # Calculate rolling average frame time
    frame_times = 
      state.frame_times
      |> :queue.in(frame_duration)
      |> limit_queue_size(30) # Keep last 30 frame times
    
    avg_frame_time = calculate_average_frame_time(frame_times)
    new_fps = adapt_frame_rate(avg_frame_time, state.current_fps)
    
    # Trigger render if needed
    if should_render?(new_fps, avg_frame_time) do
      Phoenix.PubSub.broadcast(MyApp.PubSub, "renders", :render_frame)
    end
    
    new_state = %{
      state |
      current_fps: new_fps,
      frame_times: frame_times,
      last_frame: current_time
    }
    
    schedule_frame(new_fps)
    {:noreply, new_state}
  end
  
  defp adapt_frame_rate(avg_frame_time, current_fps) do
    target_frame_time = 1_000_000 / current_fps # microseconds
    
    cond do
      # If we're consistently slow, reduce FPS
      avg_frame_time > target_frame_time * 1.5 and current_fps > @min_fps ->
        max(current_fps - 5, @min_fps)
        
      # If we're consistently fast, increase FPS  
      avg_frame_time < target_frame_time * 0.8 and current_fps < @max_fps ->
        min(current_fps + 5, @max_fps)
        
      true ->
        current_fps
    end
  end
  
  defp schedule_frame(fps \\ @default_fps) do
    interval = div(1000, fps)
    Process.send_after(self(), :frame, interval)
  end
end
```

## Benchmarking and Profiling

### Custom Benchmarks

```elixir
defmodule MyApp.Benchmarks do
  @moduledoc """
  Application-specific performance benchmarks.
  """
  
  def run_render_benchmark do
    inputs = %{
      "Small UI (10 components)" => generate_small_ui(),
      "Medium UI (100 components)" => generate_medium_ui(), 
      "Large UI (1000 components)" => generate_large_ui()
    }
    
    Benchee.run(
      %{
        "render_with_diff" => fn ui_data ->
          MyApp.Renderer.render_with_diff(ui_data)
        end,
        "render_full" => fn ui_data ->
          MyApp.Renderer.render_full(ui_data)
        end
      },
      inputs: inputs,
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.JSON, file: "bench/results/render_benchmark.json"}
      ],
      memory_time: 2,
      reduction_time: 2
    )
  end
  
  def profile_memory_usage do
    :fprof.start()
    :fprof.trace(:start)
    
    # Run test scenario
    run_memory_intensive_scenario()
    
    :fprof.trace(:stop)
    :fprof.profile()
    :fprof.analyse({:dest, "profile_results.txt"})
    :fprof.stop()
  end
  
  def run_parser_stress_test do
    # Generate realistic ANSI sequences
    sequences = generate_ansi_sequences(10_000)
    
    {time, _result} = :timer.tc(fn ->
      Enum.each(sequences, fn seq ->
        MyApp.OptimizedParser.parse_sequence(seq, %{})
      end)
    end)
    
    avg_time_per_op = time / length(sequences)
    
    IO.puts("Average parse time: #{avg_time_per_op}μs per operation")
    
    if avg_time_per_op > 3.3 do
      IO.puts("[WARN]  Parser performance below target (3.3μs)")
    else
      IO.puts("[OK] Parser performance meets target")
    end
  end
end
```

## Performance Monitoring

### Runtime Metrics Collection

```elixir
defmodule MyApp.PerformanceMetrics do
  use GenServer
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  def init(_) do
    schedule_metrics_collection()
    
    {:ok, %{
      metrics: %{},
      alerts: [],
      baseline: load_performance_baseline()
    }}
  end
  
  def handle_info(:collect_metrics, state) do
    metrics = %{
      memory_usage: get_memory_metrics(),
      render_times: get_render_metrics(), 
      parser_performance: get_parser_metrics(),
      frame_rate: get_frame_rate_metrics(),
      timestamp: System.monotonic_time(:second)
    }
    
    # Check for performance regressions
    alerts = check_performance_alerts(metrics, state.baseline)
    
    # Store metrics (could be sent to external monitoring)
    store_metrics(metrics)
    
    new_state = %{state | metrics: metrics, alerts: alerts}
    
    schedule_metrics_collection()
    {:noreply, new_state}
  end
  
  defp check_performance_alerts(current_metrics, baseline) do
    alerts = []
    
    # Check render time regression
    alerts = 
      if current_metrics.render_times.avg > baseline.render_times.avg * 1.2 do
        [{:render_regression, current_metrics.render_times.avg} | alerts]
      else
        alerts
      end
    
    # Check memory usage
    alerts = 
      if current_metrics.memory_usage.total > baseline.memory_usage.total * 1.5 do
        [{:memory_usage_high, current_metrics.memory_usage.total} | alerts]
      else
        alerts
      end
    
    alerts
  end
  
  defp get_render_metrics do
    # Get render timing data from your application
    %{
      avg: 2.1,      # milliseconds
      p95: 4.2,
      p99: 8.1,
      count: 1000
    }
  end
  
  defp get_parser_metrics do
    %{
      avg_parse_time: 2.8,  # microseconds
      sequences_per_sec: 35_000,
      cache_hit_rate: 0.85
    }
  end
end
```

## Anti-Patterns to Avoid

### 1. Synchronous Heavy Operations

```elixir
# [FAIL] DON'T: Block the UI thread
def handle_event("generate_report", _params, socket) do
  report = generate_heavy_report()  # Takes 5 seconds
  {:noreply, assign(socket, :report, report)}
end

# [OK] DO: Use background processing
def handle_event("generate_report", _params, socket) do
  Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
    report = generate_heavy_report()
    send(self(), {:report_ready, report})
  end)
  
  {:noreply, assign(socket, :loading_report, true)}
end

def handle_info({:report_ready, report}, socket) do
  socket = 
    socket
    |> assign(:report, report)
    |> assign(:loading_report, false)
    
  {:noreply, socket}
end
```

### 2. Inefficient State Updates

```elixir
# [FAIL] DON'T: Update entire large data structures
def handle_event("update_item", %{"id" => id, "value" => value}, socket) do
  items = 
    socket.assigns.items
    |> Enum.map(fn item ->
      if item.id == id do
        %{item | value: value}
      else
        item
      end
    end)
    
  {:noreply, assign(socket, :items, items)}
end

# [OK] DO: Use targeted updates
def handle_event("update_item", %{"id" => id, "value" => value}, socket) do
  socket = update(socket, :items, fn items ->
    Map.update!(items, id, &%{&1 | value: value})
  end)
  
  {:noreply, socket}
end
```

### 3. Memory Leaks

```elixir
# [FAIL] DON'T: Accumulate unbounded data
def handle_info({:log_event, event}, socket) do
  events = [event | socket.assigns.events]
  {:noreply, assign(socket, :events, events)}
end

# [OK] DO: Implement bounded collections
def handle_info({:log_event, event}, socket) do
  events = 
    [event | socket.assigns.events]
    |> Enum.take(1000)  # Keep only last 1000 events
    
  {:noreply, assign(socket, :events, events)}
end
```

## Performance Testing Strategy

### Continuous Performance Testing

```elixir
defmodule MyApp.CIPerfomanceTest do
  @moduledoc """
  Performance tests for CI pipeline.
  """
  
  use ExUnit.Case
  
  @performance_targets %{
    render_time_ms: 5.0,
    parser_time_us: 3.3,
    memory_mb: 2.8,
    startup_time_ms: 100.0
  }
  
  test "render performance meets targets" do
    {time, _result} = :timer.tc(fn ->
      MyApp.TestRenderer.render_complex_ui()
    end)
    
    time_ms = time / 1000
    
    assert time_ms < @performance_targets.render_time_ms,
           "Render time #{time_ms}ms exceeds target #{@performance_targets.render_time_ms}ms"
  end
  
  test "parser performance meets targets" do
    sequences = MyApp.TestData.generate_ansi_sequences(1000)
    
    {time, _results} = :timer.tc(fn ->
      Enum.map(sequences, &MyApp.OptimizedParser.parse_sequence(&1, %{}))
    end)
    
    avg_time_us = time / length(sequences)
    
    assert avg_time_us < @performance_targets.parser_time_us,
           "Parser time #{avg_time_us}μs exceeds target #{@performance_targets.parser_time_us}μs"
  end
  
  test "memory usage stays within bounds" do
    :erlang.garbage_collect()
    {memory_before, _} = :erlang.process_info(self(), :memory)
    
    # Run memory-intensive operations
    MyApp.TestScenarios.run_memory_intensive_scenario()
    
    :erlang.garbage_collect()
    {memory_after, _} = :erlang.process_info(self(), :memory)
    
    memory_used_mb = (memory_after - memory_before) / 1_048_576
    
    assert memory_used_mb < @performance_targets.memory_mb,
           "Memory usage #{memory_used_mb}MB exceeds target #{@performance_targets.memory_mb}MB"
  end
end
```

## Production Optimization Checklist

- [ ] **Rendering**
  - [ ] Differential rendering enabled
  - [ ] Component boundaries optimized
  - [ ] Batch updates implemented
  - [ ] Lazy loading for heavy components

- [ ] **Memory Management**
  - [ ] Buffer pooling configured
  - [ ] ETS tables optimized
  - [ ] Memory pressure detection active
  - [ ] Garbage collection tuned

- [ ] **Parser Performance**
  - [ ] Common sequences pre-compiled
  - [ ] State caching implemented
  - [ ] Binary pattern matching used
  - [ ] Predictive parsing enabled

- [ ] **Monitoring**
  - [ ] Performance metrics collected
  - [ ] Regression alerts configured
  - [ ] Benchmarks in CI pipeline
  - [ ] Memory leak detection active

- [ ] **Code Quality** 
  - [ ] Hot paths identified and optimized
  - [ ] Anti-patterns eliminated
  - [ ] Performance tests passing
  - [ ] Documentation updated

## Further Resources

- [Raxol Parser Benchmarks](../../bench/parser_profiling.exs)
- [Rendering Pipeline Profiler](../../bench/render_pipeline_profiling.exs)
- [Memory Usage Analysis](../../bench/memory_analysis.exs)
- [Performance Testing Guide](./performance_testing.md)
- [Architecture Decision Records](../adr/README.md)

---

*This cookbook is continuously updated based on real-world performance optimizations. Contribute improvements by submitting examples of successful optimizations.*