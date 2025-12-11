defmodule Raxol.Effects.CursorTrail do
  @moduledoc """
  Visual cursor trail effects for terminal interfaces.

  Creates a fading trail behind cursor movements for enhanced visual feedback.
  Useful for:
  - Drawing attention to cursor position
  - Visualizing movement patterns
  - Improving accessibility
  - Creating engaging UIs

  ## Example

      trail = CursorTrail.new(max_length: 10)
      trail = CursorTrail.update(trail, {5, 10})
      trail = CursorTrail.update(trail, {6, 10})
      trail = CursorTrail.update(trail, {7, 10})

      # Apply trail to buffer
      buffer = CursorTrail.apply(trail, buffer)

  ## Configuration

      config = %{
        max_length: 20,           # Maximum trail positions to track
        decay_rate: 0.15,         # How quickly trail fades (0.0-1.0)
        colors: [:cyan, :blue, :magenta],
        chars: ["*", "+", "."],   # Characters for different trail positions
        min_opacity: 0.1          # Minimum opacity before hiding
      }

      trail = CursorTrail.new(config)
  """

  alias Raxol.Core.Buffer

  @type position :: {non_neg_integer(), non_neg_integer()}

  @type trail_point :: %{
          position: position(),
          age: non_neg_integer(),
          opacity: float()
        }

  @type config :: %{
          optional(:max_length) => pos_integer(),
          optional(:decay_rate) => float(),
          optional(:colors) => list(atom()),
          optional(:chars) => list(String.t()),
          optional(:min_opacity) => float(),
          optional(:enabled) => boolean()
        }

  @type t :: %__MODULE__{
          points: list(trail_point()),
          config: config(),
          tick: non_neg_integer()
        }

  defstruct points: [],
            config: %{},
            tick: 0

  @default_config %{
    max_length: 15,
    decay_rate: 0.12,
    colors: [:cyan, :blue, :magenta, :white],
    chars: ["*", "+", ".", ":"],
    min_opacity: 0.15,
    enabled: true
  }

  @doc """
  Create a new cursor trail effect.
  """
  @spec new(config()) :: t()
  def new(config \\ %{}) do
    merged_config = Map.merge(@default_config, config)

    %__MODULE__{
      points: [],
      config: merged_config,
      tick: 0
    }
  end

  @doc """
  Update trail with new cursor position.
  """
  @spec update(t(), position()) :: t()
  def update(%{config: %{enabled: false}} = trail, _position), do: trail

  def update(%{points: points, config: config, tick: tick} = trail, position) do
    # Don't add if position hasn't changed
    new_points =
      case points do
        [%{position: ^position} | _] ->
          # Same position, just age existing points
          age_points(points)

        _ ->
          # New position, add to trail
          new_point = %{
            position: position,
            age: 0,
            opacity: 1.0
          }

          [new_point | age_points(points)]
          |> Enum.take(config.max_length)
          |> filter_visible(config.min_opacity)
      end

    %{trail | points: new_points, tick: tick + 1}
  end

  @doc """
  Apply trail effect to buffer.
  """
  @spec apply(t(), Buffer.t()) :: Buffer.t()
  def apply(%{config: %{enabled: false}}, buffer), do: buffer

  def apply(%{points: points, config: config}, buffer) do
    points
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {point, idx}, buf ->
      apply_point(buf, point, idx, config)
    end)
  end

  @doc """
  Clear all trail points.
  """
  @spec clear(t()) :: t()
  def clear(trail) do
    %{trail | points: [], tick: 0}
  end

  @doc """
  Enable or disable trail effect.
  """
  @spec set_enabled(t(), boolean()) :: t()
  def set_enabled(trail, enabled) do
    put_in(trail.config.enabled, enabled)
  end

  @doc """
  Update trail configuration.
  """
  @spec update_config(t(), config()) :: t()
  def update_config(%{config: current_config} = trail, new_config) do
    merged = Map.merge(current_config, new_config)
    %{trail | config: merged}
  end

  @doc """
  Get current trail length.
  """
  @spec length(t()) :: non_neg_integer()
  def length(%{points: points}), do: Kernel.length(points)

  @doc """
  Get trail statistics.
  """
  @spec stats(t()) :: map()
  def stats(%{points: points, config: config, tick: tick}) do
    %{
      point_count: Kernel.length(points),
      max_length: config.max_length,
      enabled: config.enabled,
      tick: tick,
      average_opacity:
        if Kernel.length(points) > 0 do
          Enum.sum(Enum.map(points, & &1.opacity)) / Kernel.length(points)
        else
          0.0
        end
    }
  end

  # Private functions

  defp age_points(points) do
    points
    |> Enum.map(fn point ->
      %{point | age: point.age + 1}
    end)
  end

  defp filter_visible(points, min_opacity) do
    points
    |> Enum.map(fn point ->
      opacity = calculate_opacity(point.age)
      %{point | opacity: opacity}
    end)
    |> Enum.filter(&(&1.opacity >= min_opacity))
  end

  defp calculate_opacity(age) do
    # Exponential decay formula
    max(0.0, :math.exp(-age * 0.15))
  end

  defp apply_point(buffer, %{position: {x, y}, opacity: opacity}, idx, config) do
    # Bounds check
    if x >= 0 and x < buffer.width and y >= 0 and y < buffer.height do
      char = select_char(idx, config.chars)
      color = select_color(idx, config.colors)
      style = create_style(color, opacity)

      # Get existing cell to preserve content if needed
      existing_cell = Buffer.get_cell(buffer, x, y)

      # Only apply if cell is empty or trail should override
      if existing_cell.char == " " or String.trim(existing_cell.char) == "" do
        Buffer.set_cell(buffer, x, y, char, style)
      else
        buffer
      end
    else
      buffer
    end
  end

  defp select_char(idx, chars) do
    char_idx = rem(idx, Kernel.length(chars))
    Enum.at(chars, char_idx)
  end

  defp select_color(idx, colors) do
    color_idx = rem(div(idx, 2), Kernel.length(colors))
    Enum.at(colors, color_idx)
  end

  defp create_style(color, opacity) do
    # Convert opacity to intensity (simplified for terminal)
    intensity =
      cond do
        opacity > 0.7 -> :bright
        opacity > 0.4 -> :normal
        true -> :dim
      end

    %{
      fg_color: color,
      intensity: intensity,
      bold: opacity > 0.8
    }
  end

  @doc """
  Create animated trail with multiple cursors.
  """
  @spec multi_cursor(list(position()), config()) :: t()
  def multi_cursor(positions, config \\ %{}) do
    trail = new(config)

    positions
    |> Enum.reduce(trail, fn pos, t ->
      update(t, pos)
    end)
  end

  @doc """
  Interpolate positions for smooth trail.

  Adds intermediate points between cursor positions for smoother trails.
  """
  @spec interpolate(t(), position(), position()) :: t()
  def interpolate(trail, from, to) do
    positions = bresenham_line(from, to)

    positions
    |> Enum.reduce(trail, fn pos, t ->
      update(t, pos)
    end)
  end

  # Bresenham's line algorithm for smooth interpolation
  defp bresenham_line({x0, y0}, {x1, y1}) do
    dx = abs(x1 - x0)
    dy = abs(y1 - y0)
    sx = if x0 < x1, do: 1, else: -1
    sy = if y0 < y1, do: 1, else: -1

    do_bresenham(x0, y0, x1, y1, dx, dy, sx, sy, dx - dy, [])
  end

  defp do_bresenham(x, y, x1, y1, _dx, _dy, _sx, _sy, _err, acc)
       when x == x1 and y == y1 do
    Enum.reverse([{x, y} | acc])
  end

  defp do_bresenham(x, y, x1, y1, dx, dy, sx, sy, err, acc) do
    e2 = 2 * err

    {new_x, new_err_x} =
      if e2 > -dy do
        {x + sx, err - dy}
      else
        {x, err}
      end

    {new_y, new_err_y} =
      if e2 < dx do
        {y + sy, new_err_x + dx}
      else
        {y, new_err_x}
      end

    do_bresenham(new_x, new_y, x1, y1, dx, dy, sx, sy, new_err_y, [{x, y} | acc])
  end

  @doc """
  Create rainbow trail effect.
  """
  @spec rainbow(config()) :: t()
  def rainbow(config \\ %{}) do
    rainbow_config =
      Map.merge(config, %{
        colors: [:red, :yellow, :green, :cyan, :blue, :magenta],
        chars: ["*", "*", "*", "*", "*", "*"],
        max_length: 24
      })

    new(rainbow_config)
  end

  @doc """
  Create minimal trail effect.
  """
  @spec minimal(config()) :: t()
  def minimal(config \\ %{}) do
    minimal_config =
      Map.merge(config, %{
        colors: [:white],
        chars: ["."],
        max_length: 5,
        decay_rate: 0.3
      })

    new(minimal_config)
  end

  @doc """
  Create comet trail effect (long fading tail).
  """
  @spec comet(config()) :: t()
  def comet(config \\ %{}) do
    comet_config =
      Map.merge(config, %{
        colors: [:white, :cyan, :blue],
        chars: ["*", "*", "+", "+", ".", ".", ":"],
        max_length: 30,
        decay_rate: 0.08,
        min_opacity: 0.05
      })

    new(comet_config)
  end

  @doc """
  Apply glow effect to current cursor position.
  """
  @spec apply_glow(Buffer.t(), position(), atom()) :: Buffer.t()
  def apply_glow(buffer, {x, y}, color \\ :cyan) do
    # Center glow
    buffer = apply_glow_point(buffer, {x, y}, color, 1.0)

    # Surrounding glow (8 directions)
    offsets = [
      {-1, -1},
      {0, -1},
      {1, -1},
      {-1, 0},
      {1, 0},
      {-1, 1},
      {0, 1},
      {1, 1}
    ]

    offsets
    |> Enum.reduce(buffer, fn {dx, dy}, buf ->
      apply_glow_point(buf, {x + dx, y + dy}, color, 0.3)
    end)
  end

  defp apply_glow_point(buffer, {x, y}, color, opacity) do
    if x >= 0 and x < buffer.width and y >= 0 and y < buffer.height do
      style = create_style(color, opacity)
      existing_cell = Buffer.get_cell(buffer, x, y)
      merged_style = Map.merge(existing_cell.style, style)
      Buffer.set_cell(buffer, x, y, existing_cell.char, merged_style)
    else
      buffer
    end
  end
end
