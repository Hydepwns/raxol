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
      gravity: %Vector{x: 0, y: 9.8, z: 0},
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
    delta_time =
      if delta_time do
        delta_time
      else
        now = System.os_time(:millisecond)
        dt = (now - world.last_update) / 1000.0
        # Clamp delta time to avoid large steps
        min(dt, 0.1) * world.time_scale
      end

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

    if object1 && object2 do
      # Calculate spring force
      direction = Vector.subtract(object2.position, object1.position)
      distance = Vector.magnitude(direction)

      # Avoid division by zero
      direction =
        if distance > 0 do
          Vector.scale(direction, 1 / distance)
        else
          %Vector{x: 0, y: 0, z: 0}
        end

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
    else
      world
    end
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

    # Create the particles
    Enum.reduce(1..count, world, fn i, acc_world ->
      # Create random velocity
      {min_v, max_v} = params.velocity_range

      velocity = %Vector{
        x: :rand.uniform() * (max_v - min_v) + min_v,
        y: :rand.uniform() * (max_v - min_v) + min_v,
        z: :rand.uniform() * (max_v - min_v) + min_v
      }

      # Create random lifetime
      {min_l, max_l} = params.lifetime_range
      lifetime = :rand.uniform() * (max_l - min_l) + min_l

      # Create random size
      {min_s, max_s} = params.size_range
      size = :rand.uniform() * (max_s - min_s) + min_s

      # Create the particle
      particle =
        new_object("particle_#{world.iteration}_#{i}",
          position: position,
          velocity: velocity,
          mass: size * 0.1,
          properties: %{
            lifetime: lifetime,
            max_lifetime: lifetime,
            size: size,
            color: params.color,
            fade: params.fade,
            type: :particle
          }
        )

      # Add to world
      add_object(acc_world, particle)
    end)
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
      if damping > 0 do
        Vector.scale(object.velocity, 1.0 - min(damping * delta_time, 0.99))
      else
        object.velocity
      end

    # Update velocity: v = v0 + a*t
    velocity =
      Vector.add(velocity_after_damping, Vector.scale(acceleration, delta_time))

    # Update position: p = p0 + v*t
    position = Vector.add(object.position, Vector.scale(velocity, delta_time))

    # Update lifetime for particles
    properties =
      if Map.has_key?(object.properties, :lifetime) do
        Map.update!(object.properties, :lifetime, fn lifetime ->
          lifetime - delta_time
        end)
      else
        object.properties
      end

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
    # This is a simplified collision detection algorithm
    # For a real implementation, you'd use a more efficient spatial partitioning

    # Get list of objects
    object_list = Map.values(objects)

    # Check all pairs of objects for collisions
    Enum.reduce(object_list, objects, fn obj1, acc_objects ->
      Enum.reduce(object_list, acc_objects, fn obj2, inner_acc ->
        if obj1.id != obj2.id do
          # Check for collision
          obj1_updated = Map.get(inner_acc, obj1.id)
          obj2_updated = Map.get(inner_acc, obj2.id)

          if check_collision(obj1_updated, obj2_updated) do
            # Handle collision and update objects
            {obj1_after, obj2_after} =
              resolve_collision(obj1_updated, obj2_updated)

            inner_acc
            |> Map.put(obj1.id, obj1_after)
            |> Map.put(obj2.id, obj2_after)
          else
            inner_acc
          end
        else
          inner_acc
        end
      end)
    end)
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
    if velocity_along_normal > 0 do
      {obj1, obj2}
    else
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
  end

  defp apply_boundaries(objects, boundaries) do
    Enum.map(objects, fn {id, obj} ->
      updated_obj = obj

      # Apply X boundaries
      updated_obj =
        if boundaries.min_x != nil and obj.position.x < boundaries.min_x do
          %{
            updated_obj
            | position: %{updated_obj.position | x: boundaries.min_x},
              velocity: %{
                updated_obj.velocity
                | x: -updated_obj.velocity.x * 0.8
              }
          }
        else
          updated_obj
        end

      updated_obj =
        if boundaries.max_x != nil and obj.position.x > boundaries.max_x do
          %{
            updated_obj
            | position: %{updated_obj.position | x: boundaries.max_x},
              velocity: %{
                updated_obj.velocity
                | x: -updated_obj.velocity.x * 0.8
              }
          }
        else
          updated_obj
        end

      # Apply Y boundaries
      updated_obj =
        if boundaries.min_y != nil and obj.position.y < boundaries.min_y do
          %{
            updated_obj
            | position: %{updated_obj.position | y: boundaries.min_y},
              velocity: %{
                updated_obj.velocity
                | y: -updated_obj.velocity.y * 0.8
              }
          }
        else
          updated_obj
        end

      updated_obj =
        if boundaries.max_y != nil and obj.position.y > boundaries.max_y do
          %{
            updated_obj
            | position: %{updated_obj.position | y: boundaries.max_y},
              velocity: %{
                updated_obj.velocity
                | y: -updated_obj.velocity.y * 0.8
              }
          }
        else
          updated_obj
        end

      # Apply Z boundaries
      updated_obj =
        if boundaries.min_z != nil and obj.position.z < boundaries.min_z do
          %{
            updated_obj
            | position: %{updated_obj.position | z: boundaries.min_z},
              velocity: %{
                updated_obj.velocity
                | z: -updated_obj.velocity.z * 0.8
              }
          }
        else
          updated_obj
        end

      updated_obj =
        if boundaries.max_z != nil and obj.position.z > boundaries.max_z do
          %{
            updated_obj
            | position: %{updated_obj.position | z: boundaries.max_z},
              velocity: %{
                updated_obj.velocity
                | z: -updated_obj.velocity.z * 0.8
              }
          }
        else
          updated_obj
        end

      {id, updated_obj}
    end)
    |> Map.new()
  end
end
