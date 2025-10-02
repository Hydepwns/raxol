defmodule Raxol.Terminal.Graphics.Animation do
  @moduledoc """
  Terminal graphics animation adapter that bridges the existing Raxol.Animation.Framework
  with terminal graphics capabilities.

  This module provides:
  - Frame-based animation system for terminal graphics
  - Integration with Kitty protocol animations
  - Smooth transitions for graphics elements
  - Performance monitoring for terminal animations
  - Fallback support for non-animation terminals

  ## Usage

      # Create a graphics fade animation
      Graphics.Animation.create_graphics_animation(:fade_in, %{
        duration: 500,
        easing: :ease_out_cubic,
        from: %{opacity: 0.0},
        to: %{opacity: 1.0}
      })

      # Animate an image scaling
      Graphics.Animation.create_image_animation(:scale_up, %{
        duration: 300,
        from: %{width: 100, height: 100},
        to: %{width: 200, height: 200}
      })
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Animation.Framework
  alias Raxol.Animation.Interpolate
  alias Raxol.Terminal.Graphics.GraphicsServer

  @type animation_id :: String.t()
  @type graphics_id :: non_neg_integer()
  @type frame_data :: %{
          timestamp: non_neg_integer(),
          graphics_id: graphics_id(),
          properties: map()
        }

  defstruct [
    :active_animations,
    :graphics_animations,
    :performance_metrics,
    :config
  ]

  @default_config %{
    max_fps: 30,
    performance_monitoring: true,
    fallback_mode: true,
    animation_buffer_size: 10
  }

  # Public API

  # BaseManager provides start_link
  @doc """
  Creates a graphics animation definition for use with terminal graphics.

  ## Parameters

  - `name` - Animation name/identifier
  - `params` - Animation parameters including:
    - `duration` - Animation duration in milliseconds
    - `easing` - Easing function (see Raxol.Animation.Interpolate)
    - `from`/`to` - Graphics properties to animate
    - `frame_delay` - Delay between frames (default: calculated from fps)
  """
  @spec create_graphics_animation(atom(), map()) :: :ok | {:error, term()}
  def create_graphics_animation(name, params) do
    GenServer.call(__MODULE__, {:create_graphics_animation, name, params})
  end

  # BaseManager provides start_link
  @doc """
  Starts a graphics animation on a specific graphics element.

  ## Parameters

  - `animation_name` - Name of the animation to start
  - `graphics_id` - Graphics element ID to animate
  - `options` - Additional options for the animation instance
  """
  @spec start_graphics_animation(atom(), graphics_id(), map()) ::
          {:ok, animation_id()} | {:error, term()}
  def start_graphics_animation(animation_name, graphics_id, options \\ %{}) do
    GenServer.call(
      __MODULE__,
      {:start_graphics_animation, animation_name, graphics_id, options}
    )
  end

  # BaseManager provides start_link
  @doc """
  Creates a smooth image animation between frames.

  ## Parameters

  - `name` - Animation name
  - `frames` - List of image data for animation frames
  - `options` - Animation options (duration, loop_count, etc.)
  """
  @spec create_image_animation(atom(), [binary()], map()) ::
          :ok | {:error, term()}
  def create_image_animation(name, frames, options) do
    GenServer.call(__MODULE__, {:create_image_animation, name, frames, options})
  end

  # BaseManager provides start_link
  @doc """
  Gets current performance metrics for graphics animations.
  """
  @spec get_performance_metrics() :: map()
  def get_performance_metrics do
    GenServer.call(__MODULE__, :get_performance_metrics)
  end

  # BaseManager provides start_link
  @doc """
  Stops a running graphics animation.
  """
  @spec stop_graphics_animation(animation_id()) :: :ok | {:error, term()}
  def stop_graphics_animation(animation_id) do
    GenServer.call(__MODULE__, {:stop_graphics_animation, animation_id})
  end

  # GenServer Implementation

  @impl true
  def init_manager(opts) do
    config = Map.merge(@default_config, Map.new(opts))

    # Schedule animation frame processing
    schedule_frame_tick(config.max_fps)

    initial_state = %__MODULE__{
      active_animations: %{},
      graphics_animations: %{},
      performance_metrics: initialize_metrics(),
      config: config
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_manager_call(
        {:create_graphics_animation, name, params},
        _from,
        state
      ) do
    case validate_animation_params(params) do
      :ok ->
        # Create the animation definition with the existing framework
        animation_def = build_animation_definition(params)

        case Framework.create_animation(name, animation_def) do
          :ok ->
            graphics_animations =
              Map.put(state.graphics_animations, name, params)

            {:reply, :ok, %{state | graphics_animations: graphics_animations}}

          error ->
            {:reply, error, state}
        end

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_manager_call(
        {:start_graphics_animation, name, graphics_id, options},
        _from,
        state
      ) do
    case Map.get(state.graphics_animations, name) do
      nil ->
        {:reply, {:error, :animation_not_found}, state}

      _animation_params ->
        animation_id = generate_animation_id(name, graphics_id)

        # Start the animation using the existing framework
        case Framework.start_animation(name, animation_id, options) do
          :ok ->
            animation_info = %{
              name: name,
              graphics_id: graphics_id,
              started_at: System.system_time(:millisecond),
              options: options
            }

            active_animations =
              Map.put(state.active_animations, animation_id, animation_info)

            {:reply, {:ok, animation_id},
             %{state | active_animations: active_animations}}

          error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_manager_call(
        {:create_image_animation, name, frames, options},
        _from,
        state
      ) do
    case create_frame_based_animation(name, frames, options) do
      {:ok, animation_def} ->
        graphics_animations =
          Map.put(state.graphics_animations, name, animation_def)

        {:reply, :ok, %{state | graphics_animations: graphics_animations}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_manager_call(:get_performance_metrics, _from, state) do
    {:reply, state.performance_metrics, state}
  end

  @impl true
  def handle_manager_call(
        {:stop_graphics_animation, animation_id},
        _from,
        state
      ) do
    case Map.get(state.active_animations, animation_id) do
      nil ->
        {:reply, {:error, :animation_not_found}, state}

      animation_info ->
        _ = Framework.stop_animation(animation_info.name, animation_id)
        active_animations = Map.delete(state.active_animations, animation_id)
        {:reply, :ok, %{state | active_animations: active_animations}}
    end
  end

  @impl true
  def handle_manager_info(:frame_tick, state) do
    # Process active animations and apply to graphics
    new_state = process_animation_frame(state)

    # Schedule next frame
    schedule_frame_tick(state.config.max_fps)

    {:noreply, new_state}
  end

  # Private Functions

  defp validate_animation_params(params) do
    required_keys = [:duration]

    case Enum.all?(required_keys, &Map.has_key?(params, &1)) do
      true -> :ok
      false -> {:error, :missing_required_parameters}
    end
  end

  defp build_animation_definition(params) do
    %{
      duration: Map.get(params, :duration),
      easing: Map.get(params, :easing, :linear),
      from: Map.get(params, :from, %{}),
      to: Map.get(params, :to, %{}),
      target_path: [:graphics_properties],
      interpolate_fn: &interpolate_graphics_properties/3
    }
  end

  defp create_frame_based_animation(_name, frames, options) do
    duration = Map.get(options, :duration, length(frames) * 100)
    frame_delay = div(duration, length(frames))

    animation_def = %{
      type: :frame_based,
      frames: frames,
      duration: duration,
      frame_delay: frame_delay,
      loop_count: Map.get(options, :loop_count, 1)
    }

    {:ok, animation_def}
  end

  defp interpolate_graphics_properties(from, to, progress)
       when is_map(from) and is_map(to) do
    Enum.reduce(to, %{}, fn {key, to_value}, acc ->
      from_value = Map.get(from, key, 0)
      interpolated_value = Interpolate.value(from_value, to_value, progress)
      Map.put(acc, key, interpolated_value)
    end)
  end

  defp process_animation_frame(state) do
    start_time = System.monotonic_time(:microsecond)

    # Get current animation values from the framework
    active_animations =
      Enum.reduce(
        state.active_animations,
        state.active_animations,
        fn {animation_id, animation_info}, acc ->
          case Framework.get_current_value(animation_info.name, animation_id) do
            {:ok, values} ->
              # Apply values to graphics element
              apply_graphics_properties(animation_info.graphics_id, values)
              acc

            :not_found ->
              # Remove completed animation
              Map.delete(acc, animation_id)

            {:error, _reason} ->
              acc
          end
        end
      )

    # Update performance metrics
    process_time = System.monotonic_time(:microsecond) - start_time

    metrics =
      update_performance_metrics(state.performance_metrics, process_time)

    %{
      state
      | active_animations: active_animations,
        performance_metrics: metrics
    }
  end

  defp apply_graphics_properties(graphics_id, properties) do
    # Apply animated properties to the graphics element
    # This would integrate with the unified graphics system
    case GraphicsServer.update_graphics_properties(graphics_id, properties) do
      :ok ->
        :ok

      {:error, reason} ->
        Raxol.Core.Runtime.Log.module_warning(
          "Failed to apply graphics properties: #{inspect(reason)}"
        )
    end
  end

  defp generate_animation_id(name, graphics_id) do
    "#{name}_#{graphics_id}_#{:rand.uniform(9999)}"
  end

  defp schedule_frame_tick(max_fps) do
    interval = div(1000, max_fps)
    Process.send_after(self(), :frame_tick, interval)
  end

  defp initialize_metrics do
    %{
      total_frames: 0,
      avg_frame_time: 0.0,
      active_animation_count: 0,
      started_at: System.system_time(:millisecond)
    }
  end

  defp update_performance_metrics(metrics, process_time_microseconds) do
    frame_time_ms = process_time_microseconds / 1000.0
    total_frames = metrics.total_frames + 1

    # Calculate rolling average
    avg_frame_time =
      case metrics.avg_frame_time do
        avg when avg == 0.0 -> frame_time_ms
        current_avg -> current_avg * 0.9 + frame_time_ms * 0.1
      end

    %{
      metrics
      | total_frames: total_frames,
        avg_frame_time: avg_frame_time
    }
  end
end
