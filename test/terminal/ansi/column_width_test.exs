defmodule Raxol.Terminal.ANSI.ColumnWidthTest do
  use ExUnit.Case
  alias Raxol.Terminal.{ANSI, Emulator, ScreenBuffer, Cell}

  setup do
    # Create a terminal emulator with default dimensions (80x24)
    # Use process_escape_sequence directly for clarity
    emulator = Emulator.new(80, 24)
    %{emulator: emulator}
  end

  describe "column width changes" do
    test "switching to 132-column mode", %{emulator: emulator} do
      # Process the CSI sequence for 132-column mode
      {new_emulator, _rest} =
        Emulator.process_escape_sequence(emulator, "\x1b[?3h")

      # Check that the screen buffer width has been updated to 132
      assert new_emulator.screen_buffer.width == 132

      # Check that the mode_state reflects the change
      # Using ScreenModes alias
      assert ScreenModes.mode_enabled?(new_emulator.mode_state, :wide_column)
    end

    test "switching back to 80-column mode", %{emulator: emulator} do
      # First switch to 132-column mode
      {emulator_132, _rest1} =
        Emulator.process_escape_sequence(emulator, "\x1b[?3h")

      # Verify intermediate state
      assert emulator_132.screen_buffer.width == 132

      # Then switch back to 80-column mode
      {new_emulator, _rest2} =
        Emulator.process_escape_sequence(emulator_132, "\x1b[?3l")

      # Check that the width has been updated back to 80
      assert new_emulator.screen_buffer.width == 80

      # Check that the column width mode is set back to normal
      refute ScreenModes.mode_enabled?(new_emulator.mode_state, :wide_column)
    end

    test "screen clearing on column width change", %{emulator: emulator} do
      # Write some content initially to ensure it gets cleared
      emulator = write_content(emulator, "Initial content")
      assert get_content(emulator, 0) =~ "Initial content"

      # Switch to 132-column mode
      {emulator_132, _rest1} =
        Emulator.process_escape_sequence(emulator, "\x1b[?3h")

      # Verify screen is cleared and cursor is home
      assert is_screen_clear?(emulator_132)
      assert emulator_132.cursor.position == {0, 0}
      # Verify width still changes
      assert emulator_132.screen_buffer.width == 132

      # Switch back to 80-column mode
      {emulator_80, _rest2} =
        Emulator.process_escape_sequence(emulator_132, "\x1b[?3l")

      # Verify screen is cleared again and cursor is home
      assert is_screen_clear?(emulator_80)
      assert emulator_80.cursor.position == {0, 0}
      # Verify width changes back
      assert emulator_80.screen_buffer.width == 80
    end
  end

  # Helper functions

  # Updated to use Emulator.process_input
  defp write_content(emulator, content) do
    Enum.reduce(String.graphemes(content), emulator, fn char, acc ->
      {new_acc, _rest} = Emulator.process_input(acc, char)
      new_acc
    end)
  end

  # Updated to extract content from ScreenBuffer struct
  defp get_content(emulator, line_index) do
    case ScreenBuffer.get_line(emulator.screen_buffer, line_index) do
      nil ->
        ""

      line_cells ->
        line_cells
        |> Enum.map(& &1.char)
        |> Enum.join()
    end
  end

  # Helper to check if the screen is clear (all cells are default)
  defp is_screen_clear?(emulator) do
    # Assumes Cell.new() creates the default empty cell
    default_cell = Cell.new()

    Enum.all?(emulator.screen_buffer.cells, fn row ->
      Enum.all?(row, fn cell ->
        # Compare relevant fields, ignore style for simplicity if needed
        # && cell.style == default_cell.style
        cell.char == default_cell.char
      end)
    end)
  end

  # Overload for getting all lines (optional, but useful for debugging)
  # defp get_content(emulator) do
  #   height = emulator.screen_buffer.height
  #   0..(height - 1)
  #   |> Enum.map(&get_content(emulator, &1))
  #   |> Enum.join("\n")
  # end
end
