defmodule Raxol.Animation.Physics.Vector do
  @moduledoc """
  3D vector implementation for physics simulations.

  Provides basic vector operations needed for physics calculations.
  """

  @type t :: %__MODULE__{
          x: float(),
          y: float(),
          z: float()
        }

  defstruct x: +0.0, y: +0.0, z: +0.0

  @doc """
  Creates a new vector with the specified components.
  """
  def new(x, y, z \\ +0.0) do
    %__MODULE__{x: x, y: y, z: z}
  end

  @doc """
  Adds two vectors.
  """
  def add(%__MODULE__{} = v1, %__MODULE__{} = v2) do
    %__MODULE__{
      x: v1.x + v2.x,
      y: v1.y + v2.y,
      z: v1.z + v2.z
    }
  end

  @doc """
  Subtracts the second vector from the first.
  """
  def subtract(%__MODULE__{} = v1, %__MODULE__{} = v2) do
    %__MODULE__{
      x: v1.x - v2.x,
      y: v1.y - v2.y,
      z: v1.z - v2.z
    }
  end

  @doc """
  Multiplies a vector by a scalar.
  """
  def scale(%__MODULE__{} = v, scalar) do
    %__MODULE__{
      x: v.x * scalar,
      y: v.y * scalar,
      z: v.z * scalar
    }
  end

  @doc """
  Calculates the dot product of two vectors.
  """
  def dot(%__MODULE__{} = v1, %__MODULE__{} = v2) do
    v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
  end

  @doc """
  Calculates the cross product of two vectors.
  """
  def cross(%__MODULE__{} = v1, %__MODULE__{} = v2) do
    %__MODULE__{
      x: v1.y * v2.z - v1.z * v2.y,
      y: v1.z * v2.x - v1.x * v2.z,
      z: v1.x * v2.y - v1.y * v2.x
    }
  end

  @doc """
  Calculates the magnitude (length) of a vector.
  """
  def magnitude(%__MODULE__{} = v) do
    :math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
  end

  @doc """
  Normalizes a vector (makes it unit length).
  """
  def normalize(%__MODULE__{} = v) do
    mag = magnitude(v)

    if mag > 0 do
      scale(v, 1.0 / mag)
    else
      v
    end
  end

  @doc """
  Calculates the distance between two points represented as vectors.
  """
  def distance(%__MODULE__{} = v1, %__MODULE__{} = v2) do
    dx = v2.x - v1.x
    dy = v2.y - v1.y
    dz = v2.z - v1.z

    :math.sqrt(dx * dx + dy * dy + dz * dz)
  end

  @doc """
  Returns the negation of the vector.
  """
  def negate(%__MODULE__{} = v) do
    %__MODULE__{
      x: -v.x,
      y: -v.y,
      z: -v.z
    }
  end

  @doc """
  Performs linear interpolation between two vectors.
  """
  def lerp(%__MODULE__{} = v1, %__MODULE__{} = v2, t) when t >= 0 and t <= 1 do
    %__MODULE__{
      x: v1.x + (v2.x - v1.x) * t,
      y: v1.y + (v2.y - v1.y) * t,
      z: v1.z + (v2.z - v1.z) * t
    }
  end

  @doc """
  Calculates the angle between two vectors in radians.
  """
  def angle(%__MODULE__{} = v1, %__MODULE__{} = v2) do
    dot_product = dot(v1, v2)
    magnitudes = magnitude(v1) * magnitude(v2)

    if magnitudes == 0 do
      0
    else
      :math.acos(min(1, max(-1, dot_product / magnitudes)))
    end
  end

  @doc """
  Creates a vector from spherical coordinates.
  """
  def from_spherical(radius, theta, phi) do
    %__MODULE__{
      x: radius * :math.sin(phi) * :math.cos(theta),
      y: radius * :math.sin(phi) * :math.sin(theta),
      z: radius * :math.cos(phi)
    }
  end

  @doc """
  Converts the vector to a string representation.
  """
  def to_string(%__MODULE__{} = v) do
    "(#{v.x}, #{v.y}, #{v.z})"
  end
end
