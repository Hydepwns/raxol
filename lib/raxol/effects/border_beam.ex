defmodule Raxol.Effects.BorderBeam do
  @moduledoc """
  Animated border beam effect for terminal interfaces.

  Creates a traveling glow that orbits around an element's border,
  mirroring the border-beam React component. Three visual layers:

  1. **Beam stroke** -- bright colored highlight traveling clockwise
  2. **Inner glow** -- muted background color inside the border at the beam head
  3. **Outer bloom** -- dim foreground bleed outside the border at the beam head

  ## Example

      beam = BorderBeam.new(color_variant: :ocean, duration_ms: 2000)
      beam = BorderBeam.set_bounds(beam, %{x: 5, y: 2, width: 30, height: 10})

      # In your tick handler (30 FPS):
      beam = BorderBeam.update(beam)
      buffer = BorderBeam.apply(beam, buffer)

  ## Configuration

      BorderBeam.new(
        size: :full,             # :full | :compact | :line
        color_variant: :colorful, # :colorful | :mono | :ocean | :sunset
        strength: 0.8,           # 0.0-1.0 overall intensity
        duration_ms: 2000,       # ms for one full orbit
        trail_length: 0.25,      # fraction of perimeter the trail covers
        fade_ms: 300,            # fade in/out transition time
        static_colors: false     # disables color cycling when true
      )
  """

  alias Raxol.Core.Buffer
  alias Raxol.Effects.BorderBeam.Colors

  @type size :: :full | :compact | :line
  @type bounds :: %{
          x: integer(),
          y: integer(),
          width: integer(),
          height: integer()
        }

  @type config :: %{
          size: size(),
          color_variant: Colors.variant(),
          strength: float(),
          duration_ms: pos_integer(),
          brightness: float(),
          saturation: float(),
          hue_range: non_neg_integer(),
          border_style: atom(),
          fade_ms: pos_integer(),
          trail_length: float(),
          static_colors: boolean(),
          enabled: boolean()
        }

  @type t :: %__MODULE__{
          bounds: bounds() | nil,
          perimeter: [{integer(), integer()}],
          config: config(),
          active: boolean(),
          fade_start: integer() | nil,
          started_at: integer() | nil,
          last_update: integer() | nil
        }

  defstruct bounds: nil,
            perimeter: [],
            config: %{
              size: :full,
              color_variant: :colorful,
              strength: 0.8,
              duration_ms: 2000,
              brightness: 1.3,
              saturation: 1.2,
              hue_range: 30,
              border_style: :single,
              fade_ms: 300,
              trail_length: 0.25,
              static_colors: false,
              enabled: true
            },
            active: true,
            fade_start: nil,
            started_at: nil,
            last_update: nil

  @default_config %{
    size: :full,
    color_variant: :colorful,
    strength: 0.8,
    duration_ms: 2000,
    brightness: 1.3,
    saturation: 1.2,
    hue_range: 30,
    border_style: :single,
    fade_ms: 300,
    trail_length: 0.25,
    static_colors: false,
    enabled: true
  }

  # -- Public API --

  @doc "Creates a new BorderBeam effect with the given options."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    now = System.monotonic_time(:millisecond)

    config =
      Enum.reduce(opts, @default_config, fn {k, v}, acc ->
        Map.put(acc, k, v)
      end)

    %__MODULE__{
      config: config,
      active: Keyword.get(opts, :active, true),
      started_at: now,
      last_update: now
    }
  end

  @doc "Sets the target bounds and computes the perimeter path."
  @spec set_bounds(t(), bounds()) :: t()
  def set_bounds(%__MODULE__{} = effect, bounds) do
    perimeter = compute_perimeter(bounds, effect.config.size)
    %__MODULE__{effect | bounds: bounds, perimeter: perimeter}
  end

  @doc "Toggles active state with fade transition."
  @spec set_active(t(), boolean()) :: t()
  def set_active(%__MODULE__{active: true} = effect, false) do
    %__MODULE__{
      effect
      | active: false,
        fade_start: System.monotonic_time(:millisecond)
    }
  end

  def set_active(%__MODULE__{active: false} = effect, true) do
    %__MODULE__{
      effect
      | active: true,
        fade_start: nil,
        started_at: System.monotonic_time(:millisecond)
    }
  end

  def set_active(effect, _), do: effect

  @doc "Updates timing state. Call each frame."
  @spec update(t(), integer()) :: t()
  def update(effect, now_ms \\ System.monotonic_time(:millisecond))

  def update(%__MODULE__{config: %{enabled: false}} = effect, _now_ms),
    do: effect

  def update(%__MODULE__{} = effect, now_ms) do
    %__MODULE__{effect | last_update: now_ms}
  end

  @doc "Updates config fields. Recomputes perimeter if size changed."
  @spec update_config(t(), keyword()) :: t()
  def update_config(%__MODULE__{} = effect, opts) do
    old_size = effect.config.size

    config =
      Enum.reduce(opts, effect.config, fn {k, v}, acc -> Map.put(acc, k, v) end)

    effect = %__MODULE__{effect | config: config}

    if config.size != old_size and effect.bounds do
      %__MODULE__{
        effect
        | perimeter: compute_perimeter(effect.bounds, config.size)
      }
    else
      effect
    end
  end

  @doc "Returns true if the effect is currently rendering (active or mid-fade)."
  @spec visible?(t()) :: boolean()
  def visible?(%__MODULE__{config: %{enabled: false}}), do: false
  def visible?(%__MODULE__{active: true}), do: true

  def visible?(%__MODULE__{active: false, fade_start: nil}), do: false

  def visible?(%__MODULE__{
        active: false,
        fade_start: start,
        last_update: now,
        config: config
      }) do
    now != nil and now - start < config.fade_ms
  end

  @doc """
  Renders the three beam layers onto the buffer.

  Layer order: bloom (lowest) -> inner glow -> beam stroke (highest).
  Only modifies cell styles, never replaces characters.
  """
  @spec apply(t(), map()) :: map()
  def apply(%__MODULE__{config: %{enabled: false}}, buffer), do: buffer
  def apply(%__MODULE__{bounds: nil}, buffer), do: buffer
  def apply(%__MODULE__{perimeter: []}, buffer), do: buffer

  def apply(%__MODULE__{} = effect, buffer) do
    if visible?(effect) do
      do_apply(effect, buffer)
    else
      buffer
    end
  end

  # -- Private: Rendering --

  defp do_apply(effect, buffer) do
    perimeter = effect.perimeter
    p_len = length(perimeter)

    if p_len == 0, do: throw(:empty_perimeter)

    now = effect.last_update || System.monotonic_time(:millisecond)
    elapsed = now - (effect.started_at || now)

    progress =
      rem(elapsed, effect.config.duration_ms) / effect.config.duration_ms

    head_idx = trunc(progress * p_len) |> rem(p_len)

    effective_strength = compute_effective_strength(effect, now)

    if effective_strength <= 0.0 do
      buffer
    else
      config = effect.config
      variant = config.color_variant
      trail_cells = trunc(config.trail_length * p_len) |> max(1)

      buffer
      |> apply_bloom(effect, perimeter, head_idx, variant, effective_strength)
      |> apply_inner_glow(
        effect,
        perimeter,
        head_idx,
        variant,
        effective_strength
      )
      |> apply_beam_stroke(
        perimeter,
        head_idx,
        trail_cells,
        progress,
        config,
        effective_strength
      )
    end
  end

  # Layer 3: Outer bloom -- dim color 1 cell outside border at beam head
  defp apply_bloom(buffer, %{config: %{size: size}}, _peri, _head, _var, _str)
       when size in [:compact, :line],
       do: buffer

  defp apply_bloom(buffer, _effect, perimeter, head_idx, variant, strength) do
    {hx, hy} = Enum.at(perimeter, head_idx)
    bloom_color = Colors.bloom_color(variant)
    bloom_offsets = outer_offsets(perimeter, head_idx)

    Enum.reduce(bloom_offsets, buffer, fn {ox, oy}, buf ->
      x = hx + ox
      y = hy + oy

      if in_bounds?(buf, x, y) do
        cell = Buffer.get_cell(buf, x, y)
        char = Map.get(cell, :char, " ")
        style = Map.get(cell, :style, %{})

        new_style =
          if strength > 0.5 do
            Map.merge(style, %{fg_color: bloom_color, bold: false})
          else
            Map.put(style, :fg_color, bloom_color)
          end

        Buffer.set_cell(buf, x, y, char, new_style)
      else
        buf
      end
    end)
  end

  # Layer 2: Inner glow -- muted bg color 1 cell inside border near beam head
  defp apply_inner_glow(
         buffer,
         %{config: %{size: size}},
         _peri,
         _head,
         _var,
         _str
       )
       when size == :compact,
       do: buffer

  defp apply_inner_glow(
         buffer,
         _effect,
         perimeter,
         head_idx,
         variant,
         _strength
       ) do
    glow_c = Colors.glow_color(variant)
    p_len = length(perimeter)

    # Apply glow at head and 1 neighbor on each side
    for offset <- -1..1, reduce: buffer do
      buf ->
        idx = rem(head_idx + offset + p_len, p_len)
        {hx, hy} = Enum.at(perimeter, idx)
        inner = inner_offsets(perimeter, idx)

        Enum.reduce(inner, buf, fn {ox, oy}, b ->
          x = hx + ox
          y = hy + oy

          if in_bounds?(b, x, y) do
            cell = Buffer.get_cell(b, x, y)
            char = Map.get(cell, :char, " ")
            style = Map.get(cell, :style, %{})
            Buffer.set_cell(b, x, y, char, Map.put(style, :bg_color, glow_c))
          else
            b
          end
        end)
    end
  end

  # Layer 1: Beam stroke -- bright trail along border
  defp apply_beam_stroke(
         buffer,
         perimeter,
         head_idx,
         trail_cells,
         progress,
         config,
         strength
       ) do
    p_len = length(perimeter)
    variant = config.color_variant
    static = config.static_colors

    Enum.reduce(0..(trail_cells - 1), buffer, fn dist, buf ->
      idx = rem(head_idx - dist + p_len, p_len)
      {x, y} = Enum.at(perimeter, idx)

      if in_bounds?(buf, x, y) do
        opacity = :math.exp(-dist * 4.0 / trail_cells) * strength

        color =
          if dist == 0 do
            Colors.beam_color(variant, progress, static)
          else
            Colors.trail_color(variant, dist / trail_cells)
          end

        {intensity, bold} = opacity_to_style(opacity)

        cell = Buffer.get_cell(buf, x, y)
        char = Map.get(cell, :char, " ")
        style = Map.get(cell, :style, %{})

        new_style =
          Map.merge(style, %{fg_color: color, bold: bold, intensity: intensity})

        Buffer.set_cell(buf, x, y, char, new_style)
      else
        buf
      end
    end)
  end

  # -- Private: Perimeter Path --

  @doc false
  @spec compute_perimeter(bounds(), size()) :: [{integer(), integer()}]
  def compute_perimeter(%{x: bx, y: by, width: w, height: h}, :line)
      when w >= 3 do
    for x <- bx..(bx + w - 1), do: {x, by + h - 1}
  end

  def compute_perimeter(%{x: bx, y: by, width: w, height: h}, _size)
      when w >= 3 and h >= 3 do
    top = for x <- bx..(bx + w - 1), do: {x, by}
    right = for y <- (by + 1)..(by + h - 1), do: {bx + w - 1, y}
    bottom = for x <- (bx + w - 2)..bx//-1, do: {x, by + h - 1}
    left = for y <- (by + h - 2)..(by + 1)//-1, do: {bx, y}
    top ++ right ++ bottom ++ left
  end

  def compute_perimeter(_bounds, _size), do: []

  # -- Private: Helpers --

  defp compute_effective_strength(effect, now) do
    base = effect.config.strength

    cond do
      effect.active ->
        base

      effect.fade_start == nil ->
        0.0

      true ->
        elapsed = now - effect.fade_start
        fade_ms = effect.config.fade_ms

        if elapsed >= fade_ms do
          0.0
        else
          base * (1.0 - elapsed / fade_ms)
        end
    end
  end

  defp opacity_to_style(opacity) do
    intensity =
      cond do
        opacity > 0.7 -> :bright
        opacity > 0.4 -> :normal
        true -> :dim
      end

    bold = opacity >= 0.8
    {intensity, bold}
  end

  defp in_bounds?(buffer, x, y) do
    x >= 0 and y >= 0 and x < Map.get(buffer, :width, 0) and
      y < Map.get(buffer, :height, 0)
  end

  # Compute 1-cell offset pointing outward from the border at the given index
  defp outer_offsets(perimeter, idx) do
    p_len = length(perimeter)
    {x, y} = Enum.at(perimeter, idx)

    prev_idx = rem(idx - 1 + p_len, p_len)
    next_idx = rem(idx + 1, p_len)
    {px, py} = Enum.at(perimeter, prev_idx)
    {nx, ny} = Enum.at(perimeter, next_idx)

    # Average direction from neighbors, then negate for outward
    dx = (px + nx) / 2 - x
    dy = (py + ny) / 2 - y

    # Outward is opposite of inward direction
    ox = if dx > 0, do: -1, else: if(dx < 0, do: 1, else: 0)
    oy = if dy > 0, do: -1, else: if(dy < 0, do: 1, else: 0)

    if ox == 0 and oy == 0, do: [], else: [{ox, oy}]
  end

  # Compute 1-cell offset pointing inward from the border
  defp inner_offsets(perimeter, idx) do
    case outer_offsets(perimeter, idx) do
      [{ox, oy}] -> [{-ox, -oy}]
      [] -> []
    end
  end
end
