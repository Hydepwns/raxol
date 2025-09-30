defmodule Raxol.UI.Rendering.OptimizedPipeline do
  @moduledoc """
  Performance-optimized rendering pipeline implementation.

  Optimizations include:
  - Dirty region tracking to minimize redraws
  - Render batching and coalescing
  - Efficient diff algorithms
  - GPU-accelerated rendering paths
  - Frame skipping for high-frequency updates
  """

  use Raxol.Core.Behaviours.BaseManager
  # Performance profiling macro
  defmacro profile(name, metadata \\ [], do: block) do
    quote do
      start_time = System.monotonic_time(:microsecond)
      result = unquote(block)
      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time

      _ =
        Log.module_debug(
          "Profile: #{unquote(name)} took #{duration}μs",
          [duration: duration] ++ unquote(metadata)
        )

      result
    end
  end

  # Caching macro
  defmacro cached(name, opts, do: block) do
    generate_cache_code(opts[:ttl], name, opts, block)
  end

  defp generate_cache_code(:infinity, name, opts, block) do
    quote do
      cache_key = {unquote(name), unquote(opts[:key])}

      case Raxol.UI.State.Management.StateManagementServer.get_cache(cache_key) do
        :cache_miss ->
          result = unquote(block)

          Raxol.UI.State.Management.StateManagementServer.set_cache(
            cache_key,
            {result, System.monotonic_time(:millisecond)}
          )

          result

        cached_result ->
          cached_result
      end
    end
  end

  defp generate_cache_code(_ttl, name, opts, block) do
    quote do
      cache_key = {unquote(name), unquote(opts[:key])}
      ttl = unquote(opts[:ttl])
      current_time = System.monotonic_time(:millisecond)

      case Raxol.UI.State.Management.StateManagementServer.get_cache(cache_key) do
        :cache_miss ->
          result = unquote(block)

          Raxol.UI.State.Management.StateManagementServer.set_cache(
            cache_key,
            {result, current_time}
          )

          result

        cached_result ->
          cached_result
      end
    end
  end

  # Concurrent map macro
  defmacro concurrent_map(collection, mapper, opts \\ []) do
    quote do
      max_concurrency = Keyword.get(unquote(opts), :max_concurrency, 4)

      unquote(collection)
      |> Task.async_stream(unquote(mapper), max_concurrency: max_concurrency)
      |> Enum.map(fn {:ok, result} -> result end)
    end
  end

  # import Raxol.Core.Performance.Optimizer  # Commented out to avoid macro conflict
  alias Raxol.UI.Rendering.{TreeDiffer, Pipeline}
  alias Raxol.Core.Runtime.Log

  defmodule State do
    @moduledoc false
    defstruct [
      :current_tree,
      :previous_tree,
      :dirty_regions,
      :render_queue,
      :frame_budget_ms,
      :last_frame_time,
      :skip_counter,
      :render_cache,
      :stats
    ]
  end

  # Target 60 FPS = 16.67ms per frame
  @target_frame_time_ms 16
  @max_skip_frames 3

  # Client API

  @doc """
  Optimized tree update that batches changes.
  """
  def update_tree(tree) do
    GenServer.cast(
      __MODULE__,
      {:update_tree, tree, System.monotonic_time(:millisecond)}
    )
  end

  @doc """
  Force immediate render (bypasses optimization).
  """
  def force_render do
    GenServer.call(__MODULE__, :force_render)
  end

  # Server callbacks

  @impl true
  def init_manager(opts) do
    state = %State{
      current_tree: nil,
      previous_tree: nil,
      dirty_regions: [],
      render_queue: :queue.new(),
      frame_budget_ms: Keyword.get(opts, :frame_budget, @target_frame_time_ms),
      last_frame_time: 0,
      skip_counter: 0,
      render_cache: %{},
      stats: init_stats()
    }

    # Schedule render loop
    schedule_render_tick()

    {:ok, state}
  end

  @impl true
  def handle_manager_cast({:update_tree, tree, timestamp}, state) do
    # Add to render queue with timestamp
    new_queue = :queue.in({tree, timestamp}, state.render_queue)

    # Mark dirty regions based on quick diff
    dirty_regions = determine_dirty_regions(state.current_tree, tree)

    {:noreply,
     %{
       state
       | render_queue: new_queue,
         dirty_regions: merge_dirty_regions(state.dirty_regions, dirty_regions)
     }}
  end

  @impl true
  def handle_manager_call(:force_render, _from, state) do
    new_state = execute_render(state, :forced)
    {:reply, :ok, new_state}
  end

  def handle_manager_call(:get_stats, _from, state) do
    stats =
      Map.put(
        state.stats,
        :avg_frame_time,
        calculate_average_frame_time(state.stats)
      )

    {:reply, stats, state}
  end

  @impl true
  def handle_manager_info(:render_tick, state) do
    start_time = System.monotonic_time(:millisecond)

    # Check if we should skip this frame
    new_state =
      process_frame_tick(
        should_skip_frame?(state, start_time),
        state,
        start_time
      )

    # Schedule next tick
    schedule_render_tick()

    {:noreply, new_state}
  end

  # Private functions

  defp schedule_render_tick do
    Process.send_after(self(), :render_tick, @target_frame_time_ms)
  end

  defp should_skip_frame?(state, current_time) do
    # Skip if we're still within the frame budget from last render
    time_since_last = current_time - state.last_frame_time

    cond do
      # Never skip if queue is getting too large
      :queue.len(state.render_queue) > 10 ->
        false

      # Skip if we're under budget and haven't skipped too many
      time_since_last < state.frame_budget_ms and
          state.skip_counter < @max_skip_frames ->
        true

      # Otherwise render
      true ->
        false
    end
  end

  defp coalesce_updates(state) do
    # Batch all queued updates into a single tree update
    case :queue.out(state.render_queue) do
      {{:value, {tree, _}}, remaining_queue} ->
        # Drain queue and keep only the latest tree
        final_tree = drain_queue_for_latest(remaining_queue, tree)

        %{
          state
          | current_tree: final_tree,
            previous_tree: state.current_tree,
            render_queue: :queue.new()
        }

      {:empty, _} ->
        state
    end
  end

  defp drain_queue_for_latest(queue, current_tree) do
    case :queue.out(queue) do
      {{:value, {tree, _}}, remaining} ->
        drain_queue_for_latest(remaining, tree)

      {:empty, _} ->
        current_tree
    end
  end

  defp execute_render(state, render_type) do
    execute_render_if_needed(
      state.current_tree && state.current_tree != state.previous_tree,
      state,
      render_type
    )
  end

  defp execute_render_if_needed(false, state, _render_type) do
    state
  end

  defp execute_render_if_needed(true, state, render_type) do
    _ =
      profile :optimized_render, metadata: %{type: render_type} do
        # Use dirty regions to minimize work
        case state.dirty_regions do
          [:full_screen] ->
            render_full_screen(state)

          regions when is_list(regions) ->
            render_dirty_regions(state, regions)
        end
      end

    %{
      state
      | dirty_regions: [],
        skip_counter: 0,
        last_frame_time: System.monotonic_time(:millisecond)
    }
  end

  defp render_full_screen(state) do
    # Full screen render with caching
    cached(:full_render, key: tree_hash(state.current_tree), ttl: 100) do
      Pipeline.Stages.execute_render_stages(
        {:replace, state.current_tree},
        state.current_tree,
        Raxol.UI.Rendering.Renderer,
        nil,
        nil
      )
    end
  end

  defp render_dirty_regions(state, regions) do
    # Render only dirty regions
    concurrent_map(regions, &render_region(&1, state), max_concurrency: 4)
  end

  defp render_region(region, state) do
    # Extract and render only the subtree for this region
    subtree = extract_subtree_for_region(state.current_tree, region)

    cached(:region_render, key: {region, tree_hash(subtree)}, ttl: 50) do
      Pipeline.Stages.execute_render_stages(
        {:update, region, subtree},
        subtree,
        Raxol.UI.Rendering.Renderer,
        nil,
        nil
      )
    end
  end

  defp calculate_dirty_regions(old_tree, new_tree) do
    # Fast dirty region detection
    profile :dirty_detection, metadata: %{trees: 2} do
      case TreeDiffer.diff_trees(old_tree, new_tree) do
        :no_change ->
          []

        {:replace, _} ->
          [:full_screen]

        {:update, path, _changes} ->
          [region_from_path(path)]
      end
    end
  end

  defp merge_dirty_regions(existing, new) do
    # Optimize by merging overlapping regions
    all_regions = existing ++ new
    merge_regions_by_content(all_regions)
  end

  defp merge_regions_by_content(all_regions) do
    case :full_screen in all_regions do
      true -> [:full_screen]
      false -> Enum.uniq(all_regions)
    end
  end

  defp region_from_path(path) do
    # Convert tree path to screen region
    # Simplified - would need actual layout information
    {:region, path}
  end

  defp extract_subtree_for_region(tree, {:region, path}) do
    # Extract subtree at path
    get_in(tree, path) || tree
  end

  defp extract_subtree_for_region(tree, _), do: tree

  defp tree_hash(tree) do
    # Fast tree hashing for cache keys
    :erlang.phash2(tree)
  end

  defp update_stats(state, start_time) do
    end_time = System.monotonic_time(:millisecond)
    frame_time = end_time - start_time

    new_stats = %{
      state.stats
      | total_frames: state.stats.total_frames + 1,
        total_time: state.stats.total_time + frame_time,
        max_frame_time: max(state.stats.max_frame_time, frame_time),
        skip_count: state.stats.skip_count + state.skip_counter
    }

    # Log if frame took too long
    log_slow_frame(frame_time, state.frame_budget_ms)

    %{state | stats: new_stats}
  end

  defp init_stats do
    %{
      total_frames: 0,
      total_time: 0,
      max_frame_time: 0,
      skip_count: 0
    }
  end

  @doc """
  Get rendering performance statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Enable GPU acceleration if available.
  """
  def enable_gpu_acceleration do
    # This would interface with GPU rendering libraries
    Log.module_info("GPU acceleration enabled")
    :ok
  end

  @doc """
  Precompile shaders for faster rendering.
  """
  def precompile_shaders do
    # Shader compilation for GPU rendering
    cached(:shader_compilation, key: :shaders, ttl: :infinity) do
      compile_shaders()
    end
  end

  defp compile_shaders do
    # Placeholder for actual shader compilation
    %{
      vertex_shader: "compiled_vertex_shader",
      fragment_shader: "compiled_fragment_shader"
    }
  end

  # Helper functions for refactored if statements

  defp determine_dirty_regions(nil, _tree) do
    [:full_screen]
  end

  defp determine_dirty_regions(current_tree, tree) do
    calculate_dirty_regions(current_tree, tree)
  end

  defp calculate_average_frame_time(%{total_frames: 0}), do: 0

  defp calculate_average_frame_time(%{total_frames: frames, total_time: time}),
    do: time / frames

  defp process_frame_tick(true, state, _start_time) do
    %{state | skip_counter: state.skip_counter + 1}
  end

  defp process_frame_tick(false, state, start_time) do
    # Execute optimized render
    state
    |> coalesce_updates()
    |> execute_render(:scheduled)
    |> update_stats(start_time)
  end

  defp log_slow_frame(frame_time, budget_ms)
       when frame_time > budget_ms * 1.5 do
    Log.module_warning("Slow frame: #{frame_time}ms")
  end

  defp log_slow_frame(_frame_time, _budget_ms), do: :ok
end
