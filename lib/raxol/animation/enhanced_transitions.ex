defmodule Raxol.Animation.EnhancedTransitions do
  @moduledoc """
  Enhanced animation transitions with advanced effects and performance optimizations.

  This module provides:
  - Morphing transitions between different shapes/states
  - Particle system animations
  - Path-based animations (curves, spirals, etc.)
  - Physics-based animations with spring dynamics
  - Chained animation sequences
  - Performance-optimized batch animations
  """

  alias Raxol.Animation.Framework
  alias Raxol.Animation.Physics.Vector

  @doc """
  Creates a morphing animation that smoothly transitions between different visual states.

  ## Examples

      iex> EnhancedTransitions.create_morph_animation(:button_to_input, %{
      ...>   from_state: %{width: 100, height: 30, border_radius: 15},
      ...>   to_state: %{width: 200, height: 40, border_radius: 5},
      ...>   duration: 500,
      ...>   easing: :ease_in_out_cubic
      ...> })
  """
  def create_morph_animation(name, %{from_state: from, to_state: to} = params) do
    transitions = generate_property_transitions(from, to)

    Framework.create_animation(
      name,
      Map.merge(params, %{
        type: :morph,
        transitions: transitions,
        interpolate_fn: &interpolate_morph_state/3
      })
    )
  end

  @doc """
  Creates a particle system animation for effects like sparkles, explosions, or trails.

  ## Examples

      iex> EnhancedTransitions.create_particle_animation(:sparkle_effect, %{
      ...>   particle_count: 20,
      ...>   spawn_area: %{x: 0, y: 0, width: 100, height: 50},
      ...>   velocity_range: %{min: 10, max: 50},
      ...>   duration: 1000,
      ...>   particle_lifetime: 800
      ...> })
  """
  def create_particle_animation(name, params) do
    particles = generate_particles(params)

    Framework.create_animation(
      name,
      Map.merge(params, %{
        type: :particle_system,
        particles: particles,
        update_fn: &update_particle_system/3
      })
    )
  end

  @doc """
  Creates a path-based animation that follows curves, spirals, or custom paths.

  ## Examples

      iex> EnhancedTransitions.create_path_animation(:spiral_entrance, %{
      ...>   path_type: :spiral,
      ...>   center: %{x: 100, y: 100},
      ...>   radius: 50,
      ...>   rotations: 2,
      ...>   duration: 1200,
      ...>   easing: :ease_out_back
      ...> })
  """
  def create_path_animation(name, params) do
    path_points = generate_path_points(params)

    Framework.create_animation(
      name,
      Map.merge(params, %{
        type: :path_based,
        path_points: path_points,
        interpolate_fn: &interpolate_path_position/3
      })
    )
  end

  @doc """
  Creates a physics-based animation using spring dynamics for natural movement.

  ## Examples

      iex> EnhancedTransitions.create_spring_animation(:elastic_bounce, %{
      ...>   target: %{x: 200, y: 150},
      ...>   spring_tension: 300,
      ...>   spring_friction: 20,
      ...>   mass: 1.0,
      ...>   velocity: %{x: 0, y: 0}
      ...> })
  """
  def create_spring_animation(name, params) do
    Framework.create_animation(
      name,
      Map.merge(params, %{
        type: :physics_spring,
        physics_state: initialize_spring_physics(params),
        update_fn: &update_spring_physics/3
      })
    )
  end

  @doc """
  Creates a sequence of chained animations that execute one after another.

  ## Examples

      iex> EnhancedTransitions.create_sequence_animation(:entrance_sequence, %{
      ...>   animations: [
      ...>     {:fade_in, %{duration: 300, easing: :ease_out}},
      ...>     {:slide_up, %{duration: 400, easing: :ease_out_back}},
      ...>     {:scale_bounce, %{duration: 200, easing: :ease_out_bounce}}
      ...>   ]
      ...> })
  """
  def create_sequence_animation(name, %{animations: animation_list} = params) do
    total_duration = calculate_sequence_duration(animation_list)

    Framework.create_animation(
      name,
      Map.merge(params, %{
        type: :sequence,
        total_duration: total_duration,
        animation_sequence: animation_list,
        update_fn: &update_animation_sequence/3
      })
    )
  end

  @doc """
  Creates a batch animation that efficiently animates multiple elements simultaneously.

  ## Examples

      iex> EnhancedTransitions.create_batch_animation(:stagger_in, %{
      ...>   elements: ["item1", "item2", "item3", "item4"],
      ...>   base_animation: :fade_in,
      ...>   stagger_delay: 100,
      ...>   duration: 300
      ...> })
  """
  def create_batch_animation(name, %{elements: elements} = params) do
    batch_config = generate_batch_config(elements, params)

    Framework.create_animation(
      name,
      Map.merge(params, %{
        type: :batch,
        batch_config: batch_config,
        update_fn: &update_batch_animation/3
      })
    )
  end

  # Private helper functions

  defp generate_property_transitions(from_state, to_state) do
    from_keys = Map.keys(from_state)
    to_keys = Map.keys(to_state)
    all_keys = Enum.uniq(from_keys ++ to_keys)

    Enum.map(all_keys, fn key ->
      from_val = Map.get(from_state, key, 0)
      to_val = Map.get(to_state, key, 0)
      %{property: key, from: from_val, to: to_val}
    end)
  end

  defp interpolate_morph_state(progress, from_state, to_state) do
    Enum.reduce(Map.keys(to_state), %{}, fn key, acc ->
      from_val = Map.get(from_state, key, 0)
      to_val = Map.get(to_state, key, 0)
      interpolated_val = from_val + (to_val - from_val) * progress
      Map.put(acc, key, interpolated_val)
    end)
  end

  defp generate_particles(%{particle_count: count} = params) do
    spawn_area =
      Map.get(params, :spawn_area, %{x: 0, y: 0, width: 100, height: 100})

    velocity_range = Map.get(params, :velocity_range, %{min: 10, max: 50})

    1..count
    |> Enum.map(fn _i ->
      %{
        x: spawn_area.x + :rand.uniform() * spawn_area.width,
        y: spawn_area.y + :rand.uniform() * spawn_area.height,
        velocity_x:
          (velocity_range.min +
             :rand.uniform() * (velocity_range.max - velocity_range.min)) *
            (:rand.uniform() - 0.5) * 2,
        velocity_y:
          (velocity_range.min +
             :rand.uniform() * (velocity_range.max - velocity_range.min)) *
            (:rand.uniform() - 0.5) * 2,
        lifetime: 1.0,
        size: 2 + :rand.uniform() * 4
      }
    end)
  end

  defp update_particle_system(progress, params, current_particles) do
    # Assume 60fps for physics
    dt = 1.0 / 60.0

    updated_particles =
      Enum.map(current_particles, fn particle ->
        new_lifetime =
          particle.lifetime - dt / (params[:particle_lifetime] || 1000) * 1000

        %{
          particle
          | x: particle.x + particle.velocity_x * dt,
            y: particle.y + particle.velocity_y * dt,
            # Gravity effect
            velocity_y: particle.velocity_y + 100 * dt,
            lifetime: max(0.0, new_lifetime),
            # Fade out effect
            size: particle.size * new_lifetime
        }
      end)
      |> Enum.filter(fn p -> p.lifetime > 0.0 end)

    %{particles: updated_particles, progress: progress}
  end

  defp generate_path_points(%{path_type: :spiral} = params) do
    center = params[:center] || %{x: 0, y: 0}
    radius = params[:radius] || 50
    rotations = params[:rotations] || 1
    points = params[:resolution] || 50

    0..points
    |> Enum.map(fn i ->
      t = i / points
      angle = t * rotations * 2 * :math.pi()
      current_radius = radius * t

      %{
        x: center.x + current_radius * :math.cos(angle),
        y: center.y + current_radius * :math.sin(angle)
      }
    end)
  end

  defp generate_path_points(%{path_type: :bezier} = params) do
    control_points = params[:control_points] || []
    resolution = params[:resolution] || 50
    generate_bezier_points(control_points, resolution)
  end

  defp generate_path_points(_params), do: []

  defp generate_bezier_points(control_points, resolution)
       when length(control_points) >= 4 do
    0..resolution
    |> Enum.map(fn i ->
      t = i / resolution
      calculate_bezier_point(control_points, t)
    end)
  end

  defp generate_bezier_points(_control_points, _resolution), do: []

  defp calculate_bezier_point([p0, p1, p2, p3], t) do
    # Cubic Bezier curve calculation
    u = 1 - t
    tt = t * t
    uu = u * u
    uuu = uu * u
    ttt = tt * t

    %{
      x: uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x,
      y: uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y
    }
  end

  defp interpolate_path_position(progress, _params, path_points) do
    calculate_path_interpolation(path_points, progress)
  end

  defp calculate_path_interpolation(path_points, progress)
       when length(path_points) > 1 do
    index = progress * (length(path_points) - 1)
    lower_index = floor(index)
    upper_index = min(lower_index + 1, length(path_points) - 1)

    local_progress = index - lower_index

    lower_point = Enum.at(path_points, lower_index)
    upper_point = Enum.at(path_points, upper_index)

    %{
      x: lower_point.x + (upper_point.x - lower_point.x) * local_progress,
      y: lower_point.y + (upper_point.y - lower_point.y) * local_progress
    }
  end

  defp calculate_path_interpolation(_path_points, _progress), do: %{x: 0, y: 0}

  defp initialize_spring_physics(params) do
    %{
      position: Vector.new(0, 0),
      velocity: Vector.from_map(params[:velocity] || %{x: 0, y: 0}),
      target: Vector.from_map(params[:target] || %{x: 0, y: 0}),
      spring_tension: params[:spring_tension] || 300,
      spring_friction: params[:spring_friction] || 20,
      mass: params[:mass] || 1.0
    }
  end

  defp update_spring_physics(_progress, _params, physics_state) do
    # 60fps timestep
    dt = 1.0 / 60.0

    # Spring force calculation
    displacement = Vector.subtract(physics_state.target, physics_state.position)
    spring_force = Vector.scale(displacement, physics_state.spring_tension)

    # Friction force
    friction_force =
      Vector.scale(physics_state.velocity, -physics_state.spring_friction)

    # Total force
    total_force = Vector.add(spring_force, friction_force)

    # Acceleration (F = ma, so a = F/m)
    acceleration = Vector.scale(total_force, 1.0 / physics_state.mass)

    # Update velocity and position using Euler integration
    new_velocity =
      Vector.add(physics_state.velocity, Vector.scale(acceleration, dt))

    new_position =
      Vector.add(physics_state.position, Vector.scale(new_velocity, dt))

    %{physics_state | position: new_position, velocity: new_velocity}
  end

  defp calculate_sequence_duration(animation_list) do
    Enum.reduce(animation_list, 0, fn {_name, params}, acc ->
      duration = params[:duration] || 300
      delay = params[:delay] || 0
      acc + duration + delay
    end)
  end

  defp update_animation_sequence(progress, params, _sequence_state) do
    total_duration = params[:total_duration]
    current_time = progress * total_duration

    {active_animation, local_progress} =
      find_active_animation(params[:animation_sequence], current_time)

    %{
      active_animation: active_animation,
      local_progress: local_progress,
      overall_progress: progress
    }
  end

  defp find_active_animation(animation_list, current_time) do
    find_active_animation_recursive(animation_list, current_time, 0)
  end

  defp find_active_animation_recursive([], _current_time, _accumulated_time) do
    {nil, 1.0}
  end

  defp find_active_animation_recursive(
         [{name, params} | rest],
         current_time,
         accumulated_time
       ) do
    duration = params[:duration] || 300
    delay = params[:delay] || 0
    animation_start = accumulated_time + delay
    animation_end = animation_start + duration

    check_animation_active(
      current_time >= animation_start and current_time <= animation_end,
      name,
      current_time,
      animation_start,
      duration,
      rest,
      animation_end
    )
  end

  defp check_animation_active(
         true,
         name,
         current_time,
         animation_start,
         duration,
         _rest,
         _animation_end
       ) do
    local_progress = (current_time - animation_start) / duration
    {name, min(1.0, max(0.0, local_progress))}
  end

  defp check_animation_active(
         false,
         _name,
         current_time,
         _animation_start,
         _duration,
         rest,
         animation_end
       ) do
    find_active_animation_recursive(rest, current_time, animation_end)
  end

  defp generate_batch_config(elements, params) do
    base_animation = params[:base_animation]
    stagger_delay = params[:stagger_delay] || 0

    elements
    |> Enum.with_index()
    |> Enum.map(fn {element_id, index} ->
      %{
        element_id: element_id,
        animation: base_animation,
        delay: index * stagger_delay,
        duration: params[:duration] || 300
      }
    end)
  end

  defp update_batch_animation(progress, params, _batch_state) do
    total_duration = params[:duration] || 300
    stagger_delay = params[:stagger_delay] || 0

    current_time =
      progress *
        (total_duration + (length(params[:elements]) - 1) * stagger_delay)

    element_states =
      Enum.map(params[:batch_config], fn config ->
        element_start_time = config.delay

        element_progress =
          calculate_element_progress(
            current_time >= element_start_time,
            current_time,
            element_start_time,
            config.duration
          )

        %{
          element_id: config.element_id,
          progress: element_progress,
          active: element_progress > 0.0 and element_progress < 1.0
        }
      end)

    %{
      element_states: element_states,
      overall_progress: progress
    }
  end

  defp calculate_element_progress(
         true,
         current_time,
         element_start_time,
         duration
       ) do
    min(1.0, (current_time - element_start_time) / duration)
  end

  defp calculate_element_progress(
         false,
         _current_time,
         _element_start_time,
         _duration
       ) do
    0.0
  end
end
