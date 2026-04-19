defmodule Raxol.Effects.BorderBeam.CSS do
  @moduledoc """
  LiveView CSS generation for the BorderBeam effect.

  Produces CSS that mirrors the original border-beam React component:
  conic-gradient beam stroke masked to the border, inner glow with blur,
  outer bloom with extended blur, and hue-rotate animation.
  """

  alias Raxol.Effects.BorderBeam.Colors

  @doc """
  Generates a CSS style block for the border beam effect on the given element.

  The element must have `data-raxol-id="{element_id}"` in the HTML.
  """
  @spec to_css(map(), String.t()) :: String.t()
  def to_css(config, element_id) do
    id = sanitize_id(element_id)
    variant = Map.get(config, :color_variant, :colorful)
    strength = Map.get(config, :strength, 0.8)
    duration = Map.get(config, :duration_ms, 2000) / 1000
    brightness = Map.get(config, :brightness, 1.3)
    saturation = Map.get(config, :saturation, 1.2)
    hue_range = Map.get(config, :hue_range, 30)
    size = Map.get(config, :size, :full)
    static = Map.get(config, :static_colors, false)
    active = Map.get(config, :active, true)

    opacity = if active, do: strength, else: 0

    gradient_stops = Colors.css_gradient_stops(variant)
    glow_hex = Colors.css_glow_hex(variant)
    bloom_hex = Colors.css_bloom_hex(variant)

    sections = [
      property_declaration(id),
      keyframes(id, hue_range, brightness, saturation, static),
      beam_stroke_css(
        id,
        gradient_stops,
        duration,
        opacity,
        brightness,
        saturation,
        size
      ),
      inner_glow_css(id, glow_hex, duration, opacity, size),
      bloom_css(id, bloom_hex, duration, opacity, size),
      reduced_motion_css(id)
    ]

    Enum.join(sections, "\n")
  end

  @doc """
  Returns an animation hint map for the border beam effect,
  suitable for inclusion in element animation_hints.
  """
  @spec to_hint(map()) :: %{
          type: :border_beam,
          variant: atom(),
          size: atom(),
          strength: float(),
          duration_ms: pos_integer(),
          brightness: float(),
          saturation: float(),
          hue_range: non_neg_integer(),
          active: boolean(),
          static_colors: boolean()
        }
  def to_hint(config) do
    %{
      type: :border_beam,
      variant: Map.get(config, :color_variant, :colorful),
      size: Map.get(config, :size, :full),
      strength: Map.get(config, :strength, 0.8),
      duration_ms: Map.get(config, :duration_ms, 2000),
      brightness: Map.get(config, :brightness, 1.3),
      saturation: Map.get(config, :saturation, 1.2),
      hue_range: Map.get(config, :hue_range, 30),
      active: Map.get(config, :active, true),
      static_colors: Map.get(config, :static_colors, false)
    }
  end

  # -- Private CSS generators --

  defp property_declaration(id) do
    """
    @property --bb-angle-#{id} {
      syntax: "<angle>";
      initial-value: 0deg;
      inherits: false;
    }
    """
  end

  defp keyframes(id, hue_range, brightness, saturation, static) do
    spin = """
    @keyframes bb-spin-#{id} {
      to { --bb-angle-#{id}: 360deg; }
    }
    """

    hue =
      if static do
        ""
      else
        """
        @keyframes bb-hue-#{id} {
          0% { filter: brightness(#{brightness}) saturate(#{saturation}) hue-rotate(0deg); }
          100% { filter: brightness(#{brightness}) saturate(#{saturation}) hue-rotate(#{hue_range}deg); }
        }
        """
      end

    spin <> hue
  end

  defp beam_stroke_css(
         id,
         gradient_stops,
         duration,
         opacity,
         brightness,
         saturation,
         size
       ) do
    sel = "[data-raxol-id=\"#{id}\"]::after"
    gradient = gradient_fn(size, gradient_stops, id)

    """
    #{sel} {
      content: "";
      position: absolute;
      inset: 0;
      border-radius: inherit;
      padding: 2px;
      background: #{gradient};
      -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
      -webkit-mask-composite: xor;
      mask-composite: exclude;
      animation: bb-spin-#{id} #{duration}s linear infinite;
      opacity: #{opacity};
      pointer-events: none;
      filter: brightness(#{brightness}) saturate(#{saturation});
    }
    """
  end

  defp inner_glow_css(_id, _glow_hex, _duration, _opacity, :compact), do: ""

  defp inner_glow_css(id, glow_hex, duration, opacity, _size) do
    sel = "[data-raxol-id=\"#{id}\"]::before"
    glow_opacity = Float.round(opacity * 0.4, 2)

    """
    #{sel} {
      content: "";
      position: absolute;
      inset: 2px;
      border-radius: inherit;
      background: conic-gradient(from var(--bb-angle-#{id}), transparent 0%, #{glow_hex}22 10%, transparent 25%);
      filter: blur(4px);
      opacity: #{glow_opacity};
      animation: bb-spin-#{id} #{duration}s linear infinite;
      pointer-events: none;
    }
    """
  end

  defp bloom_css(_id, _bloom_hex, _duration, _opacity, size)
       when size in [:compact, :line],
       do: ""

  defp bloom_css(id, bloom_hex, duration, opacity, _size) do
    sel = "[data-raxol-id=\"#{id}\"] > [data-beam-bloom]"
    bloom_opacity = Float.round(opacity * 0.3, 2)

    """
    #{sel} {
      position: absolute;
      inset: -4px;
      border-radius: inherit;
      background: conic-gradient(from var(--bb-angle-#{id}), transparent 0%, #{bloom_hex}15 8%, transparent 20%);
      filter: blur(8px);
      opacity: #{bloom_opacity};
      animation: bb-spin-#{id} #{duration}s linear infinite;
      pointer-events: none;
    }
    """
  end

  defp reduced_motion_css(id) do
    """
    @media (prefers-reduced-motion: reduce) {
      [data-raxol-id="#{id}"]::after {
        animation-duration: 0.01ms !important;
      }
    }
    """
  end

  defp gradient_fn(:line, stops, _id) do
    "linear-gradient(90deg, #{stops})"
  end

  defp gradient_fn(_size, stops, id) do
    "conic-gradient(from var(--bb-angle-#{id}), #{stops})"
  end

  defp sanitize_id(id) do
    String.replace(id, ~r/[^a-zA-Z0-9_-]/, "_")
  end
end
