defmodule Raxol.DevTools.DebugInspector do
  @moduledoc """
  Comprehensive debugging and inspection tools for Raxol applications.

  This module provides runtime debugging capabilities including:
  - Component tree inspection and visualization
  - State monitoring and time-travel debugging
  - Performance profiling and bottleneck detection
  - Event tracing and logging
  - Memory usage analysis
  - Render cycle debugging
  - Interactive REPL integration

  ## Usage

      # Start the debug inspector
      DebugInspector.start()
      
      # Inspect component tree
      DebugInspector.inspect_component_tree()
      
      # Profile component performance
      DebugInspector.profile_component(MyComponent, props)
      
      # Monitor state changes
      DebugInspector.watch_state([:user, :current])
      
      # Debug render cycles
      DebugInspector.trace_renders(MyComponent)
  """

  use GenServer
  alias Raxol.UI.State.Store, as: Store
  require Logger

  defmodule InspectorState do
    defstruct [
      :component_tree,
      :state_watchers,
      :performance_monitors,
      :event_tracers,
      :memory_snapshots,
      :render_traces,
      :breakpoints,
      :profiling_active,
      :ui_overlay_active
    ]

    def new do
      %__MODULE__{
        component_tree: %{},
        state_watchers: %{},
        performance_monitors: %{},
        event_tracers: [],
        memory_snapshots: [],
        render_traces: %{},
        breakpoints: MapSet.new(),
        profiling_active: false,
        ui_overlay_active: false
      }
    end
  end

  defmodule ComponentInfo do
    defstruct [
      :module,
      :props,
      :state,
      :children,
      :parent,
      :render_count,
      :last_render_time,
      :total_render_time,
      :memory_usage,
      :created_at,
      :updated_at
    ]
  end

  defmodule PerformanceProfile do
    defstruct [
      :component,
      :render_times,
      :average_render_time,
      :slowest_render,
      :total_renders,
      :memory_deltas,
      :bottlenecks
    ]
  end

  ## Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts the debug inspector with UI overlay.
  """
  def start do
    result =
      case GenServer.whereis(__MODULE__) do
        nil -> start_link()
        _pid -> :already_started
      end

    enable_ui_overlay()
    result
  end

  @doc """
  Stops the debug inspector.
  """
  def stop do
    disable_ui_overlay()
    GenServer.stop(__MODULE__)
  end

  @doc """
  Enables/disables the visual debug overlay.
  """
  def enable_ui_overlay(enabled \\ true) do
    GenServer.call(__MODULE__, {:set_ui_overlay, enabled})
  end

  def disable_ui_overlay do
    enable_ui_overlay(false)
  end

  @doc """
  Registers a component for debugging and inspection.
  """
  def register_component(component_id, module, props, opts \\ []) do
    GenServer.call(
      __MODULE__,
      {:register_component, component_id, module, props, opts}
    )
  end

  @doc """
  Unregisters a component from debugging.
  """
  def unregister_component(component_id) do
    GenServer.call(__MODULE__, {:unregister_component, component_id})
  end

  @doc """
  Gets the current component tree structure.
  """
  def inspect_component_tree do
    GenServer.call(__MODULE__, :get_component_tree)
  end

  @doc """
  Gets detailed information about a specific component.
  """
  def inspect_component(component_id) do
    GenServer.call(__MODULE__, {:inspect_component, component_id})
  end

  @doc """
  Starts profiling a specific component.
  """
  def profile_component(component_id, duration_ms \\ 10000) do
    GenServer.call(__MODULE__, {:profile_component, component_id, duration_ms})
  end

  @doc """
  Gets performance profile for a component.
  """
  def get_performance_profile(component_id) do
    GenServer.call(__MODULE__, {:get_performance_profile, component_id})
  end

  @doc """
  Watches state changes at a specific path.
  """
  def watch_state(path, opts \\ []) do
    watcher_id = System.unique_integer([:positive, :monotonic])
    GenServer.call(__MODULE__, {:watch_state, watcher_id, path, opts})
    watcher_id
  end

  @doc """
  Stops watching state changes.
  """
  def unwatch_state(watcher_id) do
    GenServer.call(__MODULE__, {:unwatch_state, watcher_id})
  end

  @doc """
  Sets a breakpoint in component render cycle.
  """
  def set_breakpoint(component_id, condition \\ :always) do
    GenServer.call(__MODULE__, {:set_breakpoint, component_id, condition})
  end

  @doc """
  Removes a breakpoint.
  """
  def remove_breakpoint(component_id) do
    GenServer.call(__MODULE__, {:remove_breakpoint, component_id})
  end

  @doc """
  Traces render cycles for debugging.
  """
  def trace_renders(component_id, enabled \\ true) do
    GenServer.call(__MODULE__, {:trace_renders, component_id, enabled})
  end

  @doc """
  Takes a memory snapshot for analysis.
  """
  def take_memory_snapshot(label \\ nil) do
    GenServer.call(__MODULE__, {:memory_snapshot, label})
  end

  @doc """
  Generates a debug report with all collected data.
  """
  def generate_debug_report do
    GenServer.call(__MODULE__, :generate_report)
  end

  @doc """
  Gets current debug statistics.
  """
  def get_debug_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  ## GenServer Implementation

  @impl GenServer
  def init(_opts) do
    state = InspectorState.new()
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:set_ui_overlay, enabled}, _from, state) do
    new_state = %{state | ui_overlay_active: enabled}

    case enabled do
      true -> Logger.info("Debug UI overlay enabled")
      false -> Logger.info("Debug UI overlay disabled")
    end

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(
        {:register_component, component_id, module, props, opts},
        _from,
        state
      ) do
    parent_id = Keyword.get(opts, :parent)

    component_info = %ComponentInfo{
      module: module,
      props: props,
      state: Keyword.get(opts, :state),
      children: [],
      parent: parent_id,
      render_count: 0,
      last_render_time: 0,
      total_render_time: 0,
      memory_usage: get_current_memory(),
      created_at: System.monotonic_time(:millisecond),
      updated_at: System.monotonic_time(:millisecond)
    }

    new_tree = Map.put(state.component_tree, component_id, component_info)

    # Update parent's children list
    updated_tree =
      case parent_id do
        nil ->
          new_tree

        parent_id ->
          case Map.get(new_tree, parent_id) do
            nil ->
              new_tree

            parent_info ->
              updated_parent = %{
                parent_info
                | children: [component_id | parent_info.children]
              }

              Map.put(new_tree, parent_id, updated_parent)
          end
      end

    new_state = %{state | component_tree: updated_tree}

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:unregister_component, component_id}, _from, state) do
    new_tree = Map.delete(state.component_tree, component_id)

    # Remove from parent's children
    updated_tree =
      case Map.get(state.component_tree, component_id) do
        %{parent: parent_id} when parent_id != nil ->
          case Map.get(new_tree, parent_id) do
            nil ->
              new_tree

            parent_info ->
              updated_children = List.delete(parent_info.children, component_id)
              updated_parent = %{parent_info | children: updated_children}
              Map.put(new_tree, parent_id, updated_parent)
          end

        _ ->
          new_tree
      end

    new_state = %{state | component_tree: updated_tree}

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_component_tree, _from, state) do
    tree_structure = build_tree_structure(state.component_tree)
    {:reply, tree_structure, state}
  end

  @impl GenServer
  def handle_call({:inspect_component, component_id}, _from, state) do
    component_info = Map.get(state.component_tree, component_id)
    {:reply, component_info, state}
  end

  @impl GenServer
  def handle_call({:profile_component, component_id, duration_ms}, _from, state) do
    # Start profiling
    profile = %PerformanceProfile{
      component: component_id,
      render_times: [],
      average_render_time: 0,
      slowest_render: 0,
      total_renders: 0,
      memory_deltas: [],
      bottlenecks: []
    }

    new_monitors = Map.put(state.performance_monitors, component_id, profile)

    new_state = %{
      state
      | performance_monitors: new_monitors,
        profiling_active: true
    }

    # Schedule profiling stop
    Process.send_after(self(), {:stop_profiling, component_id}, duration_ms)

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:get_performance_profile, component_id}, _from, state) do
    profile = Map.get(state.performance_monitors, component_id)
    {:reply, profile, state}
  end

  @impl GenServer
  def handle_call({:watch_state, watcher_id, path, opts}, _from, state) do
    callback = fn new_value, old_value ->
      send(self(), {:state_change, watcher_id, path, new_value, old_value})
    end

    # Subscribe to store changes
    unsubscribe_fn =
      Store.subscribe(path, fn new_value ->
        old_value = get_previous_state_value(path)
        callback.(new_value, old_value)
      end)

    watcher_info = %{
      path: path,
      options: opts,
      unsubscribe_fn: unsubscribe_fn,
      created_at: System.monotonic_time(:millisecond)
    }

    new_watchers = Map.put(state.state_watchers, watcher_id, watcher_info)
    new_state = %{state | state_watchers: new_watchers}

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:unwatch_state, watcher_id}, _from, state) do
    case Map.get(state.state_watchers, watcher_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      watcher_info ->
        # Unsubscribe
        watcher_info.unsubscribe_fn.()

        new_watchers = Map.delete(state.state_watchers, watcher_id)
        new_state = %{state | state_watchers: new_watchers}

        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:set_breakpoint, component_id, condition}, _from, state) do
    breakpoint = {component_id, condition}
    new_breakpoints = MapSet.put(state.breakpoints, breakpoint)
    new_state = %{state | breakpoints: new_breakpoints}

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:remove_breakpoint, component_id}, _from, state) do
    new_breakpoints =
      Enum.reduce(state.breakpoints, MapSet.new(), fn {comp_id, _condition} = bp,
                                                      acc ->
        case comp_id == component_id do
          true -> acc
          false -> MapSet.put(acc, bp)
        end
      end)

    new_state = %{state | breakpoints: new_breakpoints}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:trace_renders, component_id, enabled}, _from, state) do
    new_traces =
      case enabled do
        true -> Map.put(state.render_traces, component_id, [])
        false -> Map.delete(state.render_traces, component_id)
      end

    new_state = %{state | render_traces: new_traces}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:memory_snapshot, label}, _from, state) do
    snapshot = %{
      label: label || "snapshot_#{length(state.memory_snapshots) + 1}",
      timestamp: System.monotonic_time(:millisecond),
      memory_info: get_memory_info(),
      component_count: map_size(state.component_tree),
      active_watchers: map_size(state.state_watchers)
    }

    new_snapshots = [snapshot | state.memory_snapshots]
    new_state = %{state | memory_snapshots: new_snapshots}

    {:reply, snapshot, new_state}
  end

  @impl GenServer
  def handle_call(:generate_report, _from, state) do
    report = generate_comprehensive_report(state)
    {:reply, report, state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats = %{
      registered_components: map_size(state.component_tree),
      active_watchers: map_size(state.state_watchers),
      performance_monitors: map_size(state.performance_monitors),
      memory_snapshots: length(state.memory_snapshots),
      breakpoints_active: MapSet.size(state.breakpoints),
      profiling_active: state.profiling_active,
      ui_overlay_active: state.ui_overlay_active
    }

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_info({:stop_profiling, component_id}, state) do
    case Map.get(state.performance_monitors, component_id) do
      nil ->
        {:noreply, state}

      profile ->
        # Finalize profile
        finalized_profile = finalize_performance_profile(profile)

        new_monitors =
          Map.put(state.performance_monitors, component_id, finalized_profile)

        Logger.info(
          "Performance profiling completed for component #{component_id}"
        )

        Logger.info(
          "Average render time: #{finalized_profile.average_render_time}ms"
        )

        new_state = %{state | performance_monitors: new_monitors}
        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info(
        {:state_change, watcher_id, path, new_value, old_value},
        state
      ) do
    case Map.get(state.state_watchers, watcher_id) do
      nil ->
        {:noreply, state}

      _watcher_info ->
        Logger.debug(
          "State change detected at #{inspect(path)}: #{inspect(old_value)} -> #{inspect(new_value)}"
        )

        # If UI overlay is active, could trigger visual updates
        case state.ui_overlay_active do
          true -> broadcast_state_change(path, new_value, old_value)
          false -> :ok
        end

        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(
        {:component_render, component_id, render_time, memory_delta},
        state
      ) do
    # Update component info
    case Map.get(state.component_tree, component_id) do
      nil ->
        {:noreply, state}

      component_info ->
        updated_info = %{
          component_info
          | render_count: component_info.render_count + 1,
            last_render_time: render_time,
            total_render_time: component_info.total_render_time + render_time,
            updated_at: System.monotonic_time(:millisecond)
        }

        new_tree = Map.put(state.component_tree, component_id, updated_info)

        # Update performance monitor if active
        new_monitors =
          case Map.get(state.performance_monitors, component_id) do
            nil ->
              state.performance_monitors

            profile ->
              update_performance_profile(
                profile,
                render_time,
                memory_delta,
                state.performance_monitors,
                component_id
              )
          end

        # Update render traces if active
        new_traces =
          case Map.get(state.render_traces, component_id) do
            nil ->
              state.render_traces

            trace_list ->
              new_trace = %{
                timestamp: System.monotonic_time(:millisecond),
                render_time: render_time,
                memory_delta: memory_delta
              }

              # Keep last 100
              updated_traces = [new_trace | Enum.take(trace_list, 99)]
              Map.put(state.render_traces, component_id, updated_traces)
          end

        new_state = %{
          state
          | component_tree: new_tree,
            performance_monitors: new_monitors,
            render_traces: new_traces
        }

        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Private Implementation

  defp build_tree_structure(component_tree) do
    # Find root components (those without parents)
    roots =
      component_tree
      |> Enum.filter(fn {_id, info} -> info.parent == nil end)
      |> Enum.map(fn {id, info} ->
        build_component_node(id, info, component_tree)
      end)

    %{
      type: :debug_tree,
      roots: roots,
      total_components: map_size(component_tree)
    }
  end

  defp build_component_node(component_id, component_info, component_tree) do
    children =
      component_info.children
      |> Enum.map(fn child_id ->
        case Map.get(component_tree, child_id) do
          nil ->
            nil

          child_info ->
            build_component_node(child_id, child_info, component_tree)
        end
      end)
      |> Enum.filter(&(&1 != nil))

    %{
      id: component_id,
      module: component_info.module,
      render_count: component_info.render_count,
      last_render_time: component_info.last_render_time,
      children: children
    }
  end

  defp get_current_memory do
    :erlang.memory(:total)
  end

  defp get_memory_info do
    memory = :erlang.memory()

    %{
      total: memory[:total],
      processes: memory[:processes],
      system: memory[:system],
      atom: memory[:atom],
      binary: memory[:binary],
      ets: memory[:ets]
    }
  end

  defp get_previous_state_value(_path) do
    # This would integrate with store history
    nil
  end

  defp update_performance_profile(
         profile,
         render_time,
         memory_delta,
         monitors,
         component_id
       ) do
    new_render_times = [render_time | Enum.take(profile.render_times, 99)]
    new_memory_deltas = [memory_delta | Enum.take(profile.memory_deltas, 99)]

    updated_profile = %{
      profile
      | render_times: new_render_times,
        memory_deltas: new_memory_deltas,
        total_renders: profile.total_renders + 1,
        average_render_time:
          Enum.sum(new_render_times) / length(new_render_times),
        slowest_render: max(profile.slowest_render, render_time)
    }

    Map.put(monitors, component_id, updated_profile)
  end

  defp finalize_performance_profile(profile) do
    # Analyze for bottlenecks
    bottlenecks = detect_performance_bottlenecks(profile)

    %{profile | bottlenecks: bottlenecks}
  end

  defp detect_performance_bottlenecks(profile) do
    bottlenecks = []

    # Slow average render time
    # > 60fps
    bottlenecks =
      case profile.average_render_time > 16 do
        true ->
          [
            "Slow average render time: #{Float.round(profile.average_render_time, 2)}ms"
            | bottlenecks
          ]
        false ->
          bottlenecks
      end

    # Inconsistent render times
    case length(profile.render_times) > 10 do
      true ->
        variance = calculate_variance(profile.render_times)
        # High variance
        case variance > 100 do
          true ->
            [
              "Inconsistent render times (variance: #{Float.round(variance, 2)})"
              | bottlenecks
            ]

          false ->
            bottlenecks
        end

      false ->
        bottlenecks
    end
  end

  defp calculate_variance(numbers) do
    mean = Enum.sum(numbers) / length(numbers)

    sum_squared_diffs =
      Enum.reduce(numbers, 0, fn x, acc ->
        acc + :math.pow(x - mean, 2)
      end)

    sum_squared_diffs / length(numbers)
  end

  defp broadcast_state_change(_path, _new_value, _old_value) do
    # This would broadcast to UI overlay components
    :ok
  end

  defp generate_comprehensive_report(state) do
    %{
      generated_at: System.monotonic_time(:millisecond),
      summary: %{
        total_components: map_size(state.component_tree),
        active_watchers: map_size(state.state_watchers),
        performance_monitors: map_size(state.performance_monitors),
        memory_snapshots: length(state.memory_snapshots)
      },
      component_tree: build_tree_structure(state.component_tree),
      performance_profiles: state.performance_monitors,
      memory_analysis: analyze_memory_snapshots(state.memory_snapshots),
      recommendations: generate_recommendations(state)
    }
  end

  defp analyze_memory_snapshots(snapshots) do
    case length(snapshots) < 2 do
      true ->
        %{status: "Not enough snapshots for analysis"}

      false ->
        [latest | rest] = snapshots
        previous = List.first(rest)

        memory_trend = latest.memory_info.total - previous.memory_info.total

        %{
          latest_snapshot: latest,
          memory_trend: memory_trend,
          trend_analysis:
            case memory_trend > 0 do
              true -> "increasing"
              false -> "stable_or_decreasing"
            end
        }
    end
  end

  defp generate_recommendations(state) do
    recommendations = []

    # Check for components with high render counts
    high_render_components =
      state.component_tree
      |> Enum.filter(fn {_id, info} -> info.render_count > 100 end)
      |> Enum.map(fn {id, info} -> {id, info.render_count} end)

    recommendations =
      case Enum.empty?(high_render_components) do
        false ->
          [
            "Consider optimizing components with high render counts: #{inspect(high_render_components)}"
            | recommendations
          ]

        true ->
          recommendations
      end

    # Check for slow components
    slow_components =
      state.performance_monitors
      |> Enum.filter(fn {_id, profile} -> profile.average_render_time > 16 end)
      |> Enum.map(fn {id, profile} -> {id, profile.average_render_time} end)

    recommendations =
      case Enum.empty?(slow_components) do
        false ->
          [
            "Optimize slow rendering components: #{inspect(slow_components)}"
            | recommendations
          ]

        true ->
          recommendations
      end

    case Enum.empty?(recommendations) do
      true -> ["No performance issues detected"]
      false -> recommendations
    end
  end

  ## Public Debugging Helpers

  @doc """
  Creates a visual debug overlay component.
  """
  def debug_overlay do
    stats = get_debug_stats()

    %{
      type: :column,
      attrs: %{
        style: %{
          position: :fixed,
          top: 10,
          right: 10,
          background: "rgba(0,0,0,0.8)",
          color: :white,
          padding: 15,
          border_radius: 8,
          font_family: :monospace,
          font_size: 12,
          z_index: 9999,
          max_width: 300
        }
      },
      children: [
        %{
          type: :text,
          attrs: %{
            content: "🔍 Debug Inspector",
            style: %{font_weight: :bold, margin_bottom: 10}
          }
        },
        %{
          type: :text,
          attrs: %{content: "Components: #{stats.registered_components}"}
        },
        %{type: :text, attrs: %{content: "Watchers: #{stats.active_watchers}"}},
        %{
          type: :text,
          attrs: %{content: "Monitors: #{stats.performance_monitors}"}
        },
        %{
          type: :text,
          attrs: %{
            content:
              "Profiling: #{case stats.profiling_active do
                true -> "ON"
                false -> "OFF"
              end}"
          }
        },
        debug_overlay_controls()
      ]
    }
  end

  defp debug_overlay_controls do
    %{
      type: :row,
      attrs: %{gap: 5, margin_top: 10},
      children: [
        %{
          type: :button,
          attrs: %{
            label: "Report",
            size: :small,
            on_click: fn ->
              report = generate_debug_report()
              Logger.info("Debug Report: #{inspect(report, pretty: true)}")
            end
          }
        },
        %{
          type: :button,
          attrs: %{
            label: "Memory",
            size: :small,
            on_click: fn -> take_memory_snapshot("manual") end
          }
        }
      ]
    }
  end
end
