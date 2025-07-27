defmodule Raxol.Terminal.Emulator.ScreenOperations do
  @moduledoc """
  Screen operation functions extracted from the main emulator module.
  Handles screen clearing and line clearing operations.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Operations.ScreenOperations, as: ScreenOps

  @type emulator :: Emulator.t()

  @doc """
  Clears from cursor to end of screen.
  """
  @spec clear_from_cursor_to_end(
          emulator(),
          non_neg_integer(),
          non_neg_integer()
        ) :: emulator()
  def clear_from_cursor_to_end(emulator, _x, _y) do
    ScreenOps.erase_from_cursor_to_end(emulator)
  end

  @doc """
  Clears from start of screen to cursor.
  """
  @spec clear_from_start_to_cursor(
          emulator(),
          non_neg_integer(),
          non_neg_integer()
        ) :: emulator()
  def clear_from_start_to_cursor(emulator, _x, _y) do
    ScreenOps.erase_from_start_to_cursor(emulator)
  end

  @doc """
  Clears the entire screen.
  """
  @spec clear_entire_screen(emulator()) :: emulator()
  def clear_entire_screen(emulator) do
    ScreenOps.clear_screen(emulator)
  end

  @doc """
  Clears from cursor to end of line.
  """
  @spec clear_from_cursor_to_end_of_line(
          emulator(),
          non_neg_integer(),
          non_neg_integer()
        ) :: emulator()
  def clear_from_cursor_to_end_of_line(emulator, _x, _y) do
    ScreenOps.clear_line(emulator, 0)
  end

  @doc """
  Clears from start of line to cursor.
  """
  @spec clear_from_start_of_line_to_cursor(
          emulator(),
          non_neg_integer(),
          non_neg_integer()
        ) :: emulator()
  def clear_from_start_of_line_to_cursor(emulator, _x, _y) do
    ScreenOps.clear_line(emulator, 1)
  end

  @doc """
  Clears the entire line.
  """
  @spec clear_entire_line(emulator(), non_neg_integer()) :: emulator()
  def clear_entire_line(emulator, _y) do
    ScreenOps.clear_line(emulator, 2)
  end

  @doc """
  Clears the current line.
  """
  @spec clear_line(emulator()) :: emulator()
  def clear_line(emulator) do
    # Clear the current line from cursor to end
    ScreenOps.clear_line(emulator)
  end
end
