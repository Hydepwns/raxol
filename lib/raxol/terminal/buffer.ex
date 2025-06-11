defmodule Raxol.Terminal.Buffer do
  @moduledoc """
  Delegating module for terminal buffer operations. Provides a unified API and delegates to the appropriate submodules.
  """

  # Delegate to UnifiedManager
  defdelegate new(arg1, arg2), to: Raxol.Terminal.Buffer.UnifiedManager
  defdelegate get_cell(buffer, x, y), to: Raxol.Terminal.Buffer.UnifiedManager
  defdelegate set_cell(buffer, x, y, cell), to: Raxol.Terminal.Buffer.UnifiedManager

  defdelegate fill_region(buffer, x1, y1, x2, y2, cell),
    to: Raxol.Terminal.Buffer.UnifiedManager

  defdelegate copy_region(buffer, x1, y1, x2, y2, dest_x, dest_y),
    to: Raxol.Terminal.Buffer.UnifiedManager

  defdelegate scroll_region(buffer, x1, y1, x2, y2, amount),
    to: Raxol.Terminal.Buffer.UnifiedManager

  defdelegate copy(buffer), to: Raxol.Terminal.Buffer.UnifiedManager

  defdelegate get_differences(buffer1, buffer2),
    to: Raxol.Terminal.Buffer.UnifiedManager

  defdelegate clear(buffer), to: Raxol.Terminal.Buffer.UnifiedManager
  defdelegate resize(buffer, width, height), to: Raxol.Terminal.Buffer.UnifiedManager
end
