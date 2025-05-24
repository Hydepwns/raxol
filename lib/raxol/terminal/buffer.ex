defmodule Raxol.Terminal.Buffer do
  @moduledoc """
  Delegating module for terminal buffer operations. Provides a unified API and delegates to the appropriate submodules.
  """

  # Delegate to Operations, Manager, Eraser, etc. as appropriate

  defdelegate new(arg1, arg2), to: Raxol.Terminal.Buffer.Manager
  defdelegate get_cell(buffer, x, y), to: Raxol.Terminal.Buffer.Manager
  defdelegate set_cell(buffer, x, y, cell), to: Raxol.Terminal.Buffer.Manager

  defdelegate fill_region(buffer, x1, y1, x2, y2, cell),
    to: Raxol.Terminal.Buffer.Manager

  defdelegate copy_region(buffer, x1, y1, x2, y2, dest_x, dest_y),
    to: Raxol.Terminal.Buffer.Manager

  defdelegate scroll_region(buffer, x1, y1, x2, y2, amount),
    to: Raxol.Terminal.Buffer.Manager

  defdelegate copy(buffer), to: Raxol.Terminal.Buffer.Manager

  defdelegate get_differences(buffer1, buffer2),
    to: Raxol.Terminal.Buffer.Manager

  defdelegate clear(buffer), to: Raxol.Terminal.Buffer.Manager
  defdelegate resize(buffer, width, height), to: Raxol.Terminal.Buffer.Manager
end
