defmodule Raxol.Terminal.ANSI.Processor do
  @moduledoc """
  Processes ANSI escape sequences for terminal control.
  """

  alias Raxol.Terminal.Cursor
  alias Raxol.Terminal.Buffer.Eraser
  alias Raxol.Terminal.ANSI.{TextFormatting, CharacterSets}

  @doc """
  Processes an ANSI escape sequence and updates the terminal state accordingly.
  """
  def process_sequence(emulator, sequence) do
    case sequence do
      {:cursor_up, n} ->
        handle_cursor_up(emulator, n)

      {:cursor_down, n} ->
        handle_cursor_down(emulator, n)

      {:cursor_forward, n} ->
        handle_cursor_forward(emulator, n)

      {:cursor_backward, n} ->
        handle_cursor_backward(emulator, n)

      {:cursor_move, row, col} ->
        handle_cursor_move(emulator, row, col)

      {:set_foreground, color} ->
        TextFormatting.set_foreground(emulator, color)

      {:set_background, color} ->
        TextFormatting.set_background(emulator, color)

      {:set_attribute, attr} ->
        TextFormatting.set_attribute(emulator, attr)

      {:reset_attributes} ->
        TextFormatting.reset_attributes(emulator)

      {:clear_screen, mode} ->
        Eraser.clear_screen(emulator, mode)

      {:clear_line, mode} ->
        Eraser.clear_line(emulator, mode)

      {:set_charset, charset} ->
        CharacterSets.switch_charset(emulator, charset, :g0)

      _ ->
        emulator
    end
  end

  defp handle_cursor_up(emulator, n), do: Cursor.move_up(emulator, n)
  defp handle_cursor_down(emulator, n), do: Cursor.move_down(emulator, n)
  defp handle_cursor_forward(emulator, n), do: Cursor.move_forward(emulator, n)

  defp handle_cursor_backward(emulator, n),
    do: Cursor.move_backward(emulator, n)

  defp handle_cursor_move(emulator, row, col),
    do: Cursor.move_to(emulator, {row, col})
end
