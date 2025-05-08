defmodule Raxol.Animation.Accessibility do
  @moduledoc """
  Handles accessibility concerns for the Animation Framework,
  specifically adapting animations for reduced motion preferences.
  """

  require Logger

  @doc """
  Adapts an animation definition based on reduced motion settings.

  Currently, it significantly shortens the duration to provide a near-instant transition.
  Alternative strategies include setting duration to 0 or changing animation type.
  """
  def adapt_for_reduced_motion(animation) do
    Logger.debug("[Animation] Adapting '#{animation.name}' for reduced motion.")
    # Use Map.put to avoid potential KeyError with struct-like maps
    adapted_with_duration = Map.put(animation, :duration, 10)
    Map.put(adapted_with_duration, :disabled, true)
    # Alternative: Snap to end state instantly
    # %{animation | duration: 0, from: animation.to}
    # Alternative: Mark as disabled (if other parts of the system check this flag)
    # %{animation | disabled: true}
  end

  @doc """
  Adapts an animation definition for cognitive accessibility by increasing its duration.

  This makes animations slower and potentially easier to follow.
  """
  def adapt_for_cognitive_accessibility(animation) do
    original_duration = animation.duration
    cognitive_duration = round(original_duration * 1.5)

    Logger.debug(
      "[Animation] Adapting '#{animation.name}' for cognitive accessibility. Duration: #{original_duration} -> #{cognitive_duration}."
    )

    Map.put(animation, :duration, cognitive_duration)
  end
end
