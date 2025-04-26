defmodule Raxol.UI.Rendering.Pipeline do
  @moduledoc """
  Manages the rendering pipeline for the UI.
  """

  # TODO: Implement more rendering pipeline logic

  # --- Function Moved from Raxol.Terminal.Configuration ---

  @spec apply_animation_settings(
          atom() | nil,
          String.t() | nil,
          pos_integer(),
          boolean(),
          float(),
          float(),
          float(),
          :fit | :fill | :stretch
        ) :: :ok
  # Make public
  def apply_animation_settings(
        animation_type,
        animation_path,
        fps,
        loop,
        blend,
        opacity,
        blur,
        scale
      ) do
    # Store animation settings in the process dictionary (or send to relevant process)
    Process.put(:animation_settings, %{
      type: animation_type,
      path: animation_path,
      fps: fps,
      loop: loop,
      blend: blend,
      opacity: opacity,
      blur: blur,
      scale: scale
    })

    # TODO: This likely needs to communicate with the actual rendering process,
    # not just store in the current process's dictionary.
    :ok
  end
end

# --- Removed Function Moved from Raxol.Terminal.Configuration ---
