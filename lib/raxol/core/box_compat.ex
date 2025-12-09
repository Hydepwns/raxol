defmodule Raxol.Core.Box do
  @moduledoc """
  Compatibility layer for legacy Raxol.Core.Box references.

  This module exists to maintain backwards compatibility with plugins
  that reference the old apps/raxol_core modules.

  Returns buffer unchanged (stub implementation).
  """

  @doc "Draw a box border on the buffer (stub)"
  def draw_box(buffer, _x, _y, _width, _height, _border_style \\ :single) do
    buffer
  end

  @doc "Fill area with character (stub)"
  def fill_area(buffer, _x, _y, _width, _height, _char, _style) do
    buffer
  end
end
