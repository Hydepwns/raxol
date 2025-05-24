defmodule Raxol.Terminal.Buffer.Updater do
  @moduledoc """
  Handles calculating differences and applying updates to the Raxol.Terminal.ScreenBuffer.
  """

  require Logger

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.CharacterHandling
  # Import State to access helper functions now moved there
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
  def diff(%ScreenBuffer{} = buffer, changes) when is_list(changes) do
    # Ensure changes are in the expected {x, y, map} format
    if Enum.empty?(changes) or match?([{_, _, _} | _], changes) do
      Enum.filter(changes, fn {x, y, desired_cell_map} ->
        # Use imported get_cell_at
        current_cell_struct = get_cell_at(buffer, x, y)
        # Convert map for comparison
        desired_cell_struct = Cell.from_map(desired_cell_map)

        case {desired_cell_struct, current_cell_struct} do
          # Invalid desired cell map
          {nil, _} -> false
          # Current cell doesn't exist (e.g., outside buffer), needs update if desired is valid
          {_, nil} -> true
          {desired, current} -> not Cell.equals?(current, desired)
        end
      end)
    else
      Logger.warning(
        "Invalid format passed to ScreenBuffer.Updater.diff/2. Expected list of {x, y, map}. Got: #{inspect(changes)}"
      )

      # Return empty list for invalid input format
      []
    end
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
    Enum.reduce(changes, buffer, fn
      {x, y, %Cell{} = cell}, acc_buffer when is_integer(x) and is_integer(y) ->
        apply_cell_update(acc_buffer, x, y, cell)

      {x, y, cell_map}, acc_buffer
      when is_integer(x) and is_integer(y) and is_map(cell_map) ->
        case Cell.from_map(cell_map) do
          nil ->
            Logger.warning(
              "[ScreenBuffer.Updater.update] Failed to convert cell map: #{inspect(cell_map)} at (#{x}, #{y})"
            )

            acc_buffer

          cell_struct ->
            apply_cell_update(acc_buffer, x, y, cell_struct)
        end

      invalid_change, acc_buffer ->
        Logger.warning(
          "[ScreenBuffer.Updater.update] Invalid change format: #{inspect(invalid_change)}"
        )

        acc_buffer
    end)
  end

  # Applies a single cell update, handling wide characters.
  # Internal helper for update/2.
  defp apply_cell_update(%ScreenBuffer{} = buffer, x, y, %Cell{} = cell) do
    if y >= 0 and y < buffer.height and x >= 0 and x < buffer.width do
      # Ensure cell.char is a non-empty string before getting codepoint
      codepoint =
        if is_binary(cell.char) and byte_size(cell.char) > 0 do
          # Convert char string to integer codepoint
          hd(String.to_charlist(cell.char))
        else
          # Handle cases like nil, empty string, or non-binary char if they occur
          # Defaulting to width 1 for space might be reasonable
          # Or log a warning and assume width 1
          Logger.warn(
            "Cell char is not a valid string: #{inspect(cell.char)}, assuming width 1"
          )

          # Codepoint for space
          32
        end

      # Use the integer codepoint for width calculation
      is_wide =
        CharacterHandling.get_char_width(codepoint) == 2 and
          not cell.is_wide_placeholder

      new_cells =
        List.update_at(buffer.cells, y, fn row ->
          row_with_primary = List.replace_at(row, x, cell)

          if is_wide and x + 1 < buffer.width do
            List.replace_at(
              row_with_primary,
              x + 1,
              Cell.new_wide_placeholder(cell.style)
            )
          else
            row_with_primary
          end
        end)

      %{buffer | cells: new_cells}
    else
      # Ignore updates outside bounds
      buffer
    end
  end

  defp clear_char_at(buffer, x, y) do
    if x < buffer.width and y < buffer.height do
      # Check if the character to be cleared is a wide character
      current_char_data = Raxol.Terminal.Buffer.Reader.get_char_at(buffer, x, y)
      codepoint = current_char_data.codepoint

      is_wide_char_segment =
        (Raxol.Terminal.CharacterHandling.get_char_width(codepoint) == 2 and
           current_char_data.segment == :wide_char_placeholder) or
          (Raxol.Terminal.CharacterHandling.get_char_width(codepoint) == 2 and x > 0 and
             Raxol.Terminal.Buffer.Reader.get_char_at(buffer, x - 1, y).segment ==
               :wide_char_start)

      # Default style for cleared cells
      cleared_cell = Cell.new(" ") # Cleared cell with default attributes

      # Update the line
      line_to_update = Map.get(buffer.lines, y, Line.new(buffer.width))
      updated_cells =
        if is_wide_char_segment do
          # If it's part of a wide character, we need to clear both cells
          # and handle the case where x is the start or the placeholder of the wide char
          if current_char_data.segment == :wide_char_start do
            # Current char is the start, clear it and the placeholder to its right
            Map.put(line_to_update.cells, x, cleared_cell)
            |> Map.put(x + 1, cleared_cell)
          else
            # Current char is the placeholder, clear it and the start to its left
            Map.put(line_to_update.cells, x, cleared_cell)
            |> Map.put(x - 1, cleared_cell)
          end
        else
          # Not a wide character, or a standalone character that happens to be wide
          # but not marked as part of a multi-cell char (should be rare)
          Map.put(line_to_update.cells, x, cleared_cell)
        end

      updated_line = %{line_to_update | cells: updated_cells}
      %{buffer | lines: Map.put(buffer.lines, y, updated_line)}
    else
      buffer # x or y is out of bounds
    end
  end
end
