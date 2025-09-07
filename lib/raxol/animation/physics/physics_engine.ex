defmodule Raxol.Animation.Physics.PhysicsEngine do
  @moduledoc """
  Physics engine for Raxol animations.

  Provides physics-based animation capabilities including:
  * Spring simulations
  * Gravity and bounce effects
  * Friction and damping
  * Collisions
  * Particle systems
  * Force fields

  These can be used to create natural, organic animations that respond
  to user interactions in a physically plausible way.
  """

  alias Raxol.Animation.Physics.ForceField
  alias Raxol.Animation.Physics.Vector

  @type physics_object :: %{
          id: String.t(),
          position: Vector.t(),
          velocity: Vector.t(),
          acceleration: Vector.t(),
          mass: float(),
          forces: [Vector.t()],
          constraints: map(),
          properties: map()
        }

  @type world_state :: %{
          objects: %{String.t() => physics_object()},
          gravity: Vector.t(),
          time_scale: float(),
          iteration: non_neg_integer(),
          boundaries: map(),
          force_fields: [ForceField.t()],
          # System time in milliseconds
          last_update: integer()
        }

  @doc """
  Creates a new physics world with default values.
  """
  def new_world do
    %{
      objects: %{},
      gravity: %Vector{x: +0.0, y: 9.8, z: +0.0},
      time_scale: 1.0,
      iteration: 0,
      boundaries: %{
        min_x: nil,
        max_x: nil,
        min_y: nil,
        max_y: nil,
        min_z: nil,
        max_z: nil
      },
      force_fields: [],
      last_update: System.os_time(:millisecond)
    }
  end

  @doc """
  Creates a new physics world with custom settings.
  """
  def new_world(opts) do
    world = new_world()

    world
    |> Map.put(:gravity, Keyword.get(opts, :gravity, world.gravity))
    |> Map.put(:time_scale, Keyword.get(opts, :time_scale, world.time_scale))
    |> Map.put(
      :boundaries,
      Map.merge(world.boundaries, Keyword.get(opts, :boundaries, %{}))
    )
  end

  @doc """
  Creates a new physics object with the given properties.
  """
  def new_object(id, opts \\ []) do
    %{
      id: id,
      position: Keyword.get(opts, :position, %Vector{x: 0, y: 0, z: 0}),
      velocity: Keyword.get(opts, :velocity, %Vector{x: 0, y: 0, z: 0}),
      acceleration: %Vector{x: 0, y: 0, z: 0},
      mass: Keyword.get(opts, :mass, 1.0),
      forces: [],
      constraints: Keyword.get(opts, :constraints, %{}),
      properties: Keyword.get(opts, :properties, %{})
    }
  end

  @doc """
  Adds an object to the physics world.
  """
  def add_object(world, object) do
    %{world | objects: Map.put(world.objects, object.id, object)}
  end

  @doc """
  Removes an object from the physics world.
  """
  def remove_object(world, object_id) do
    %{world | objects: Map.delete(world.objects, object_id)}
  end

  @doc """
  Adds a force field to the physics world.
  """
  def add_force_field(world, force_field) do
    %{world | force_fields: [force_field | world.force_fields]}
  end

  @doc """
  Sets the boundaries of the physics world.
  """
  def set_boundaries(world, boundaries) do
    %{world | boundaries: Map.merge(world.boundaries, boundaries)}
  end

  @doc """
  Updates the physics world by one time step.
  """
  def update(world, delta_time \\ nil) do
    # Calculate delta time if not provided
    delta_time = calculate_delta_time(delta_time, world)

    # Update all objects
    updated_objects =
      world.objects
      |> Enum.map(fn {id, object} ->
        {id, update_object(object, world, delta_time)}
      end)
      |> Map.new()

    # Check for collisions
    objects_after_collisions = handle_collisions(updated_objects, world)

    # Apply boundary constraints
    final_objects = apply_boundaries(objects_after_collisions, world.boundaries)

    # Return updated world
    %{
      world
      | objects: final_objects,
        iteration: world.iteration + 1,
        last_update: System.os_time(:millisecond)
    }
  end

  @doc """
  Step function that is an alias for update - for compatibility.
  """
  def step(world, delta_time), do: update(world, delta_time)

  @doc """
  Create a new physics world - alias for new_world.
  """
  def create_world, do: new_world()

  @doc """
  Add object with position and properties - simplified API.
  """
  def add_object(world, id, properties)
      when is_binary(id) and is_map(properties) do
    object = new_object(id, Map.to_list(properties))
    add_object(world, object)
  end

  @doc """
  Creates a spring force between two objects.
  """
  def spring_force(
        world,
        object_id_1,
        object_id_2,
        spring_constant,
        rest_length
      ) do
    object1 = Map.get(world.objects, object_id_1)
    object2 = Map.get(world.objects, object_id_2)

    apply_spring_force_if_objects_exist(
      object1 && object2,
      world,
      object1,
      object2,
      object_id_1,
      object_id_2,
      spring_constant,
      rest_length
    )
  end

  @doc """
  Creates a particle system at the specified position.
  """
  def create_particle_system(world, position, count, opts \\ []) do
    params = %{
      velocity_range: Keyword.get(opts, :velocity_range, {-5.0, 5.0}),
      lifetime_range: Keyword.get(opts, :lifetime_range, {0.5, 2.0}),
      size_range: Keyword.get(opts, :size_range, {1.0, 3.0}),
      color: Keyword.get(opts, :color, :white),
      fade: Keyword.get(opts, :fade, true)
    }

    Enum.reduce(1..count, world, fn i, acc_world ->
      particle = create_particle(position, params, world.iteration, i)
      add_object(acc_world, particle)
    end)
  end

  defp create_particle(position, params, iteration, index) do
    particle_props = create_particle_properties(params)

    new_object("particle_#{iteration}_#{index}",
      position: position,
      velocity: particle_props.velocity,
      mass: particle_props.size * 0.1,
      properties: particle_props
    )
  end

  defp create_particle_properties(params) do
    lifetime = generate_random_value(params.lifetime_range)

    %{
      velocity: generate_random_velocity(params.velocity_range),
      lifetime: lifetime,
      max_lifetime: lifetime,
      size: generate_random_value(params.size_range),
      color: params.color,
      fade: params.fade,
      type: :particle
    }
  end

  defp generate_random_velocity({min_v, max_v}) do
    %Vector{
      x: :rand.uniform() * (max_v - min_v) + min_v,
      y: :rand.uniform() * (max_v - min_v) + min_v,
      z: :rand.uniform() * (max_v - min_v) + min_v
    }
  end

  defp generate_random_value({min, max}) do
    :rand.uniform() * (max - min) + min
  end

  @doc """
  Applies an impulse force to an object.
  """
  def apply_impulse(world, object_id, impulse) do
    case Map.get(world.objects, object_id) do
      nil ->
        world

      object ->
        # F = m * a, so a = F / m
        # For an impulse, we directly change velocity: v' = v + impulse/m
        updated_velocity =
          Vector.add(
            object.velocity,
            Vector.scale(impulse, 1 / object.mass)
          )

        updated_object = %{object | velocity: updated_velocity}
        %{world | objects: Map.put(world.objects, object_id, updated_object)}
    end
  end

  # Private functions

  defp update_object(object, world, delta_time) do
    # Apply gravity
    gravity_force = Vector.scale(world.gravity, object.mass)

    # Combine with existing forces
    all_forces = [gravity_force | object.forces]

    # Apply force fields
    all_forces =
      Enum.reduce(world.force_fields, all_forces, fn field, forces ->
        field_force = ForceField.calculate_force(field, object)
        [field_force | forces]
      end)

    # Calculate net force
    net_force =
      Enum.reduce(all_forces, %Vector{x: 0, y: 0, z: 0}, &Vector.add/2)

    # Calculate acceleration (F = ma, so a = F/m)
    acceleration = Vector.scale(net_force, 1 / object.mass)

    # Apply damping/friction if specified
    damping = Map.get(object.properties, :damping, 0.0)

    velocity_after_damping =
      apply_damping_if_needed(damping > 0, object.velocity, damping, delta_time)

    # Update velocity: v = v0 + a*t
    velocity =
      Vector.add(velocity_after_damping, Vector.scale(acceleration, delta_time))

    # Update position: p = p0 + v*t
    position = Vector.add(object.position, Vector.scale(velocity, delta_time))

    # Update lifetime for particles
    properties =
      update_particle_lifetime(
        Map.has_key?(object.properties, :lifetime),
        object.properties,
        delta_time
      )

    # Return updated object
    %{
      object
      | position: position,
        velocity: velocity,
        acceleration: acceleration,
        # Clear forces after applying
        forces: [],
        properties: properties
    }
  end

  defp handle_collisions(objects, _world) do
    object_list = Map.values(objects)

    Enum.reduce(
      object_list,
      objects,
      &process_object_collisions(&1, object_list, &2)
    )
  end

  defp process_object_collisions(obj1, object_list, acc_objects) do
    Enum.reduce(object_list, acc_objects, fn obj2, inner_acc ->
      process_collision_if_different_objects(
        obj1.id != obj2.id,
        obj1,
        obj2,
        inner_acc
      )
    end)
  end

  defp handle_single_collision(obj1, obj2, acc_objects) do
    handle_collision_if_detected(
      check_collision(obj1, obj2),
      obj1,
      obj2,
      acc_objects
    )
  end

  defp check_collision(obj1, obj2) do
    # For simplicity, assume objects are spheres
    radius1 = Map.get(obj1.properties, :radius, 1.0)
    radius2 = Map.get(obj2.properties, :radius, 1.0)

    # Calculate distance between centers
    distance = Vector.distance(obj1.position, obj2.position)

    # Check if distance is less than sum of radii
    distance < radius1 + radius2
  end

  defp resolve_collision(obj1, obj2) do
    # Calculate collision normal
    normal = Vector.normalize(Vector.subtract(obj2.position, obj1.position))

    # Calculate relative velocity
    relative_velocity = Vector.subtract(obj2.velocity, obj1.velocity)

    # Calculate velocity along normal
    velocity_along_normal = Vector.dot(relative_velocity, normal)

    # Early out if objects are moving away from each other
    resolve_collision_based_on_velocity(
      velocity_along_normal > 0,
      obj1,
      obj2,
      normal,
      velocity_along_normal
    )
  end

  defp apply_boundaries(objects, boundaries) do
    Enum.map(objects, fn {id, obj} ->
      {id, apply_all_boundaries(obj, boundaries)}
    end)
    |> Map.new()
  end

  defp apply_all_boundaries(obj, boundaries) do
    obj
    |> apply_axis_boundary(:x, boundaries)
    |> apply_axis_boundary(:y, boundaries)
    |> apply_axis_boundary(:z, boundaries)
  end

  defp apply_axis_boundary(obj, axis, boundaries) do
    min_key = :"min_#{axis}"
    max_key = :"max_#{axis}"
    pos_key = axis
    vel_key = axis

    obj
    |> apply_min_boundary(pos_key, vel_key, Map.get(boundaries, min_key))
    |> apply_max_boundary(pos_key, vel_key, Map.get(boundaries, max_key))
  end

  defp apply_min_boundary(obj, pos_key, vel_key, min_value) do
    apply_min_boundary_constraint(
      min_value != nil and Map.get(obj.position, pos_key) < min_value,
      obj,
      pos_key,
      vel_key,
      min_value
    )
  end

  defp apply_max_boundary(obj, pos_key, vel_key, max_value) do
    apply_max_boundary_constraint(
      max_value != nil and Map.get(obj.position, pos_key) > max_value,
      obj,
      pos_key,
      vel_key,
      max_value
    )
  end

  # Helper functions to eliminate if statements

  defp calculate_delta_time(nil, world) do
    now = System.os_time(:millisecond)
    dt = (now - world.last_update) / 1000.0
    # Clamp delta time to avoid large steps
    min(dt, 0.1) * world.time_scale
  end

  defp calculate_delta_time(delta_time, _world), do: delta_time

  defp apply_spring_force_if_objects_exist(
         false,
         world,
         _object1,
         _object2,
         _object_id_1,
         _object_id_2,
         _spring_constant,
         _rest_length
       ) do
    world
  end

  defp apply_spring_force_if_objects_exist(
         true,
         world,
         object1,
         object2,
         object_id_1,
         object_id_2,
         spring_constant,
         rest_length
       ) do
    # Calculate spring force
    direction = Vector.subtract(object2.position, object1.position)
    distance = Vector.magnitude(direction)

    # Avoid division by zero
    direction = normalize_direction_vector(distance > 0, direction, distance)

    # Calculate force magnitude (F = k * (d - r))
    force_magnitude = spring_constant * (distance - rest_length)

    # Calculate the force vector
    force = Vector.scale(direction, force_magnitude)

    # Apply forces to both objects
    object1 = %{object1 | forces: [force | object1.forces]}
    object2 = %{object2 | forces: [Vector.negate(force) | object2.forces]}

    # Update world with new object states
    world
    |> Map.put(:objects, Map.put(world.objects, object_id_1, object1))
    |> Map.put(:objects, Map.put(world.objects, object_id_2, object2))
  end

  defp normalize_direction_vector(true, direction, distance) do
    Vector.scale(direction, 1 / distance)
  end

  defp normalize_direction_vector(false, _direction, _distance) do
    %Vector{x: 0, y: 0, z: 0}
  end

  defp apply_damping_if_needed(false, velocity, _damping, _delta_time),
    do: velocity

  defp apply_damping_if_needed(true, velocity, damping, delta_time) do
    Vector.scale(velocity, 1.0 - min(damping * delta_time, 0.99))
  end

  defp update_particle_lifetime(false, properties, _delta_time), do: properties

  defp update_particle_lifetime(true, properties, delta_time) do
    Map.update!(properties, :lifetime, fn lifetime ->
      lifetime - delta_time
    end)
  end

  defp process_collision_if_different_objects(false, _obj1, _obj2, inner_acc),
    do: inner_acc

  defp process_collision_if_different_objects(true, obj1, obj2, inner_acc) do
    obj1_updated = Map.get(inner_acc, obj1.id)
    obj2_updated = Map.get(inner_acc, obj2.id)
    handle_single_collision(obj1_updated, obj2_updated, inner_acc)
  end

  defp handle_collision_if_detected(false, _obj1, _obj2, acc_objects),
    do: acc_objects

  defp handle_collision_if_detected(true, obj1, obj2, acc_objects) do
    {obj1_after, obj2_after} = resolve_collision(obj1, obj2)

    acc_objects
    |> Map.put(obj1.id, obj1_after)
    |> Map.put(obj2.id, obj2_after)
  end

  defp resolve_collision_based_on_velocity(
         true,
         obj1,
         obj2,
         _normal,
         _velocity_along_normal
       ) do
    {obj1, obj2}
  end

  defp resolve_collision_based_on_velocity(
         false,
         obj1,
         obj2,
         normal,
         velocity_along_normal
       ) do
    # Calculate restitution (bounciness)
    restitution =
      min(
        Map.get(obj1.properties, :restitution, 0.8),
        Map.get(obj2.properties, :restitution, 0.8)
      )

    # Calculate impulse scalar
    j = -(1 + restitution) * velocity_along_normal
    j = j / (1 / obj1.mass + 1 / obj2.mass)

    # Apply impulse
    impulse = Vector.scale(normal, j)

    obj1_velocity =
      Vector.subtract(obj1.velocity, Vector.scale(impulse, 1 / obj1.mass))

    obj2_velocity =
      Vector.add(obj2.velocity, Vector.scale(impulse, 1 / obj2.mass))

    # Return updated objects
    {
      %{obj1 | velocity: obj1_velocity},
      %{obj2 | velocity: obj2_velocity}
    }
  end

  defp apply_min_boundary_constraint(
         false,
         obj,
         _pos_key,
         _vel_key,
         _min_value
       ),
       do: obj

  defp apply_min_boundary_constraint(true, obj, pos_key, vel_key, min_value) do
    %{
      obj
      | position: Map.put(obj.position, pos_key, min_value),
        velocity:
          Map.put(
            obj.velocity,
            vel_key,
            -Map.get(obj.velocity, vel_key) * 0.8
          )
    }
  end

  defp apply_max_boundary_constraint(
         false,
         obj,
         _pos_key,
         _vel_key,
         _max_value
       ),
       do: obj

  defp apply_max_boundary_constraint(true, obj, pos_key, vel_key, max_value) do
    %{
      obj
      | position: Map.put(obj.position, pos_key, max_value),
        velocity:
          Map.put(
            obj.velocity,
            vel_key,
            -Map.get(obj.velocity, vel_key) * 0.8
          )
    }
  end
end
