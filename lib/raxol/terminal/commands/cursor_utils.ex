defmodule Raxol.Terminal.Commands.CursorUtils do
  @moduledoc """
  Shared utility functions for cursor handling commands.
  Eliminates code duplication between CursorHandler and CSIHandler.
  """

  @doc """
  Calculates new cursor position based on direction and movement amount.
  Ensures the new position is within the emulator bounds.

  ## Parameters
    - current_pos: Current {row, col} position
    - direction: Direction to move (:up, :down, :left, :right)
    - amount: Number of positions to move
    - width: Emulator width for boundary checking
    - height: Emulator height for boundary checking

  ## Returns
    New {row, col} position clamped to bounds
  """
  @spec calculate_new_cursor_position(
          {non_neg_integer(), non_neg_integer()},
          atom(),
          non_neg_integer(),
          pos_integer(),
          pos_integer()
        ) :: {non_neg_integer(), non_neg_integer()}
  def calculate_new_cursor_position(
        {row, col},
        direction,
        amount,
        width,
        height
      ) do
    case direction do
      :up -> {max(0, row - amount), col}
      :down -> {min(height - 1, row + amount), col}
      :left -> {row, max(0, col - amount)}
      :right -> {row, min(width - 1, col + amount)}
    end
  end
end
