defmodule Raxol.Terminal.ANSI.ColumnWidthTest do
  use ExUnit.Case
  alias Raxol.Terminal.{ANSI, Emulator, ScreenBuffer}

  setup do
    # Create a terminal emulator with default dimensions (80x24)
    terminal = Emulator.new(80, 24)
    %{terminal: terminal}
  end

  describe "column width changes" do
    test "switching to 132-column mode", %{terminal: terminal} do
      # Process the CSI sequence for 132-column mode
      new_terminal = ANSI.process_escape_sequence(terminal, "\x1b[?3h")
      
      # Check that the width has been updated to 132
      assert new_terminal.width == 132
      
      # Check that the screen buffer has been resized
      assert length(List.first(new_terminal.screen_buffer)) == 132
      
      # Check that the column width mode is set to wide
      assert Raxol.Terminal.ANSI.ScreenModes.get_column_width_mode(new_terminal.mode_state) == :wide
    end

    test "switching back to 80-column mode", %{terminal: terminal} do
      # First switch to 132-column mode
      terminal = ANSI.process_escape_sequence(terminal, "\x1b[?3h")
      
      # Then switch back to 80-column mode
      new_terminal = ANSI.process_escape_sequence(terminal, "\x1b[?3l")
      
      # Check that the width has been updated back to 80
      assert new_terminal.width == 80
      
      # Check that the screen buffer has been resized
      assert length(List.first(new_terminal.screen_buffer)) == 80
      
      # Check that the column width mode is set back to normal
      assert Raxol.Terminal.ANSI.ScreenModes.get_column_width_mode(new_terminal.mode_state) == :normal
    end

    test "content preservation during column width changes", %{terminal: terminal} do
      # Write some content to the terminal
      terminal = write_content(terminal, "Hello, World!")
      
      # Switch to 132-column mode
      terminal = ANSI.process_escape_sequence(terminal, "\x1b[?3h")
      
      # Check that the content is preserved
      assert get_content(terminal) =~ "Hello, World!"
      
      # Switch back to 80-column mode
      terminal = ANSI.process_escape_sequence(terminal, "\x1b[?3l")
      
      # Check that the content is still preserved
      assert get_content(terminal) =~ "Hello, World!"
    end
  end

  # Helper functions

  defp write_content(terminal, content) do
    Enum.reduce(String.graphemes(content), terminal, fn char, acc ->
      ANSI.process_char(acc, char)
    end)
  end

  defp get_content(terminal) do
    terminal.screen_buffer
    |> Enum.map(fn row ->
      row
      |> Enum.map(fn cell -> cell.char end)
      |> Enum.join("")
    end)
    |> Enum.join("\n")
  end
end 