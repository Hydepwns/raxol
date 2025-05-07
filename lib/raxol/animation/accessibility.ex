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
    # For simplicity, just shorten duration significantly
    %{animation | duration: 10} # Very short duration
    # Alternative: Snap to end state instantly
    # %{animation | duration: 0, from: animation.to}
    # Alternative: Mark as disabled (if other parts of the system check this flag)
    # %{animation | disabled: true}
  end
end
