defmodule Raxol.Effects.CursorTrail do
  @moduledoc """
  Visual cursor trail for terminal interfaces.

  Tracks recent cursor positions and renders a fading trail behind the
  current cursor. Useful for drawing attention to cursor movement,
  visualising input, or just adding aesthetic weight to a TUI cockpit.

  ## Example

      trail = CursorTrail.new(max_length: 10)
      trail = CursorTrail.update(trail, {5, 10})
      trail = CursorTrail.update(trail, {6, 10})
      trail = CursorTrail.update(trail, {7, 10})

      buffer = CursorTrail.apply(trail, buffer)

  ## Configuration

      config = %{
        max_length: 20,           # Maximum trail positions to track
        decay_rate: 0.15,         # Exponential opacity decay per tick
        colors: [:cyan, :blue, :magenta],
        chars: ["*", "+", "."],   # Characters cycled along the trail
        min_opacity: 0.1,         # Drop points below this opacity
        overwrite_text: false,    # Paint over non-space cells if true
        enabled: true
      }

      trail = CursorTrail.new(config)

  ## Presets

  - `rainbow/1` -- 6-color rainbow cycle, length 24
  - `comet/1`   -- long fading white-to-blue tail
  - `minimal/1` -- 5-cell single-color trail
  - `electric/1`/`neon/1`/`matrix/1` -- presets aligned with the
    `Raxol.Effects.BorderBeam` palette family
  """

  alias Raxol.Core.Buffer

  @type position :: {integer(), integer()}

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
          optional(:overwrite_text) => boolean(),
          optional(:enabled) => boolean()
        }

  @type t :: %__MODULE__{
          points: list(trail_point()),
          config: config(),
          tick: non_neg_integer()
        }

  defstruct points: [], config: %{}, tick: 0

  @default_config %{
    max_length: 15,
    decay_rate: 0.12,
    colors: [:cyan, :blue, :magenta, :white],
    chars: ["*", "+", ".", ":"],
    min_opacity: 0.15,
    overwrite_text: false,
    enabled: true
  }

  @doc "Create a new cursor trail."
  @spec new(config()) :: t()
  def new(config \\ %{}) do
    %__MODULE__{config: Map.merge(@default_config, config)}
  end

  @doc "Append a position to the trail (or age existing points if unchanged)."
  @spec update(t(), position()) :: t()
  def update(%{config: %{enabled: false}} = trail, _position), do: trail

  def update(%{points: points, config: config, tick: tick} = trail, position) do
    decay = Map.get(config, :decay_rate, 0.12)
    min_op = Map.get(config, :min_opacity, 0.15)
    max_len = Map.get(config, :max_length, 15)

    new_points =
      case points do
        [%{position: ^position} | _] ->
          age_and_filter(points, decay, min_op)

        _ ->
          point = %{position: position, age: 0, opacity: 1.0}
          [point | age_and_filter(points, decay, min_op)] |> Enum.take(max_len)
      end

    %{trail | points: new_points, tick: tick + 1}
  end

  @doc "Apply the trail's current points to a buffer."
  @spec apply(t(), Buffer.t()) :: Buffer.t()
  def apply(%{config: %{enabled: false}}, buffer), do: buffer
  def apply(%{points: []}, buffer), do: buffer

  def apply(%{points: points, config: config}, buffer) do
    chars_tup = List.to_tuple(Map.get(config, :chars, ["*"]))
    colors_tup = List.to_tuple(Map.get(config, :colors, [:white]))
    chars_len = max(tuple_size(chars_tup), 1)
    colors_len = max(tuple_size(colors_tup), 1)
    overwrite = Map.get(config, :overwrite_text, false)

    # Single pass: walk newest -> oldest (current order), index from 0.
    {result, _} =
      Enum.reduce(points, {buffer, 0}, fn point, {buf, idx} ->
        char = elem(chars_tup, rem(idx, chars_len))
        color = elem(colors_tup, rem(idx, colors_len))
        {apply_point(buf, point, char, color, overwrite), idx + 1}
      end)

    result
  end

  @doc "Drop all points (preserves config)."
  @spec clear(t()) :: t()
  def clear(trail), do: %{trail | points: [], tick: 0}

  @doc "Enable or disable the effect."
  @spec set_enabled(t(), boolean()) :: t()
  def set_enabled(trail, enabled), do: put_in(trail.config.enabled, enabled)

  @doc "Merge new config keys into the existing config."
  @spec update_config(t(), config()) :: t()
  def update_config(%{config: current} = trail, new_config) do
    %{trail | config: Map.merge(current, new_config)}
  end

  @doc "Number of currently visible points."
  @spec length(t()) :: non_neg_integer()
  def length(%{points: points}), do: Kernel.length(points)

  @doc "Trail statistics: point_count, max_length, enabled, tick, average_opacity."
  @spec stats(t()) :: map()
  def stats(%{points: points, config: config, tick: tick}) do
    count = Kernel.length(points)

    avg =
      if count == 0,
        do: 0.0,
        else: Enum.sum(Enum.map(points, & &1.opacity)) / count

    %{
      point_count: count,
      max_length: config.max_length,
      enabled: config.enabled,
      tick: tick,
      average_opacity: avg
    }
  end

  @doc "Build a trail seeded with multiple positions."
  @spec multi_cursor(list(position()), config()) :: t()
  def multi_cursor(positions, config \\ %{}) do
    Enum.reduce(positions, new(config), &update(&2, &1))
  end

  @doc """
  Append the points along the line `from -> to` to the trail. Uses
  Bresenham's algorithm to fill in intermediate cells so a single jump
  produces a smooth trail.
  """
  @spec interpolate(t(), position(), position()) :: t()
  def interpolate(trail, from, to) do
    Enum.reduce(bresenham_line(from, to), trail, &update(&2, &1))
  end

  # -- Presets --

  @doc "Six-color rainbow cycle, length 24."
  @spec rainbow(config()) :: t()
  def rainbow(config \\ %{}) do
    config
    |> Map.merge(%{
      colors: [:red, :yellow, :green, :cyan, :blue, :magenta],
      chars: ["*", "*", "*", "*", "*", "*"],
      max_length: 24
    })
    |> new()
  end

  @doc "Subtle five-cell white trail with quick decay."
  @spec minimal(config()) :: t()
  def minimal(config \\ %{}) do
    config
    |> Map.merge(%{
      colors: [:white],
      chars: ["."],
      max_length: 5,
      decay_rate: 0.30
    })
    |> new()
  end

  @doc "Long white-to-blue fading tail with tapered chars."
  @spec comet(config()) :: t()
  def comet(config \\ %{}) do
    config
    |> Map.merge(%{
      colors: [:white, :cyan, :blue],
      chars: ["*", "*", "+", "+", ".", ".", ":"],
      max_length: 30,
      decay_rate: 0.08,
      min_opacity: 0.05
    })
    |> new()
  end

  @doc "Bright yellow/cyan crackle, matches BorderBeam `:electric`."
  @spec electric(config()) :: t()
  def electric(config \\ %{}) do
    config
    |> Map.merge(%{
      colors: [:bright_yellow, :bright_cyan, :bright_white, :cyan],
      chars: ["+", "*", "x", "."],
      max_length: 14,
      decay_rate: 0.18
    })
    |> new()
  end

  @doc "Magenta/cyan vapor, matches BorderBeam `:neon`."
  @spec neon(config()) :: t()
  def neon(config \\ %{}) do
    config
    |> Map.merge(%{
      colors: [:bright_magenta, :bright_cyan, :magenta, :bright_blue],
      chars: ["*", "+", "."],
      max_length: 18,
      decay_rate: 0.10
    })
    |> new()
  end

  @doc "Green-on-green digital rain, matches BorderBeam `:matrix`."
  @spec matrix(config()) :: t()
  def matrix(config \\ %{}) do
    config
    |> Map.merge(%{
      colors: [:bright_green, :green, :bright_black],
      chars: ["1", "0", "$", "#"],
      max_length: 20,
      decay_rate: 0.13
    })
    |> new()
  end

  @doc """
  Apply a fixed glow halo around a single position. Independent of trail
  state -- useful for highlighting an active cursor without history.
  """
  @spec apply_glow(Buffer.t(), position(), atom()) :: Buffer.t()
  def apply_glow(buffer, {x, y}, color \\ :cyan) do
    halo = [
      {0, 0, 1.0},
      {-1, -1, 0.3},
      {0, -1, 0.3},
      {1, -1, 0.3},
      {-1, 0, 0.3},
      {1, 0, 0.3},
      {-1, 1, 0.3},
      {0, 1, 0.3},
      {1, 1, 0.3}
    ]

    Enum.reduce(halo, buffer, fn {dx, dy, opacity}, buf ->
      paint_glow(buf, x + dx, y + dy, color, opacity)
    end)
  end

  # -- Private --

  defp age_and_filter(points, decay_rate, min_opacity) do
    points
    |> Enum.map(fn point ->
      age = point.age + 1
      %{point | age: age, opacity: opacity_for(age, decay_rate)}
    end)
    |> Enum.filter(&(&1.opacity >= min_opacity))
  end

  defp opacity_for(age, decay_rate), do: max(0.0, :math.exp(-age * decay_rate))

  defp apply_point(
         buffer,
         %{position: {x, y}, opacity: opacity},
         char,
         color,
         overwrite
       ) do
    cond do
      not in_bounds?(buffer, x, y) ->
        buffer

      not overwrite and not blank_cell?(buffer, x, y) ->
        buffer

      true ->
        Buffer.set_cell(buffer, x, y, char, opacity_style(color, opacity))
    end
  end

  defp blank_cell?(buffer, x, y) do
    case Buffer.get_cell(buffer, x, y) do
      %{char: char} -> char == " " or String.trim(char) == ""
      _ -> true
    end
  end

  defp in_bounds?(buffer, x, y) do
    x >= 0 and y >= 0 and x < Map.get(buffer, :width, 0) and
      y < Map.get(buffer, :height, 0)
  end

  defp opacity_style(color, opacity) do
    attrs = opacity_attrs(opacity)
    %{fg_color: color, bold: opacity > 0.8, attrs: attrs}
  end

  defp opacity_attrs(opacity) when opacity >= 0.65, do: [:bold]
  defp opacity_attrs(opacity) when opacity >= 0.25, do: []
  defp opacity_attrs(_opacity), do: [:dim]

  defp paint_glow(buffer, x, y, color, opacity) do
    if in_bounds?(buffer, x, y) do
      cell = Buffer.get_cell(buffer, x, y)
      base_style = Map.get(cell, :style, %{})
      merged = Map.merge(base_style, opacity_style(color, opacity))
      Buffer.set_cell(buffer, x, y, Map.get(cell, :char, " "), merged)
    else
      buffer
    end
  end

  # Bresenham's line algorithm.
  defp bresenham_line({x0, y0}, {x1, y1}) do
    dx = abs(x1 - x0)
    dy = abs(y1 - y0)
    params = %{dx: dx, dy: dy, sx: sign(x0, x1), sy: sign(y0, y1)}
    do_bresenham({x0, y0}, {x1, y1}, params, dx - dy, [])
  end

  defp sign(from, to) when from < to, do: 1
  defp sign(_, _), do: -1

  defp do_bresenham({x, y}, {x, y}, _params, _err, acc) do
    Enum.reverse([{x, y} | acc])
  end

  defp do_bresenham({x, y}, target, params, err, acc) do
    e2 = 2 * err

    {x1, err1} =
      if e2 > -params.dy, do: {x + params.sx, err - params.dy}, else: {x, err}

    {y1, err2} =
      if e2 < params.dx, do: {y + params.sy, err1 + params.dx}, else: {y, err1}

    do_bresenham({x1, y1}, target, params, err2, [{x, y} | acc])
  end
end
