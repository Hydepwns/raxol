defmodule Raxol.Terminal.Emulator.EraseOps do
  @moduledoc false

  alias Raxol.Core.Runtime.Log
  alias Raxol.Terminal.Operations.ScreenOperations
  alias Raxol.Terminal.Operations.TextOperations

  def clear_screen(emulator) do
    ScreenOperations.clear_screen(emulator)
  rescue
    error ->
      Log.warning("clear_screen failed: #{inspect(error)}")
      emulator
  end

  def clear_line(emulator, line),
    do: ScreenOperations.clear_line(emulator, line)

  def erase_display(emulator, mode),
    do: ScreenOperations.erase_display(emulator, mode)

  def erase_in_display(emulator, mode),
    do: ScreenOperations.erase_in_display(emulator, mode)

  def erase_line(emulator, mode),
    do: ScreenOperations.erase_line(emulator, mode)

  def erase_in_line(emulator, mode),
    do: ScreenOperations.erase_in_line(emulator, mode)

  def erase_from_cursor_to_end(emulator),
    do: ScreenOperations.erase_from_cursor_to_end(emulator)

  def erase_from_start_to_cursor(emulator),
    do: ScreenOperations.erase_from_start_to_cursor(emulator)

  def erase_chars(emulator, count),
    do: ScreenOperations.erase_chars(emulator, count)

  def insert_char(emulator, char),
    do: TextOperations.insert_char(emulator, char)

  def insert_chars(emulator, count),
    do: TextOperations.insert_chars(emulator, count)

  def delete_char(emulator),
    do: TextOperations.delete_char(emulator)

  def delete_chars(emulator, count),
    do: TextOperations.delete_chars(emulator, count)

  def write_text(emulator, text),
    do: TextOperations.write_text(emulator, text)
end
