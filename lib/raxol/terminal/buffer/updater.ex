defmodule Raxol.Terminal.Buffer.Updater do
  @moduledoc """
  Handles calculating differences and applying updates to the Raxol.Terminal.ScreenBuffer.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.CharacterHandling

  import Raxol.Terminal.Buffer.State, only: [get_cell_at: 3]

  @doc """
  Calculates the difference between the current buffer state and a list of desired cell changes.
  Returns a list of {x, y, cell_map} tuples representing only the cells that need to be updated.
  Input `changes` must be a list of {x, y, map} tuples.
  """
  @spec diff(
          ScreenBuffer.t(),
          list({non_neg_integer(), non_neg_integer(), map()})
        ) :: list({non_neg_integer(), non_neg_integer(), map()})
  def diff(%ScreenBuffer{} = _buffer, changes) when is_list(changes) do
    if valid_changes_format?(changes) do
      Enum.filter(changes, &needs_update?(_buffer, &1))
    else
      log_invalid_changes_format(changes)
      []
    end
  end

  defp valid_changes_format?(changes) do
    Enum.empty?(changes) or match?([{_, _, _} | _], changes)
  end

  defp needs_update?(_buffer, {x, y, desired_cell_map}) do
    current_cell_struct = get_cell_at(_buffer, x, y)
    desired_cell_struct = Cell.from_map(desired_cell_map)
    cells_differ?(desired_cell_struct, current_cell_struct)
  end

  defp cells_differ?(nil, _), do: false
  defp cells_differ?(_, nil), do: true
  defp cells_differ?(desired, current), do: not Cell.equals?(current, desired)

  defp log_invalid_changes_format(changes) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Invalid format passed to ScreenBuffer.Updater.diff/2. Expected list of {x, y, map}. Got: #{inspect(changes)}",
      %{}
    )
  end

  @doc """
  Updates the buffer state by applying a list of cell changes.
  Changes must be in the format {x, y, Cell.t() | map()}.
  Returns the updated buffer.
  """
  @spec update(
          ScreenBuffer.t(),
          list({non_neg_integer(), non_neg_integer(), Cell.t() | map()})
        ) :: ScreenBuffer.t()
  def update(%ScreenBuffer{} = buffer, changes) when is_list(changes) do
    Enum.reduce(changes, buffer, &process_change/2)
  end

  defp process_change({x, y, %Cell{} = cell}, buffer)
       when is_integer(x) and is_integer(y) do
    apply_cell_update(buffer, x, y, cell)
  end

  defp process_change({x, y, cell_map}, buffer)
       when is_integer(x) and is_integer(y) and is_map(cell_map) do
    case Cell.from_map(cell_map) do
      nil ->
        log_invalid_cell_map(x, y, cell_map)
        buffer

      cell_struct ->
        apply_cell_update(buffer, x, y, cell_struct)
    end
  end

  defp process_change(invalid_change, buffer) do
    log_invalid_change(invalid_change)
    buffer
  end

  defp log_invalid_cell_map(x, y, cell_map) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "[ScreenBuffer.Updater.update] Failed to convert cell map: #{inspect(cell_map)} at (#{x}, #{y})",
      %{}
    )
  end

  defp log_invalid_change(invalid_change) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "[ScreenBuffer.Updater.update] Invalid change format: #{inspect(invalid_change)}",
      %{}
    )
  end

  # Applies a single cell update, handling wide characters.
  # Internal helper for update/2.
  defp apply_cell_update(%ScreenBuffer{} = buffer, x, y, %Cell{} = cell) do
    if in_bounds?(buffer, x, y) do
      update_cell_in_bounds(buffer, x, y, cell)
    else
      buffer
    end
  end

  defp in_bounds?(%ScreenBuffer{width: width, height: height}, x, y) do
    y >= 0 and y < height and x >= 0 and x < width
  end

  defp update_cell_in_bounds(buffer, x, y, cell) do
    codepoint = get_codepoint(cell)

    wide =
      CharacterHandling.get_char_width(codepoint) == 2 and
        not cell.wide_placeholder

    new_cells =
      List.update_at(buffer.cells, y, fn row ->
        update_row_with_wide_char(row, x, cell, wide, buffer.width)
      end)

    %{buffer | cells: new_cells}
  end

  defp get_codepoint(%Cell{char: char})
       when is_binary(char) and byte_size(char) > 0 do
    hd(String.to_charlist(char))
  end

  defp get_codepoint(%Cell{} = cell) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Cell char is not a valid string: #{inspect(cell.char)}, assuming width 1",
      %{}
    )

    32
  end

  defp update_row_with_wide_char(row, x, cell, wide, width) do
    row_with_primary = List.replace_at(row, x, cell)

    if wide and x + 1 < width do
      List.replace_at(
        row_with_primary,
        x + 1,
        Cell.new_wide_placeholder(cell.style)
      )
    else
      row_with_primary
    end
  end
end
