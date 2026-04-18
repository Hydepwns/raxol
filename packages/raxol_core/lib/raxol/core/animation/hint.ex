defmodule Raxol.Core.Animation.Hint do
  @moduledoc """
  CSS mapping functions for animation hints.

  Provides the canonical CSS property and timing function mappings
  used by both the main animation framework (`Raxol.Animation.Hint`)
  and the LiveView bridge (`Raxol.LiveView.TerminalBridge`).

  This module lives in raxol_core so that raxol_liveview can depend
  on it without pulling in the full raxol package.
  """

  @doc """
  Maps a Raxol animation property to a CSS property name.

  Returns `nil` for properties that have no CSS equivalent.
  """
  @spec to_css_property(atom()) :: String.t() | nil
  def to_css_property(:opacity), do: "opacity"
  def to_css_property(:color), do: "color"
  def to_css_property(:fg), do: "color"
  def to_css_property(:bg_color), do: "background-color"
  def to_css_property(:bg), do: "background-color"
  def to_css_property(:width), do: "width"
  def to_css_property(:height), do: "height"
  def to_css_property(:transform), do: "transform"
  def to_css_property(_), do: nil

  @doc """
  Maps a Raxol easing atom to a CSS timing function string.

  All 30+ easing functions are mapped to their `cubic-bezier()` equivalents.
  Easing names that cannot be expressed as cubic-bezier (bounce, elastic)
  fall back to `"linear"` since CSS cannot natively represent them.
  """
  @spec to_css_timing(atom()) :: String.t()
  # Linear
  def to_css_timing(:linear), do: "linear"

  # Quadratic
  def to_css_timing(:ease_in_quad), do: "cubic-bezier(0.55, 0.085, 0.68, 0.53)"
  def to_css_timing(:ease_out_quad), do: "cubic-bezier(0.25, 0.46, 0.45, 0.94)"

  def to_css_timing(:ease_in_out_quad),
    do: "cubic-bezier(0.455, 0.03, 0.515, 0.955)"

  # Cubic
  def to_css_timing(:ease_in_cubic), do: "cubic-bezier(0.55, 0.055, 0.675, 0.19)"
  def to_css_timing(:ease_out_cubic), do: "cubic-bezier(0.215, 0.61, 0.355, 1)"

  def to_css_timing(:ease_in_out_cubic),
    do: "cubic-bezier(0.645, 0.045, 0.355, 1)"

  # Quartic
  def to_css_timing(:ease_in_quart), do: "cubic-bezier(0.895, 0.03, 0.685, 0.22)"
  def to_css_timing(:ease_out_quart), do: "cubic-bezier(0.165, 0.84, 0.44, 1)"

  def to_css_timing(:ease_in_out_quart),
    do: "cubic-bezier(0.77, 0, 0.175, 1)"

  # Quintic
  def to_css_timing(:ease_in_quint), do: "cubic-bezier(0.755, 0.05, 0.855, 0.06)"
  def to_css_timing(:ease_out_quint), do: "cubic-bezier(0.23, 1, 0.32, 1)"

  def to_css_timing(:ease_in_out_quint),
    do: "cubic-bezier(0.86, 0, 0.07, 1)"

  # Sine
  def to_css_timing(:ease_in_sine), do: "cubic-bezier(0.47, 0, 0.745, 0.715)"
  def to_css_timing(:ease_out_sine), do: "cubic-bezier(0.39, 0.575, 0.565, 1)"

  def to_css_timing(:ease_in_out_sine),
    do: "cubic-bezier(0.445, 0.05, 0.55, 0.95)"

  # Exponential
  def to_css_timing(:ease_in_expo), do: "cubic-bezier(0.95, 0.05, 0.795, 0.035)"
  def to_css_timing(:ease_out_expo), do: "cubic-bezier(0.19, 1, 0.22, 1)"

  def to_css_timing(:ease_in_out_expo),
    do: "cubic-bezier(1, 0, 0, 1)"

  # Circular
  def to_css_timing(:ease_in_circ), do: "cubic-bezier(0.6, 0.04, 0.98, 0.335)"
  def to_css_timing(:ease_out_circ), do: "cubic-bezier(0.075, 0.82, 0.165, 1)"

  def to_css_timing(:ease_in_out_circ),
    do: "cubic-bezier(0.785, 0.135, 0.15, 0.86)"

  # Back
  def to_css_timing(:ease_in_back), do: "cubic-bezier(0.6, -0.28, 0.735, 0.045)"
  def to_css_timing(:ease_out_back), do: "cubic-bezier(0.175, 0.885, 0.32, 1.275)"

  def to_css_timing(:ease_in_out_back),
    do: "cubic-bezier(0.68, -0.55, 0.265, 1.55)"

  # Aliases
  def to_css_timing(:ease_in), do: to_css_timing(:ease_in_quad)
  def to_css_timing(:ease_out), do: to_css_timing(:ease_out_quad)
  def to_css_timing(:ease_in_out), do: to_css_timing(:ease_in_out_quad)

  # Bounce and elastic cannot be expressed as cubic-bezier
  def to_css_timing(_), do: "linear"
end
