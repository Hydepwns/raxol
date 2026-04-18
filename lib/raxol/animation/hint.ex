defmodule Raxol.Animation.Hint do
  @moduledoc """
  Declarative animation hint metadata attached to view elements.

  Hints describe *what* is being animated so surface renderers can
  optionally accelerate rendering. For example, LiveView can emit CSS
  `transition` properties instead of re-rendering every frame server-side.

  The server always computes the correct frame via
  `Animation.Framework.apply_animations_to_state/1`. Hints are optional
  acceleration -- surfaces that don't understand them render the
  server-computed values as-is.

  CSS mapping functions delegate to `Raxol.Core.Animation.Hint` in
  raxol_core, eliminating duplication with TerminalBridge.
  """

  defstruct [
    :property,
    :from,
    :to,
    duration_ms: 300,
    easing: :ease_out_cubic,
    delay_ms: 0
  ]

  @type t :: %__MODULE__{
          property: atom(),
          from: any(),
          to: any(),
          duration_ms: non_neg_integer(),
          easing: atom(),
          delay_ms: non_neg_integer()
        }

  @doc """
  Maps a Raxol animation property to a CSS property name.

  Returns `nil` for properties that have no CSS equivalent.
  """
  defdelegate to_css_property(property), to: Raxol.Core.Animation.Hint

  @doc """
  Maps a Raxol easing atom to a CSS timing function string.
  """
  defdelegate to_css_timing(easing), to: Raxol.Core.Animation.Hint
end
