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
        seed: Keyword.get(opts, :seed, :rand.uniform(10_000))
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
    direction = Vector.subtract(object.position, field.position)
    distance = Vector.magnitude(direction)

    if field.radius != :infinity and distance > field.radius do
      %Vector{}
    else
      direction = normalize_direction(direction, distance)
      force_magnitude = calculate_force_magnitude(field, distance)
      Vector.scale(direction, force_magnitude)
    end
  end

  defp normalize_direction(direction, distance) do
    if distance > 0 do
      Vector.scale(direction, 1 / distance)
    else
      theta = :rand.uniform() * 2 * :math.pi()
      phi = :rand.uniform() * :math.pi()
      Vector.from_spherical(1, theta, phi)
    end
  end

  defp calculate_force_magnitude(field, distance) do
    magnitude =
      case field.falloff do
        :none ->
          field.strength

        :linear ->
          field.strength * (1 - distance / field.radius)

        :quadratic ->
          field.strength *
            (1 - distance / field.radius * (distance / field.radius))
      end

    max(0, magnitude)
  end

  defp calculate_directional_force(
         %__MODULE__{type: :directional} = field,
         _object
       ) do
    # Simply apply the force in the specified direction
    Vector.scale(field.direction, field.strength)
  end

  defp calculate_vortex_force(%__MODULE__{type: :vortex} = field, object) do
    to_object = Vector.subtract(object.position, field.position)
    distance = Vector.magnitude(to_object)

    if field.radius != :infinity and distance > field.radius do
      %Vector{}
    else
      calculate_vortex_force_at_point(field, to_object, distance)
    end
  end

  defp calculate_vortex_force_at_point(field, to_object, distance) do
    axis_projection =
      Vector.scale(field.direction, Vector.dot(to_object, field.direction))

    perpendicular = Vector.subtract(to_object, axis_projection)
    perp_distance = Vector.magnitude(perpendicular)

    if perp_distance > 0 do
      perp_normalized = Vector.scale(perpendicular, 1 / perp_distance)
      tangent = Vector.cross(field.direction, perp_normalized)
      force_magnitude = calculate_force_magnitude(field, distance)
      Vector.scale(tangent, force_magnitude)
    else
      %Vector{}
    end
  end

  defp calculate_noise_force(%__MODULE__{type: :noise} = field, object) do
    scale = field.properties.scale
    seed = field.properties.seed
    scaled_pos = scale_position(object.position, scale, seed)
    noise_vector = calculate_noise_vector(scaled_pos)
    Vector.scale(noise_vector, field.strength)
  end

  defp scale_position(position, scale, seed) do
    %Vector{
      x: position.x * scale + seed,
      y: position.y * scale + seed * 2,
      z: position.z * scale + seed * 3
    }
  end

  defp calculate_noise_vector(%Vector{x: x, y: y, z: z}) do
    offsets = [{0.2, 0.5}, {0.1, 0.3}, {0.3, 0.4}]

    [x_val, y_val, z_val] =
      Enum.map(offsets, fn {y_off, z_off} ->
        calculate_noise_component(x, y, z, y_off, z_off)
      end)

    %Vector{x: x_val, y: y_val, z: z_val}
  end

  defp calculate_noise_component(x, y, z, y_offset, z_offset) do
    :math.sin(x) * :math.cos(y + y_offset) * :math.sin(z + z_offset)
  end

  defp calculate_custom_force(%__MODULE__{type: :custom} = field, object) do
    if field.function do
      field.function.(object, field)
    else
      %Vector{}
    end
  end
end
