defmodule Raxol.Terminal.Rendering.AdaptiveFrameRate do
  @moduledoc """
  Adaptive frame rate system for smart refresh optimization in Raxol terminals.

  This module provides intelligent refresh rate management that adapts to:
  - Content change frequency (static text vs animations)
  - System performance and battery life
  - User interaction patterns (active typing vs idle)
  - Terminal focus state and visibility
  - Hardware capabilities and thermal constraints
  - Network latency for remote terminals

  ## Features

  ### Adaptive Refresh Strategies
  - **Content-Aware**: Reduces frame rate for static content
  - **Interaction-Based**: Higher rates during active user input
  - **Performance-Scaled**: Adapts to system load and thermal state
  - **Battery-Optimized**: Lower rates on battery power
  - **Focus-Aware**: Pauses rendering when terminal is not visible
  - **Network-Adaptive**: Adjusts for remote terminal latency

  ### Performance Benefits
  - Reduced CPU/GPU usage during idle periods
  - Extended battery life on mobile devices
  - Lower thermal generation and fan noise
  - Better responsiveness during high-activity periods
  - Smoother animations with variable refresh rates

  ## Usage

      # Initialize adaptive frame rate manager
      {:ok, afr} = AdaptiveFrameRate.start_link(
        target_fps: 60,
        min_fps: 1,
        max_fps: 120,
        strategy: :adaptive
      )
      
      # Register content change
      AdaptiveFrameRate.content_changed(afr, change_type: :text_update)
      
      # Register user interaction
      AdaptiveFrameRate.user_interaction(afr, interaction_type: :keystroke)
      
      # Get current optimal frame rate
      fps = AdaptiveFrameRate.get_current_fps(afr)
      
      # Enable battery optimization
      AdaptiveFrameRate.set_power_mode(afr, :battery)
  """

  use GenServer
  require Logger

  defstruct [
    :config,
    :current_fps,
    :target_fps,
    :frame_history,
    :content_analyzer,
    :interaction_tracker,
    :performance_monitor,
    :power_manager,
    :focus_tracker,
    :stats
  ]

  @type fps :: number()
  @type refresh_strategy ::
          :fixed | :adaptive | :content_aware | :battery_optimized
  @type power_mode :: :performance | :balanced | :battery | :eco
  @type interaction_type ::
          :keystroke | :mouse_move | :mouse_click | :scroll | :resize
  @type content_change_type ::
          :text_update | :cursor_move | :scroll | :color_change | :animation
  @type focus_state :: :focused | :unfocused | :minimized | :occluded

  @type config :: %{
          target_fps: fps(),
          min_fps: fps(),
          max_fps: fps(),
          strategy: refresh_strategy(),
          power_mode: power_mode(),
          enable_vsync: boolean(),
          thermal_throttling: boolean(),
          network_adaptive: boolean()
        }

  @type frame_stats :: %{
          current_fps: fps(),
          average_fps: fps(),
          frame_time_ms: float(),
          dropped_frames: integer(),
          power_efficiency: float(),
          thermal_state: :normal | :warm | :hot
        }

  # Default configuration
  @default_config %{
    target_fps: 60,
    min_fps: 1,
    max_fps: 120,
    strategy: :adaptive,
    power_mode: :balanced,
    enable_vsync: true,
    thermal_throttling: true,
    network_adaptive: false
  }

  # Frame rate thresholds for different scenarios
  @idle_fps 5
  @text_editing_fps 30
  @animation_fps 60
  @high_activity_fps 120
  @battery_max_fps 30
  @eco_max_fps 15

  # Timing constants
  @interaction_timeout_ms 2000
  @content_change_timeout_ms 500
  @thermal_check_interval_ms 5000
  @stats_update_interval_ms 1000

  ## Public API

  @doc """
  Starts the adaptive frame rate manager.

  ## Options
  - `:target_fps` - Preferred frame rate (default: 60)
  - `:min_fps` - Minimum frame rate (default: 1)
  - `:max_fps` - Maximum frame rate (default: 120)
  - `:strategy` - Refresh strategy (default: :adaptive)
  - `:power_mode` - Power management mode (default: :balanced)
  """
  def start_link(opts \\ []) do
    config = opts |> Enum.into(%{}) |> then(&Map.merge(@default_config, &1))
    GenServer.start_link(__MODULE__, config)
  end

  @doc """
  Registers a content change to influence frame rate decisions.
  """
  def content_changed(afr, opts \\ []) do
    change_type = Keyword.get(opts, :change_type, :text_update)
    intensity = Keyword.get(opts, :intensity, :normal)
    GenServer.cast(afr, {:content_changed, change_type, intensity})
  end

  @doc """
  Registers user interaction to boost frame rate temporarily.
  """
  def user_interaction(afr, opts \\ []) do
    interaction_type = Keyword.get(opts, :interaction_type, :keystroke)
    GenServer.cast(afr, {:user_interaction, interaction_type})
  end

  @doc """
  Gets the current optimal frame rate.
  """
  def get_current_fps(afr) do
    GenServer.call(afr, :get_current_fps)
  end

  @doc """
  Gets comprehensive frame rate statistics.
  """
  def get_stats(afr) do
    GenServer.call(afr, :get_stats)
  end

  @doc """
  Updates the power management mode.
  """
  def set_power_mode(afr, power_mode)
      when power_mode in [:performance, :balanced, :battery, :eco] do
    GenServer.call(afr, {:set_power_mode, power_mode})
  end

  @doc """
  Updates the refresh strategy.
  """
  def set_strategy(afr, strategy)
      when strategy in [:fixed, :adaptive, :content_aware, :battery_optimized] do
    GenServer.call(afr, {:set_strategy, strategy})
  end

  @doc """
  Sets the terminal focus state.
  """
  def set_focus_state(afr, focus_state)
      when focus_state in [:focused, :unfocused, :minimized, :occluded] do
    GenServer.cast(afr, {:set_focus_state, focus_state})
  end

  @doc """
  Forces a specific frame rate (overrides adaptive behavior).
  """
  def force_fps(afr, fps) when is_number(fps) and fps > 0 do
    GenServer.call(afr, {:force_fps, fps})
  end

  @doc """
  Resumes adaptive frame rate behavior after forcing.
  """
  def resume_adaptive(afr) do
    GenServer.call(afr, :resume_adaptive)
  end

  @doc """
  Enables or disables VSync.
  """
  def set_vsync(afr, enabled) when is_boolean(enabled) do
    GenServer.call(afr, {:set_vsync, enabled})
  end

  ## GenServer Implementation

  @impl GenServer
  def init(config) do
    # Schedule periodic updates
    :timer.send_interval(@stats_update_interval_ms, :update_stats)
    :timer.send_interval(@thermal_check_interval_ms, :check_thermal_state)

    state = %__MODULE__{
      config: config,
      current_fps: config.target_fps,
      target_fps: config.target_fps,
      frame_history: :queue.new(),
      content_analyzer: init_content_analyzer(),
      interaction_tracker: init_interaction_tracker(),
      performance_monitor: init_performance_monitor(),
      power_manager: init_power_manager(config.power_mode),
      focus_tracker: %{
        state: :focused,
        last_change: System.monotonic_time(:millisecond)
      },
      stats: init_stats()
    }

    Logger.info(
      "Adaptive frame rate initialized: target=#{config.target_fps}fps, strategy=#{config.strategy}"
    )

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_current_fps, _from, state) do
    {:reply, state.current_fps, state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats = calculate_comprehensive_stats(state)
    {:reply, stats, state}
  end

  @impl GenServer
  def handle_call({:set_power_mode, power_mode}, _from, state) do
    new_config = %{state.config | power_mode: power_mode}
    new_power_manager = init_power_manager(power_mode)

    new_state = %{state | config: new_config, power_manager: new_power_manager}

    # Recalculate optimal FPS with new power mode
    updated_state = calculate_optimal_fps(new_state)

    Logger.info(
      "Power mode changed to #{power_mode}, new FPS: #{updated_state.current_fps}"
    )

    {:reply, :ok, updated_state}
  end

  @impl GenServer
  def handle_call({:set_strategy, strategy}, _from, state) do
    new_config = %{state.config | strategy: strategy}
    new_state = %{state | config: new_config}

    # Recalculate with new strategy
    updated_state = calculate_optimal_fps(new_state)

    Logger.info(
      "Strategy changed to #{strategy}, new FPS: #{updated_state.current_fps}"
    )

    {:reply, :ok, updated_state}
  end

  @impl GenServer
  def handle_call({:force_fps, fps}, _from, state) do
    clamped_fps = clamp_fps(fps, state.config)

    new_state = %{
      state
      | current_fps: clamped_fps,
        config: Map.put(state.config, :forced_fps, clamped_fps)
    }

    Logger.info("FPS forced to #{clamped_fps}")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:resume_adaptive, _from, state) do
    new_config = Map.delete(state.config, :forced_fps)
    new_state = %{state | config: new_config}

    # Recalculate optimal FPS
    updated_state = calculate_optimal_fps(new_state)

    Logger.info("Resumed adaptive FPS: #{updated_state.current_fps}")
    {:reply, :ok, updated_state}
  end

  @impl GenServer
  def handle_call({:set_vsync, enabled}, _from, state) do
    new_config = %{state.config | enable_vsync: enabled}
    new_state = %{state | config: new_config}

    Logger.info("VSync #{get_vsync_status(enabled)}")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_cast({:content_changed, change_type, intensity}, state) do
    updated_analyzer =
      update_content_analyzer(state.content_analyzer, change_type, intensity)

    new_state = %{state | content_analyzer: updated_analyzer}

    # Recalculate optimal FPS based on content changes
    updated_state = calculate_optimal_fps(new_state)

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:user_interaction, interaction_type}, state) do
    updated_tracker =
      update_interaction_tracker(state.interaction_tracker, interaction_type)

    new_state = %{state | interaction_tracker: updated_tracker}

    # Boost FPS temporarily for interactions
    updated_state = apply_interaction_boost(new_state, interaction_type)

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:set_focus_state, focus_state}, state) do
    now = System.monotonic_time(:millisecond)
    new_focus_tracker = %{state: focus_state, last_change: now}
    new_state = %{state | focus_tracker: new_focus_tracker}

    # Adjust FPS based on focus state
    updated_state = apply_focus_adjustment(new_state, focus_state)

    Logger.debug(
      "Focus state changed to #{focus_state}, FPS: #{updated_state.current_fps}"
    )

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_info(:update_stats, state) do
    new_stats = update_frame_stats(state.stats, state.current_fps)
    updated_state = %{state | stats: new_stats}

    # Periodic optimization check
    optimized_state = maybe_optimize_fps(updated_state)

    {:noreply, optimized_state}
  end

  @impl GenServer
  def handle_info(:check_thermal_state, state) do
    handle_thermal_check(state.config.thermal_throttling, state)
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Private Implementation

  defp get_vsync_status(true), do: "enabled"
  defp get_vsync_status(false), do: "disabled"

  defp handle_thermal_check(false, state), do: {:noreply, state}

  defp handle_thermal_check(true, state) do
    thermal_state = check_system_thermal_state()
    updated_state = apply_thermal_throttling(state, thermal_state)
    {:noreply, updated_state}
  end

  defp calculate_fps_with_override(true, state) do
    %{state | current_fps: state.config.forced_fps}
  end

  defp calculate_fps_with_override(false, state) do
    base_fps = calculate_base_fps(state)
    content_fps = apply_content_analysis(base_fps, state.content_analyzer)

    interaction_fps =
      apply_interaction_boost_calculation(
        content_fps,
        state.interaction_tracker
      )

    power_fps = apply_power_constraints(interaction_fps, state.power_manager)
    focus_fps = apply_focus_constraints(power_fps, state.focus_tracker)
    final_fps = clamp_fps(focus_fps, state.config)

    %{state | current_fps: final_fps, target_fps: final_fps}
  end

  defp apply_interaction_boost_if_active(
         false,
         content_fps,
         _interaction_tracker
       ) do
    content_fps
  end

  defp apply_interaction_boost_if_active(true, content_fps, interaction_tracker) do
    # Boost FPS during active interaction
    boost_multiplier =
      case interaction_tracker.interaction_intensity do
        :low -> 1.2
        :medium -> 1.5
        :high -> 2.0
      end

    round(content_fps * boost_multiplier)
  end

  defp apply_throttling_if_needed(false, state, _throttle_factor), do: state

  defp apply_throttling_if_needed(true, state, throttle_factor) do
    new_fps = round(state.current_fps * throttle_factor)

    Logger.info(
      "Thermal throttling applied: #{state.current_fps} -> #{new_fps} fps"
    )

    %{state | current_fps: clamp_fps(new_fps, state.config)}
  end

  defp calculate_fps_from_stats(false, state), do: state.current_fps

  defp calculate_fps_from_stats(true, state) do
    1000.0 / state.stats.average_frame_time
  end

  defp calculate_optimal_fps(state) do
    # Check for forced FPS override
    calculate_fps_with_override(Map.has_key?(state.config, :forced_fps), state)
  end

  defp calculate_base_fps(state) do
    case state.config.strategy do
      :fixed -> state.config.target_fps
      :adaptive -> adaptive_base_fps(state)
      :content_aware -> content_aware_base_fps(state)
      :battery_optimized -> battery_optimized_base_fps(state)
    end
  end

  defp adaptive_base_fps(state) do
    # Intelligent base FPS calculation
    system_load = get_system_load()
    battery_level = get_battery_level()

    calculate_adaptive_fps(system_load, battery_level, state.config.target_fps)
  end

  defp calculate_adaptive_fps(system_load, _battery_level, _target_fps)
       when system_load > 0.8,
       do: @text_editing_fps

  defp calculate_adaptive_fps(_system_load, battery_level, _target_fps)
       when battery_level < 0.2,
       do: @battery_max_fps

  defp calculate_adaptive_fps(_system_load, _battery_level, target_fps),
    do: target_fps

  defp content_aware_base_fps(state) do
    case state.content_analyzer.primary_activity do
      :idle -> @idle_fps
      :text_editing -> @text_editing_fps
      :animation -> @animation_fps
      :high_activity -> @high_activity_fps
      _ -> @text_editing_fps
    end
  end

  defp battery_optimized_base_fps(_state) do
    case get_power_source() do
      :battery -> @battery_max_fps
      :ac -> @text_editing_fps
      _ -> @battery_max_fps
    end
  end

  defp apply_content_analysis(base_fps, content_analyzer) do
    now = System.monotonic_time(:millisecond)

    # Check recent content activity
    recent_changes =
      content_analyzer.recent_changes
      |> Enum.filter(fn {_type, timestamp} ->
        now - timestamp < @content_change_timeout_ms
      end)

    boost_factor =
      case length(recent_changes) do
        # No recent changes, reduce FPS
        0 -> 0.5
        # Normal activity
        n when n < 3 -> 1.0
        # High activity
        n when n < 10 -> 1.5
        # Very high activity
        _ -> 2.0
      end

    round(base_fps * boost_factor)
  end

  defp apply_interaction_boost_calculation(content_fps, interaction_tracker) do
    now = System.monotonic_time(:millisecond)

    recent_interactions =
      interaction_tracker.recent_interactions
      |> Enum.filter(fn {_type, timestamp} ->
        now - timestamp < @interaction_timeout_ms
      end)

    apply_interaction_boost_if_active(
      length(recent_interactions) > 0,
      content_fps,
      interaction_tracker
    )
  end

  defp apply_interaction_boost(state, interaction_type) do
    boost_fps =
      case interaction_type do
        :keystroke -> min(state.config.target_fps, @text_editing_fps)
        :mouse_move -> min(state.config.target_fps * 1.2, @animation_fps)
        :mouse_click -> min(state.config.target_fps, @text_editing_fps)
        :scroll -> min(state.config.target_fps * 1.5, @animation_fps)
        :resize -> @animation_fps
      end

    %{state | current_fps: clamp_fps(boost_fps, state.config)}
  end

  defp apply_power_constraints(fps, power_manager) do
    max_fps =
      case power_manager.mode do
        :performance -> fps
        :balanced -> min(fps, round(fps * 0.8))
        :battery -> min(fps, @battery_max_fps)
        :eco -> min(fps, @eco_max_fps)
      end

    max_fps
  end

  defp apply_focus_constraints(fps, focus_tracker) do
    case focus_tracker.state do
      :focused -> fps
      :unfocused -> round(fps * 0.5)
      :minimized -> @idle_fps
      :occluded -> round(fps * 0.3)
    end
  end

  defp apply_focus_adjustment(state, focus_state) do
    adjustment_factor =
      case focus_state do
        :focused -> 1.0
        :unfocused -> 0.5
        :minimized -> 0.1
        :occluded -> 0.3
      end

    new_fps = round(state.target_fps * adjustment_factor)
    %{state | current_fps: clamp_fps(new_fps, state.config)}
  end

  defp apply_thermal_throttling(state, thermal_state) do
    throttle_factor =
      case thermal_state do
        :normal -> 1.0
        :warm -> 0.8
        :hot -> 0.5
      end

    apply_throttling_if_needed(throttle_factor < 1.0, state, throttle_factor)
  end

  defp clamp_fps(fps, config) do
    fps
    |> max(config.min_fps)
    |> min(config.max_fps)
    |> round()
  end

  defp maybe_optimize_fps(state) do
    # Periodic optimization based on performance metrics
    case should_optimize?(state) do
      true ->
        Logger.debug("Running FPS optimization")
        calculate_optimal_fps(state)
      false ->
        state
    end
  end

  defp should_optimize?(state) do
    # Check if we should run optimization
    stats = state.stats

    # Optimize if frame rate is unstable or performance is poor
    stats.frame_variance > 5.0 or stats.average_frame_time > 20.0
  end

  ## Initialization Functions

  defp init_content_analyzer do
    %{
      primary_activity: :idle,
      recent_changes: [],
      change_frequency: 0.0,
      last_significant_change: System.monotonic_time(:millisecond)
    }
  end

  defp init_interaction_tracker do
    %{
      recent_interactions: [],
      interaction_intensity: :low,
      last_interaction: nil,
      interaction_frequency: 0.0
    }
  end

  defp init_performance_monitor do
    %{
      cpu_usage: 0.0,
      memory_usage: 0.0,
      gpu_usage: 0.0,
      system_load: 0.0
    }
  end

  defp init_power_manager(power_mode) do
    %{
      mode: power_mode,
      battery_level: get_battery_level(),
      power_source: get_power_source(),
      thermal_state: :normal
    }
  end

  defp init_stats do
    %{
      frames_rendered: 0,
      total_frame_time: 0.0,
      average_frame_time: 0.0,
      frame_variance: 0.0,
      dropped_frames: 0,
      power_efficiency: 1.0
    }
  end

  ## Update Functions

  defp update_content_analyzer(analyzer, change_type, _intensity) do
    now = System.monotonic_time(:millisecond)

    # Add to recent changes
    new_changes =
      [{change_type, now} | analyzer.recent_changes]
      # Keep last 50 changes
      |> Enum.take(50)

    # Determine primary activity
    primary_activity = determine_primary_activity(new_changes)

    # Calculate change frequency
    recent_count =
      Enum.count(new_changes, fn {_, timestamp} ->
        now - timestamp < @content_change_timeout_ms
      end)

    frequency = recent_count / (@content_change_timeout_ms / 1000)

    %{
      analyzer
      | primary_activity: primary_activity,
        recent_changes: new_changes,
        change_frequency: frequency,
        last_significant_change: now
    }
  end

  defp update_interaction_tracker(tracker, interaction_type) do
    now = System.monotonic_time(:millisecond)

    # Add to recent interactions
    new_interactions =
      [{interaction_type, now} | tracker.recent_interactions]
      # Keep last 20 interactions
      |> Enum.take(20)

    # Calculate interaction intensity
    recent_count =
      Enum.count(new_interactions, fn {_, timestamp} ->
        now - timestamp < @interaction_timeout_ms
      end)

    intensity =
      case recent_count do
        n when n < 2 -> :low
        n when n < 5 -> :medium
        _ -> :high
      end

    frequency = recent_count / (@interaction_timeout_ms / 1000)

    %{
      tracker
      | recent_interactions: new_interactions,
        interaction_intensity: intensity,
        last_interaction: {interaction_type, now},
        interaction_frequency: frequency
    }
  end

  defp update_frame_stats(stats, current_fps) do
    # Update frame statistics
    new_frame_count = stats.frames_rendered + 1
    # Convert FPS to frame time in ms
    frame_time = 1000.0 / current_fps
    new_total_time = stats.total_frame_time + frame_time
    new_average = new_total_time / new_frame_count

    # Calculate variance (simplified)
    variance = abs(frame_time - new_average)

    %{
      stats
      | frames_rendered: new_frame_count,
        total_frame_time: new_total_time,
        average_frame_time: new_average,
        frame_variance: variance
    }
  end

  ## Helper Functions

  defp determine_primary_activity(recent_changes) do
    # Analyze recent changes to determine primary activity
    change_types = Enum.map(recent_changes, &elem(&1, 0))

    analyze_activity_pattern(change_types)
  end

  defp analyze_activity_pattern(change_types) do
    cond do
      :animation in change_types ->
        :animation

      length(change_types) > 10 ->
        :high_activity

      true ->
        text_update_count = Enum.count(change_types, &(&1 == :text_update))

        case {text_update_count, change_types} do
          {count, _} when count > 3 -> :text_editing
          {_, []} -> :idle
          _ -> :normal
        end
    end
  end

  defp calculate_comprehensive_stats(state) do
    %{
      current_fps: state.current_fps,
      target_fps: state.target_fps,
      average_fps: calculate_average_fps(state),
      frame_time_ms: 1000.0 / state.current_fps,
      strategy: state.config.strategy,
      power_mode: state.power_manager.mode,
      focus_state: state.focus_tracker.state,
      content_activity: state.content_analyzer.primary_activity,
      interaction_intensity: state.interaction_tracker.interaction_intensity,
      thermal_state: state.power_manager.thermal_state,
      frames_rendered: state.stats.frames_rendered,
      dropped_frames: state.stats.dropped_frames
    }
  end

  defp calculate_average_fps(state) do
    calculate_fps_from_stats(
      state.stats.frames_rendered > 0 and state.stats.average_frame_time > 0,
      state
    )
  end

  ## System Integration Functions (Platform-specific implementations would go here)

  defp get_system_load do
    # Placeholder - would use actual system monitoring
    :rand.uniform()
  end

  defp get_battery_level do
    # Placeholder - would query actual battery level
    case :os.type() do
      # 75% battery
      {:unix, :darwin} -> 0.75
      # Assume AC power
      _ -> 1.0
    end
  end

  defp get_power_source do
    # Placeholder - would detect actual power source
    case :os.type() do
      {:unix, :darwin} -> if :rand.uniform() > 0.5, do: :battery, else: :ac
      _ -> :ac
    end
  end

  defp check_system_thermal_state do
    # Placeholder - would check actual thermal sensors
    case :rand.uniform(10) do
      n when n > 8 -> :hot
      n when n > 6 -> :warm
      _ -> :normal
    end
  end

  ## Public Utility Functions

  @doc """
  Calculates optimal frame rate for specific content type.
  """
  def optimal_fps_for_content(content_type) do
    case content_type do
      :static_text -> @idle_fps
      :text_editing -> @text_editing_fps
      :scrolling -> @animation_fps
      :animation -> @animation_fps
      :video_playback -> 30
      :gaming -> @high_activity_fps
      :data_visualization -> @animation_fps
      _ -> @text_editing_fps
    end
  end

  @doc """
  Suggests power optimization settings based on usage pattern.
  """
  def suggest_power_optimization(usage_stats) do
    idle_percentage = Map.get(usage_stats, :idle_time_percentage, 50)
    battery_level = Map.get(usage_stats, :battery_level, 1.0)

    determine_power_mode(battery_level, idle_percentage)
  end

  defp determine_power_mode(battery_level, _idle_percentage)
       when battery_level < 0.2,
       do: %{power_mode: :eco, max_fps: @eco_max_fps}

  defp determine_power_mode(battery_level, _idle_percentage)
       when battery_level < 0.5,
       do: %{power_mode: :battery, max_fps: @battery_max_fps}

  defp determine_power_mode(_battery_level, idle_percentage)
       when idle_percentage > 70,
       do: %{power_mode: :balanced, enable_aggressive_idle: true}

  defp determine_power_mode(_battery_level, _idle_percentage),
    do: %{power_mode: :performance, max_fps: @high_activity_fps}
end
