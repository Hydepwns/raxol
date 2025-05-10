defmodule Raxol.Core.Renderer.Views.PerformanceTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Renderer.Views.{Table, Chart}
  alias Raxol.Core.Renderer.View # View helpers might still be used
  alias Raxol.Core.Runtime.ComponentManager
  alias Raxol.Core.Renderer.Manager, as: RendererManagerMod # Alias for the module itself
  alias Raxol.Core.Events.Event # Added alias
  alias Raxol.Core.Events.Manager, as: EventManager # Added alias
  alias Raxol.Core.Renderer.Views.PerformanceTest.TestHostComponent
  alias Raxol.Test.PerformanceTestData # Add this alias
  alias Raxol.Test.PerformanceViewGenerators # Add this alias
  require Logger

  # Allow longer timeout for performance tests
  @moduletag timeout: 120_000

  # Thresholds (can be adjusted based on baseline performance)
  @threshold_initial_render 0.2 # seconds
  @threshold_resize 0.3 # seconds (placeholder, as resize is not fully tested yet)
  @threshold_memory_increase_bytes 50_000_000 # 50MB (very generous)
  @threshold_animation_frame_time 0.050 # 50ms (for 20 FPS target)
  @threshold_animation_max_frame_time 0.100 # 100ms
  @threshold_scroll_time 0.050 # 50ms
  @threshold_max_scroll_time 0.100 # 100ms
  @threshold_data_update_time 0.050 # 50ms
  @threshold_max_data_update_time 0.100 # 100ms
  @threshold_incremental_load_time 0.100 # 100ms
  @threshold_max_incremental_load_time 0.200 # 200ms
  @threshold_large_table_render 1.0 # 1 second
  @threshold_complex_layout_render 0.5 # 0.5 seconds
  @threshold_dynamic_update_complex 0.1 # 100ms

  # TODO: Rewrite tests to align with current Renderer.Manager GenServer API.
  # The original tests called deprecated/removed direct functions like
  # render_frame/1, resize/3, and set_root_view/2.
  # @moduledoc false
  # Skipping entire file due to outdated API usage - Will remove this gradually
  # @tag :skip # Will unskip test by test

  setup do
    start_supervised!(ComponentManager)
    start_supervised!(RendererManagerMod)

    # Initialize RendererManagerMod without root component assumptions
    :ok = RendererManagerMod.initialize([])

    # Optionally, mount a default TestHostComponent if many tests need a generic host
    # This component can be updated by tests to render arbitrary view maps.
    {:ok, host_component_id} = ComponentManager.mount(
      Raxol.Core.Renderer.Views.PerformanceTest.TestHostComponent,
      %{initial_view: View.box(%{})} # Start with an empty view
    )
    # Force an initial render of the host component to ensure it's in the system
    # and to clear any initial render queue items from its mount.
    _initial_render_time = measure_action_and_render_time(fn -> :ok end, fn -> host_component_id end)

    %{host_component_id: host_component_id}
  end

  # Generate large sample data
  @large_data Enum.map(1..1000, fn i ->
                %{
                  id: i,
                  name: "Product #{i}",
                  sales: Enum.map(1..12, fn _ -> :rand.uniform(1000) end),
                  trend: Enum.random([:up, :down, :stable])
                }
              end)

  # Helper to measure execution time (for synchronous operations)
  defp measure_sync(fun) do
    {time, result} = :timer.tc(fun)
    # Convert to seconds
    {result, time / 1_000_000}
  end

  # New helper to measure an action followed by a full render cycle time
  # action_fun: a 0-arity function that performs the action (e.g., mount, update)
  #             and returns the result of that action.
  defp measure_action_and_render_time(action_fun) do
    action_result = action_fun.()
    # Allow a brief moment for ComponentManager GenServer calls to complete
    # and add the component to the render queue before we trigger the render.
    Process.sleep(5) # Might be removable if all action_fun calls are sync and queue reliably.

    start_time = System.monotonic_time(:nanosecond)
    :ok = RendererManagerMod.render(self())

    receive do
      :render_cycle_complete ->
        end_time = System.monotonic_time(:nanosecond)
        duration_seconds = (end_time - start_time) / 1_000_000_000
        {action_result, duration_seconds}
    after
      # Increased timeout for potentially complex renders in performance tests
      15_000 ->
        Logger.error("Timeout waiting for :render_cycle_complete in performance test measure helper.")
        # Return a very large time to indicate failure and make assertions fail
        {action_result, 9999.999}
    end
  end

  # REFACTORED: This now measures the mount action and the subsequent first render.
  # The action_result (e.g. {:ok, component_id}) is returned along with the render time.
  defp mount_component_and_measure_initial_render(module, props) do
    action_fun = fn ->
      ComponentManager.mount(module, props)
    end

    {mount_result, render_time} = measure_action_and_render_time(action_fun)

    if elem(mount_result, 0) == :error do
      Logger.error("Failed to mount component in mount_component_and_measure_initial_render: #{inspect(mount_result)}")
    end
    # Returns { {:ok, component_id} | {:error, reason}, render_time }
    {mount_result, render_time}
  end

  # Old helper measure_component_mount_time removed as its functionality
  # is covered by measure_sync or mount_component_and_measure_initial_render.

  # Old helper initialize_module_as_root_and_measure_render removed as it was
  # based on outdated RendererManagerMod API and incorrect measurement.
  # Its replacement is mount_component_and_measure_initial_render.

  # Old helper update_host_view_and_measure_render removed as it was
  # based on outdated RendererManagerMod API (update_root_props) and incorrect measurement.
  # Its replacement is update_test_host_view_and_measure_render.

  # New helper for updating the TestHostComponent (mounted in setup) and measuring render
  defp update_test_host_view_and_measure_render(host_component_id, view_map) do
    action_fun = fn ->
      ComponentManager.update(host_component_id, {:set_view, view_map})
    end
    # The result of the action_fun (ComponentManager.update) is {:ok, new_component_state} or an error.
    # We can capture this if needed, or just return :ok if successful for the purpose of timing.
    get_action_result_fun = fn -> :ok end # Placeholder, can be enhanced

    {_action_ok, render_time} = measure_action_and_render_time(action_fun)
    render_time
  end

  describe "large table performance" do
    test "renders large table efficiently" do
      columns = [
        %{header: "ID", key: :id, width: 6, align: :right},
        %{header: "Name", key: :name, width: 20, align: :left},
        %{
          header: "Trend",
          key: :sales,
          width: 24,
          align: :left,
          format: fn sales ->
            Chart.new(
              type: :sparkline,
              series: [
                %{
                  name: "Sales",
                  data: sales,
                  color: :blue
                }
              ],
              width: 24
            )
          end
        }
      ]

      table_props = %{
        columns: columns,
        data: PerformanceTestData.large_data(),
        border: :single,
        striped: true
      }

      # Measure synchronous mounting time for the component itself
      {mount_result, mount_time_sync} = measure_sync(fn -> ComponentManager.mount(Table, table_props) end)
      assert elem(mount_result, 0) == :ok, "Table component mount failed: #{inspect(mount_result)}"
      # _table_component_id_sync = elem(mount_result, 1) # If needed

      assert mount_time_sync < 0.1, "Table mounting (synchronous part) should be fast: got #{mount_time_sync}s"

      # Now, mount a new instance and measure its first full render time.
      # This ensures we are measuring the render of a freshly mounted component.
      {render_mount_result, first_render_time} = mount_component_and_measure_initial_render(Table, table_props)
      assert elem(render_mount_result, 0) == :ok, "Table component mount for render measurement failed: #{inspect(render_mount_result)}"
      # {:ok, _table_component_id_for_render} = render_mount_result

      assert first_render_time < @threshold_large_table_render, "Large table initial render time #{first_render_time}s exceeded threshold #{@threshold_large_table_render}s"
    end

    test "handles dynamic updates efficiently" do
      initial_table_props = %{
        columns: [
          %{header: "ID", key: :id, width: 6, align: :right},
          %{header: "Name", key: :name, width: 20, align: :left}
        ],
        data: PerformanceTestData.large_data(), # Uses the full 1000 rows
        border: :single,
        striped: true
      }

      # Mount the Table component and measure its first render
      {{:ok, table_component_id}, initial_time} = mount_component_and_measure_initial_render(Table, initial_table_props)

      # Define new props for the update
      updated_table_props = %{
        initial_table_props | # Start with old props
        border: :double, # Change border
        striped: false # Change striped
      }

      # The message for Table.update/2
      update_message = {:set_props, updated_table_props}

      # Perform the update action and measure the subsequent render time
      action_fun = fn ->
        ComponentManager.update(table_component_id, update_message)
      end

      {update_result, update_time} = measure_action_and_render_time(action_fun)

      # Assert that the component update itself was successful
      assert elem(update_result, 0) == :ok, "Table component update failed: #{inspect(update_result)}"

      Logger.info(
        "Table dynamic update test: initial_render=#{initial_time}s, update_render=#{update_time}s"
      )

      # Assertions on render times
      assert initial_time < @threshold_large_table_render
      assert update_time < @threshold_dynamic_update_complex
    end
  end

  describe "complex layout performance" do
    test "handles deeply nested views efficiently", %{host_component_id: host_component_id} do
      # Create a deeply nested structure with alternating flex/grid containers
      {view_map, creation_time} =
        measure_sync(fn ->
          PerformanceViewGenerators.create_nested_structure(10) # This helper returns a view map
        end)

      # Assert view creation time (this was already there)
      assert creation_time < 0.1, "View map creation for deep nesting too slow"

      # Now, render this view_map using the TestHostComponent (default root) and measure render time
      render_time = update_test_host_view_and_measure_render(host_component_id, view_map)

      # Assert render time (new assertion, might need a new threshold)
      # Using @threshold_initial_render as a placeholder, adjust if needed
      assert render_time < @threshold_initial_render, "Deeply nested view render time exceeded threshold"

      # Verify we have many nested views
      assert PerformanceViewGenerators.count_nested_views(view_map) > 100
    end

    test "manages multiple charts efficiently", %{host_component_id: host_component_id} do
      # Create a grid of charts
      # 4x4 grid
      charts_data = # Renamed from 'charts' to avoid confusion with rendered view elements
        for i <- 1..16 do
          Chart.new(
            type: if(rem(i, 2) == 0, do: :bar, else: :line),
            series: [
              %{
                name: "Series #{i}",
                data:
                  Enum.take_random(PerformanceTestData.large_data(), 50)
                  |> Enum.map(&List.first(&1.sales)),
                color: :blue
              }
            ],
            width: 30,
            height: 10,
            show_axes: true,
            show_legend: true
          )
        end

      # Measure the synchronous creation of the view map (the data structure for the grid)
      {view_map, creation_time} = measure_sync(fn -> View.grid [columns: 4], do: charts_data end)

      assert creation_time < 0.2, "Chart grid view map creation time should be less than 0.2s, got #{creation_time}s"
      assert length(view_map.children) == 16

      # Now, measure the time to render this grid of charts using the TestHostComponent
      render_time = update_test_host_view_and_measure_render(host_component_id, view_map)

      Logger.info("Created grid view with #{length(charts_data)} charts. Creation_time: #{creation_time}s, Render_time: #{render_time}s")
      # Add a threshold for rendering multiple charts, e.g., @threshold_complex_layout_render
      assert render_time < @threshold_complex_layout_render, "Chart grid render time #{render_time}s exceeded threshold #{@threshold_complex_layout_render}s"
    end

    test "handles dynamic resizing efficiently", %{host_component_id: host_component_id} do
      # Create a complex layout view map
      view_map = PerformanceViewGenerators.create_configurable_test_layout(
        include_top_header: true,
        table_rows: 100,
        table_panel_width: 30, # From old create_complex_layout
        num_charts: 4,
        chart_grid_columns: 2, # 2x2 grid for 4 charts
        chart_data_points: 20
        # Default table columns: ID, Name
      )

      # Update host view and measure initial render
      initial_time = update_test_host_view_and_measure_render(host_component_id, view_map)

      # Define new dimensions for resize
      new_width = 160  # Example new width
      new_height = 60 # Example new height
      resize_event_data = %{action: :resize, width: new_width, height: new_height}
      resize_event = Event.new(:window, resize_event_data)

      # Dispatch the resize event.
      # RendererManagerMod is subscribed to :window events and will handle this.
      :ok = EventManager.dispatch(resize_event)

      # Perform a "sync-up" render: ensure the resize event has likely been processed by RendererManagerMod
      # by waiting for one full render cycle to complete before measuring the target render.
      :ok = RendererManagerMod.render(self())
      receive do
        :render_cycle_complete ->
          :ok # Successfully synced
      after
        15_000 -> # Use the same timeout as measure_action_and_render_time for consistency
          flunk("Timeout waiting for sync-up render after resize dispatch in 'handles dynamic resizing efficiently' test.")
      end

      # Now, measure the next render operation, which should reflect the new dimensions.
      # The action_fun is :ok because the primary action (resize) has already been dispatched
      # and given a chance to be processed.
      {_action_result, post_resize_render_time} = measure_action_and_render_time(fn -> :ok end)

      # Assertions
      assert initial_time < @threshold_initial_render
      assert post_resize_render_time < @threshold_resize # Repurpose @threshold_resize

      Logger.info(
        "Dynamic resizing test: initial_render=#{initial_time}s, post_resize_render=#{post_resize_render_time}s"
      )
    end

    test "maintains performance with z-index sorting", %{host_component_id: host_component_id} do
      # Create overlapping views with various z-indices
      views_data = # Renamed from 'views' to avoid confusion
        for i <- 1..100 do
          View.box(
            position: {rem(i, 10), rem(i, 5)},
            z_index: rem(i, 10),
            size: {10, 5},
            children: [
              View.text("Layer #{i}")
            ]
          )
        end

      # Measure synchronous creation of the view map
      {view_map, creation_time} =
        measure_sync(fn ->
          View.box(children: views_data)
        end)

      assert creation_time < 0.1, "Z-index view map creation time should be < 0.1s, got #{creation_time}s"
      assert length(view_map.children) == 100

      # Now, measure the time to render this view using the TestHostComponent
      render_time = update_test_host_view_and_measure_render(host_component_id, view_map)

      Logger.info("Z-index view: Creation_time: #{creation_time}s, Render_time: #{render_time}s")
      # Add a threshold for rendering this, could be @threshold_initial_render or a new one.
      assert render_time < @threshold_initial_render, "Z-index view render time #{render_time}s exceeded threshold #{@threshold_initial_render}s"
    end
  end

  describe "memory usage" do
    test "maintains reasonable memory usage with large layouts" do
      # Create a large complex layout view map
      view_map = PerformanceViewGenerators.create_configurable_test_layout(
        table_rows: 1000, # Uses full @large_data by default if table_data_source is not changed
        table_panel_width: 40, # From old create_large_complex_layout
        num_charts: 9,
        chart_grid_columns: 3, # 3x3 grid for 9 charts
        chart_data_points: 50,
        table_columns: [
          %{header: "ID", key: :id, width: 6, align: :right},
          %{header: "Name", key: :name, width: 20, align: :left},
          %{header: "Trend", key: :sales, width: 12, align: :left, format: :sparkline} # Special marker
        ]
      )

      # Update host view to render the complex layout
      # We measure render time as part of this, but it's not the primary focus of *this* test.
      # The main goal is to have the complex view in memory.
      _initial_render_time = update_test_host_view_and_measure_render(host_component_id, view_map)

      # Initial render
      # RendererManagerMod.render() # This is now done by update_test_host_view_and_measure_render

      # Check memory usage (conceptual, actual check might need OS tools)
      # For now, we'll rely on the test not crashing due to OOM.
      # In a real scenario, you might use :erlang.memory/0 or external tools.
      initial_memory = :erlang.memory(:total)

      # Render multiple frames, ensuring each completes
      for i <- 1..10 do
        :ok = RendererManagerMod.render(self())
        receive do
          :render_cycle_complete ->
            :ok # Frame #{i} rendered
        after
          15_000 -> # Consistent timeout
            flunk("Timeout waiting for render_cycle_complete in memory test loop, frame #{i}")
        end
      end

      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory

      Logger.info(
        "Memory usage test: initial_memory=#{initial_memory}, final_memory=#{final_memory}, increase=#{memory_increase}"
      )

      # Assert that memory increase is within a reasonable limit
      # This is a very rough check and highly dependent on the system and layout complexity.
      assert memory_increase < @threshold_memory_increase_bytes
    end
  end

  describe "animation performance" do
    # Common setup for animation tests
    setup do
      # Manager is already started via application supervision or outer describe
      # {:ok, _manager} = RendererManagerMod.start_link([])
      on_exit(fn ->
        # Ensure cleanup, though GenServer.stop might be too abrupt if it\'s a named process
        # GenServer.stop(manager)
        :ok
      end)

      # Return the manager PID for use in tests
      %{component_manager: ComponentManager} # Assuming ComponentManager is globally available or passed
    end

    test "handles smooth progress bar animation", %{host_component_id: host_component_id} do
      frames = PerformanceViewGenerators.create_progress_bar_frames(50) # List of view maps

      frame_render_times =
        Enum.map(frames, fn frame_view_map ->
          update_test_host_view_and_measure_render(host_component_id, frame_view_map)
        end)

      avg_frame_time = Enum.sum(frame_render_times) / Enum.count(frame_render_times)
      max_frame_time = Enum.max(frame_render_times)

      Logger.info(
        "Progress bar animation: avg_frame_time=#{avg_frame_time}ms, max_frame_time=#{max_frame_time}ms"
      )

      assert avg_frame_time < @threshold_animation_frame_time
      assert max_frame_time < @threshold_animation_max_frame_time
    end

    test "handles spinner animation efficiently", %{host_component_id: host_component_id} do
      frames = PerformanceViewGenerators.create_spinner_frames(50) # List of view maps
      frame_render_times =
        Enum.map(frames, fn frame_view_map ->
          update_test_host_view_and_measure_render(host_component_id, frame_view_map)
        end)

      avg_frame_time = Enum.sum(frame_render_times) / Enum.count(frame_render_times)
      max_frame_time = Enum.max(frame_render_times)

      Logger.info(
        "Spinner animation: avg_frame_time=#{avg_frame_time}ms, max_frame_time=#{max_frame_time}ms"
      )
      assert avg_frame_time < @threshold_animation_frame_time
      assert max_frame_time < @threshold_animation_max_frame_time
    end

    test "handles chart animation smoothly", %{host_component_id: host_component_id} do
      frames = PerformanceViewGenerators.create_chart_animation_frames(50) # List of view maps
      frame_render_times =
        Enum.map(frames, fn frame_view_map ->
          update_test_host_view_and_measure_render(host_component_id, frame_view_map)
        end)

      avg_frame_time = Enum.sum(frame_render_times) / Enum.count(frame_render_times)
      max_frame_time = Enum.max(frame_render_times)

      Logger.info(
        "Chart animation: avg_frame_time=#{avg_frame_time}ms, max_frame_time=#{max_frame_time}ms"
      )
      assert avg_frame_time < @threshold_animation_frame_time
      assert max_frame_time < @threshold_animation_max_frame_time
    end
  end

  describe "scrolling performance" do
    # Common setup for scrolling tests
    setup %{host_component_id: host_component_id} do
      # RendererManagerMod and ComponentManager are started in the top-level setup.
      # TestHostComponent is the default root for RendererManagerMod.
      # We no longer need to pass component_manager from here as tests will use ComponentManager module directly if needed.
      %{host_component_id: host_component_id} # Pass host_component_id from top-level setup
    end

    test "handles smooth vertical scrolling", %{host_component_id: host_component_id} do
      # This test simulates scrolling by creating a Table view and then conceptually updating a scroll offset.
      # The current `update_test_host_view_and_measure_render` works by re-setting the *entire* view.
      # For a more realistic scroll test of a *component*, the Table component itself would need
      # to handle a scroll message via ComponentManager.update, and then RendererManagerMod.render()
      # would render the updated component state. This test needs significant redesign for that.

      # For now, we adapt it to measure rendering different views that *look* like scrolled states.
      # However, this doesn't test component-internal scroll logic or partial re-renders.

      table_props_for_view = %{
        columns: PerformanceTestData.generate_columns(5),
        data: PerformanceTestData.generate_data(100, 5), # 100 rows
        border: :single
      }
      # Initial render of the full table (or rather, its view map)
      initial_render_time = update_test_host_view_and_measure_render(host_component_id, Table.new(table_props_for_view))
      Logger.info("Vertical scrolling: initial full table render_time=#{initial_render_time}s")

      total_rows = 100
      viewport_height = 20
      scroll_steps = 20 # Number of scroll steps to simulate

      scroll_render_times =
        for i <- 1..scroll_steps do
          # Simulate a new view for each scrolled state
          # This is NOT testing Table component's internal scrolling, but rendering different data sets.
          scrolled_data = Enum.slice(table_props_for_view.data, i, viewport_height)
          scrolled_table_view = Table.new(Map.put(table_props_for_view, :data, scrolled_data))
          update_test_host_view_and_measure_render(host_component_id, scrolled_table_view)
        end

      avg_scroll_time = Enum.sum(scroll_render_times) / Enum.count(scroll_render_times)
      max_scroll_time = Enum.max(scroll_render_times)

      Logger.info(
        "Vertical scrolling (simulated by view replacement): avg_scroll_time=#{avg_scroll_time}s, max_scroll_time=#{max_scroll_time}s"
      )
      assert avg_scroll_time < @threshold_scroll_time
      assert max_scroll_time < @threshold_max_scroll_time
    end

    test "handles horizontal scrolling efficiently", %{host_component_id: host_component_id} do
      # Similar caveats as vertical scrolling test.
      table_props_for_view = %{
        columns: PerformanceTestData.generate_columns(20), # Many columns
        data: PerformanceTestData.generate_data(10, 20), # 10 rows
        border: :single
      }
      initial_render_time = update_test_host_view_and_measure_render(host_component_id, Table.new(table_props_for_view))
      Logger.info("Horizontal scrolling: initial full table render_time=#{initial_render_time}s")

      # Conceptual total width and viewport width
      # total_columns = 20
      # viewport_columns = 5 # Assume we can see 5 columns at a time
      scroll_steps = 10

      scroll_render_times =
        for i <- 1..scroll_steps do
          # Simulate new view for scrolled state by changing which columns are shown
          scrolled_columns = Enum.slice(table_props_for_view.columns, i, 5) # Show 5 columns at a time
          scrolled_table_view = Table.new(Map.put(table_props_for_view, :columns, scrolled_columns))
          update_test_host_view_and_measure_render(host_component_id, scrolled_table_view)
        end

      avg_scroll_time = Enum.sum(scroll_render_times) / Enum.count(scroll_render_times)
      max_scroll_time = Enum.max(scroll_render_times)

      Logger.info(
        "Horizontal scrolling (simulated by view replacement): avg_scroll_time=#{avg_scroll_time}s, max_scroll_time=#{max_scroll_time}s"
      )
      assert avg_scroll_time < @threshold_scroll_time
      assert max_scroll_time < @threshold_max_scroll_time
    end
  end

  describe "dynamic content performance" do
    setup %{host_component_id: host_component_id} do
      # RendererManagerMod and ComponentManager are started in the top-level setup.
      # TestHostComponent is the default root for RendererManagerMod.
      %{host_component_id: host_component_id} # Pass host_component_id from top-level setup
    end

    test "handles real-time data updates efficiently", %{host_component_id: host_component_id} do
      initial_data = PerformanceTestData.generate_data(50, 5)
      columns = PerformanceTestData.generate_columns(5)

      # Initial view render
      initial_view_map = Table.new(columns: columns, data: initial_data, border: :single)
      _initial_render_time = update_test_host_view_and_measure_render(host_component_id, initial_view_map)

      update_render_times =
        for i <- 1..20 do
          new_data = PerformanceViewGenerators.update_some_data(initial_data, i)
          updated_view_map = Table.new(columns: columns, data: new_data, border: :single)
          update_test_host_view_and_measure_render(host_component_id, updated_view_map)
        end

      avg_update_time = Enum.sum(update_render_times) / Enum.count(update_render_times)
      max_update_time = Enum.max(update_render_times)

      Logger.info(
        "Real-time data updates (simulated by view replacement): avg_update_time=#{avg_update_time}ms, max_update_time=#{max_update_time}ms"
      )
      assert avg_update_time < @threshold_data_update_time
      assert max_update_time < @threshold_max_data_update_time
    end

    test "handles incremental content loading", %{host_component_id: host_component_id} do
      columns = PerformanceTestData.generate_columns(10)
      initial_data = PerformanceTestData.generate_data(10, 10) # Start with 10 rows

      # Initial view render
      initial_view_map = Table.new(columns: columns, data: initial_data, border: :single)
      _initial_render_time = update_test_host_view_and_measure_render(host_component_id, initial_view_map)

      chunk_size = 50
      current_data = initial_data

      load_render_times =
        for chunk_start <- 0..950//chunk_size do # Load up to 1000 rows in chunks
          new_rows = PerformanceTestData.generate_data(chunk_size, 10, chunk_start + length(initial_data)) # Adjust start_offset
          current_data = current_data ++ new_rows
          updated_view_map = Table.new(columns: columns, data: current_data, border: :single)
          update_test_host_view_and_measure_render(host_component_id, updated_view_map)
        end

      avg_load_time = Enum.sum(load_render_times) / Enum.count(load_render_times)
      max_load_time = Enum.max(load_render_times)

      Logger.info(
        "Incremental content loading (simulated by view replacement): avg_load_time=#{avg_load_time}ms, max_load_time=#{max_load_time}ms"
      )
      assert avg_load_time < @threshold_incremental_load_time
      assert max_load_time < @threshold_max_incremental_load_time
    end
  end
end
