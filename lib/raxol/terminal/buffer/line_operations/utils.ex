defmodule Raxol.Terminal.Buffer.LineOperations.Utils do
  @moduledoc """
  Shared utility functions for line operations.
  Extracted to eliminate code duplication between Deletion and Insertion modules.
  """

  @doc """
  Fills new lines in the buffer with empty cells.

  ## Parameters
    - buffer: The buffer to modify
    - start_y: Starting line index
    - count: Number of lines to fill
    - style: Style to apply to new cells

  ## Returns
    Updated buffer with filled lines
  """
  @spec fill_new_lines(map(), non_neg_integer(), non_neg_integer(), map() | nil) ::
          map()
  def fill_new_lines(buffer, start_y, count, style) do
    lines = Map.get(buffer, :lines, %{})
    width = Map.get(buffer, :width, 80)

    new_lines =
      Enum.reduce(start_y..(start_y + count - 1), lines, fn y, acc ->
        line = Enum.map(0..(width - 1), fn _ -> %{char: " ", style: style} end)
        Map.put(acc, y, line)
      end)

    %{buffer | lines: new_lines}
  end
end
