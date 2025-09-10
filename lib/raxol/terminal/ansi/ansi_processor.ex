defmodule Raxol.Terminal.ANSI.AnsiProcessor do
  @moduledoc """
  Processes ANSI escape sequences for terminal control.
  """

  alias Raxol.Terminal.Cursor
  alias Raxol.Terminal.Buffer.Eraser
  alias Raxol.Terminal.ANSI.{TextFormatting, CharacterSets}

  @doc """
  Processes an ANSI escape sequence and updates the terminal state accordingly.
  """
  def process_sequence(emulator, {:cursor_up, n}),
    do: handle_cursor_up(emulator, n)

  def process_sequence(emulator, {:cursor_down, n}),
    do: handle_cursor_down(emulator, n)

  def process_sequence(emulator, {:cursor_forward, n}),
    do: handle_cursor_forward(emulator, n)

  def process_sequence(emulator, {:cursor_backward, n}),
    do: handle_cursor_backward(emulator, n)

  def process_sequence(emulator, {:cursor_move, row, col}),
    do: handle_cursor_move(emulator, row, col)

  def process_sequence(emulator, {:set_foreground, color}),
    do: TextFormatting.set_foreground(emulator, color)

  def process_sequence(emulator, {:set_background, color}),
    do: TextFormatting.set_background(emulator, color)

  def process_sequence(emulator, {:set_attribute, attr}),
    do: TextFormatting.set_attribute(emulator, attr)

  def process_sequence(emulator, {:reset_attributes}),
    do: TextFormatting.reset_attributes(emulator)

  def process_sequence(emulator, {:clear_screen, mode}),
    do: Eraser.clear_screen(emulator, mode)

  def process_sequence(emulator, {:clear_line, mode}),
    do: Eraser.clear_line(emulator, mode)

  def process_sequence(emulator, {:set_charset, charset}),
    do: CharacterSets.switch_charset(emulator, charset, :g0)

  def process_sequence(emulator, _), do: emulator

  defp handle_cursor_up(emulator, n), do: Cursor.move_up(emulator, n)
  defp handle_cursor_down(emulator, n), do: Cursor.move_down(emulator, n)
  defp handle_cursor_forward(emulator, n), do: Cursor.move_forward(emulator, n)

  defp handle_cursor_backward(emulator, n),
    do: Cursor.move_backward(emulator, n)

  defp handle_cursor_move(emulator, row, col),
    do: Cursor.move_to(emulator, {row, col})
end
