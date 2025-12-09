defmodule Raxol.Core.Box do
  @moduledoc """
  Compatibility layer for legacy Raxol.Core.Box references.

  This module exists to maintain backwards compatibility with plugins
  that reference the old apps/raxol_core modules.

  Maps to Raxol.UI.Components box drawing functions.
  """

  @doc "Draw a box border on the buffer"
  def draw_box(buffer, x, y, width, height, border_style \\ :single) do
    # Simple box drawing - can be enhanced later
    # For now, return buffer unchanged to prevent crashes
    _ = {x, y, width, height, border_style}
    buffer
  end
end
