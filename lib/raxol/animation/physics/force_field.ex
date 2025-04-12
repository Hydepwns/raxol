defmodule Raxol.Animation.Physics.ForceField do
  @moduledoc """
  Force field implementation for physics simulations.

  Force fields apply forces to physics objects within their influence.
  Types of force fields include:

  * Point (radial forces emanating from a point)
  * Directional (constant force in a direction, like wind)
  * Vortex (spinning forces)
  * Noise (random forces based on position)
  * Custom (user-defined force function)
  """

  alias Raxol.Animation.Physics.Vector

  @type field_type :: :point | :directional | :vortex | :noise | :custom

  @type t :: %__MODULE__{
          type: field_type(),
          position: Vector.t(),
          direction: Vector.t(),
          strength: float(),
          radius: float(),
          falloff: :linear | :quadratic | :none,
          function: (any(), any() -> Vector.t()) | nil,
          properties: map()
        }

  defstruct type: :point,
            position: %Vector{},
            direction: %Vector{x: 0, y: 1, z: 0},
            strength: 1.0,
            radius: 10.0,
            falloff: :quadratic,
            function: nil,
            properties: %{}

  @doc """
  Creates a new point force field.

  A point force field applies forces radiating from or towards a point.
  Positive strength = repulsive, Negative strength = attractive.

  ## Options

  * `:position` - Position of the field (default: origin)
  * `:strength` - Strength of the field (default: 1.0)
  * `:radius` - Radius of influence (default: 10.0)
  * `:falloff` - How force decreases with distance (:linear, :quadratic, :none) (default: :quadratic)
  """
  def point_field(opts \\ []) do
    %__MODULE__{
      type: :point,
      position: Keyword.get(opts, :position, %Vector{}),
      strength: Keyword.get(opts, :strength, 1.0),
      radius: Keyword.get(opts, :radius, 10.0),
      falloff: Keyword.get(opts, :falloff, :quadratic)
    }
  end

  @doc """
  Creates a new directional force field.

  A directional force field applies a constant force in a specific direction,
  like wind or gravity.

  ## Options

  * `:direction` - Direction of the force (default: up)
  * `:strength` - Strength of the field (default: 1.0)
  """
  def directional_field(opts \\ []) do
    %__MODULE__{
      type: :directional,
      direction:
        Keyword.get(opts, :direction, %Vector{x: 0, y: 1, z: 0})
        |> Vector.normalize(),
      strength: Keyword.get(opts, :strength, 1.0),
      radius: :infinity
    }
  end

  @doc """
  Creates a new vortex force field.

  A vortex force field applies spinning forces around an axis.

  ## Options

  * `:position` - Center of the vortex (default: origin)
  * `:direction` - Axis of rotation (default: up)
  * `:strength` - Strength of the field (default: 1.0)
  * `:radius` - Radius of influence (default: 10.0)
  * `:falloff` - How force decreases with distance (:linear, :quadratic, :none) (default: :linear)
  """
  def vortex_field(opts \\ []) do
    %__MODULE__{
      type: :vortex,
      position: Keyword.get(opts, :position, %Vector{}),
      direction:
        Keyword.get(opts, :direction, %Vector{x: 0, y: 1, z: 0})
        |> Vector.normalize(),
      strength: Keyword.get(opts, :strength, 1.0),
      radius: Keyword.get(opts, :radius, 10.0),
      falloff: Keyword.get(opts, :falloff, :linear)
    }
  end

  @doc """
  Creates a new noise force field.

  A noise force field applies pseudo-random forces based on position.

  ## Options

  * `:strength` - Strength of the field (default: 1.0)
  * `:scale` - Scale of the noise (default: 0.1)
  * `:seed` - Random seed (default: random)
  """
  def noise_field(opts \\ []) do
    %__MODULE__{
      type: :noise,
      strength: Keyword.get(opts, :strength, 1.0),
      radius: :infinity,
      properties: %{
        scale: Keyword.get(opts, :scale, 0.1),
        seed: Keyword.get(opts, :seed, :rand.uniform(10000))
      }
    }
  end

  @doc """
  Creates a new custom force field.

  A custom force field uses a user-provided function to calculate forces.

  ## Options

  * `:function` - Function to calculate force (fn object, field -> force_vector end)
  * `:properties` - Additional properties for the function (default: %{})
  """
  def custom_field(function, opts \\ []) when is_function(function, 2) do
    %__MODULE__{
      type: :custom,
      function: function,
      properties: Keyword.get(opts, :properties, %{}),
      radius: Keyword.get(opts, :radius, :infinity)
    }
  end

  @doc """
  Calculates the force applied by a field on an object.
  """
  def calculate_force(%__MODULE__{} = field, object) do
    case field.type do
      :point -> calculate_point_force(field, object)
      :directional -> calculate_directional_force(field, object)
      :vortex -> calculate_vortex_force(field, object)
      :noise -> calculate_noise_force(field, object)
      :custom -> calculate_custom_force(field, object)
    end
  end

  # Private functions

  defp calculate_point_force(%__MODULE__{type: :point} = field, object) do
    # Vector from field center to object
    direction = Vector.subtract(object.position, field.position)
    distance = Vector.magnitude(direction)

    # Check if object is within radius
    if field.radius != :infinity and distance > field.radius do
      %Vector{}
    else
      # Normalize direction
      direction =
        if distance > 0 do
          Vector.scale(direction, 1 / distance)
        else
          # Random direction if at exact center
          theta = :rand.uniform() * 2 * :math.pi()
          phi = :rand.uniform() * :math.pi()
          Vector.from_spherical(1, theta, phi)
        end

      # Calculate force magnitude based on falloff
      force_magnitude =
        case field.falloff do
          :none ->
            field.strength

          :linear ->
            field.strength * (1 - distance / field.radius)

          :quadratic ->
            field.strength *
              (1 - distance / field.radius * (distance / field.radius))
        end

      # Ensure magnitude is positive
      force_magnitude = max(0, force_magnitude)

      # Calculate final force vector
      Vector.scale(direction, force_magnitude)
    end
  end

  defp calculate_directional_force(
         %__MODULE__{type: :directional} = field,
         _object
       ) do
    # Simply apply the force in the specified direction
    Vector.scale(field.direction, field.strength)
  end

  defp calculate_vortex_force(%__MODULE__{type: :vortex} = field, object) do
    # Vector from field center to object
    to_object = Vector.subtract(object.position, field.position)
    distance = Vector.magnitude(to_object)

    # Check if object is within radius
    if field.radius != :infinity and distance > field.radius do
      %Vector{}
    else
      # Project the point onto the axis
      axis_projection =
        Vector.scale(field.direction, Vector.dot(to_object, field.direction))

      # Get the perpendicular component
      perpendicular = Vector.subtract(to_object, axis_projection)
      perp_distance = Vector.magnitude(perpendicular)

      if perp_distance > 0 do
        # Normalize the perpendicular component
        perp_normalized = Vector.scale(perpendicular, 1 / perp_distance)

        # Calculate the tangent direction (cross product with axis)
        tangent = Vector.cross(field.direction, perp_normalized)

        # Calculate force magnitude based on falloff
        force_magnitude =
          case field.falloff do
            :none ->
              field.strength

            :linear ->
              field.strength * (1 - distance / field.radius)

            :quadratic ->
              field.strength *
                (1 - distance / field.radius * (distance / field.radius))
          end

        # Ensure magnitude is positive
        force_magnitude = max(0, force_magnitude)

        # The force is tangential to the circle around the axis
        Vector.scale(tangent, force_magnitude)
      else
        # If point is on the axis, no force
        %Vector{}
      end
    end
  end

  defp calculate_noise_force(%__MODULE__{type: :noise} = field, object) do
    # This is a simplified Perlin-like noise
    # In a real implementation, you'd use a proper noise function

    scale = field.properties.scale
    seed = field.properties.seed

    # Scale the position and add the seed
    x = object.position.x * scale + seed
    y = object.position.y * scale + seed * 2
    z = object.position.z * scale + seed * 3

    # Generate pseudo-random values based on position
    # These are simplified noise functions
    noise_x = :math.sin(x) * :math.cos(y + 0.2) * :math.sin(z + 0.5)
    noise_y = :math.cos(x + 0.1) * :math.sin(y) * :math.cos(z + 0.3)
    noise_z = :math.sin(x + 0.3) * :math.cos(y + 0.4) * :math.sin(z)

    # Create force vector and scale by strength
    %Vector{
      x: noise_x * field.strength,
      y: noise_y * field.strength,
      z: noise_z * field.strength
    }
  end

  defp calculate_custom_force(%__MODULE__{type: :custom} = field, object) do
    if field.function do
      field.function.(object, field)
    else
      %Vector{}
    end
  end
end
