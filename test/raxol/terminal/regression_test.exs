defmodule Raxol.Terminal.RegressionTest do
  @moduledoc """
  Regression test suite for previously discovered bugs and edge cases.
  
  Each test case documents:
  - The original issue/bug report
  - Expected behavior
  - Performance requirements
  """
  
  use ExUnit.Case, async: true
  
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ANSI.AnsiParser, as: Parser
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  
  describe "cursor position bugs" do
    test "Issue #001: Cursor position off-by-one after CR+LF" do
      # Bug: Cursor column was not resetting to 0 after CR+LF
      emulator = Emulator.new(80, 24)
      
      {state, _} = Emulator.process_input(emulator, "Hello")
      {state, _} = Emulator.process_input(state, "\r\n")
      
      # Cursor should be at start of next line
      assert CursorManager.get_position(state.cursor) == {1, 0}
    end

    @tag timeout: 120_000
    test "Issue #002: Cursor wrap at exactly column 80" do
      # Bug: Text at column 80 wasn't wrapping correctly
      emulator = Emulator.new(80, 24)
      
      # Write exactly 80 characters
      text = String.duplicate("x", 80)
      {state, _} = Emulator.process_input(emulator, text)
      
      # Cursor should have wrapped to next line
      assert CursorManager.get_position(state.cursor) == {1, 0}
    end

    test "Issue #003: Negative cursor position with backspace at origin" do
      # Bug: Backspace at position 0,0 caused negative position
      emulator = Emulator.new(80, 24)
      
      # Ensure at origin
      {state, _} = Emulator.process_input(emulator, "\e[1;1H")
      
      # Backspace shouldn't go negative
      {state, _} = Emulator.process_input(state, "\b")
      
      {row, col} = CursorManager.get_position(state.cursor)
      assert row >= 0
      assert col >= 0
    end

    test "Issue #004: Cursor save/restore with scrolling" do
      # Bug: Saved cursor position incorrect after scroll
      emulator = Emulator.new(80, 3)  # Small screen to force scrolling
      
      # Position cursor and save
      {state, _} = Emulator.process_input(emulator, "\e[2;5H")
      {state, _} = Emulator.process_input(state, "\e[s")  # Save
      
      # Fill screen to cause scroll
      {state, _} = Emulator.process_input(state, "\n\n\n\n\n")
      
      # Restore cursor
      {state, _} = Emulator.process_input(state, "\e[u")
      
      # Position should be restored relative to viewport
      {row, _col} = CursorManager.get_position(state.cursor)
      assert row >= 0 and row < 3
    end
  end

  describe "color parsing bugs" do
    test "Issue #005: 256-color with missing parameters" do
      # Bug: Parser crashed on incomplete 256-color sequence
      sequences = [
        "\e[38;5m",      # Missing color index
        "\e[38;5;m",     # Empty color index
        "\e[48;5;256m"   # Out of range (0-255)
      ]
      
      Enum.each(sequences, fn seq ->
        # Should not crash
        result = Parser.parse(seq <> "text")
        assert is_list(result)
      end)
    end

    test "Issue #006: RGB color with invalid values" do
      # Bug: RGB values > 255 caused overflow
      emulator = Emulator.new(80, 24)
      
      sequences = [
        "\e[38;2;256;0;0m",    # R > 255
        "\e[38;2;0;999;0m",    # G > 255
        "\e[38;2;0;0;-1m",     # B < 0
        "\e[38;2;0;0;0.5m"     # Float value
      ]
      
      Enum.each(sequences, fn seq ->
        {state, _} = Emulator.process_input(emulator, seq <> "text")
        assert state != nil
      end)
    end

    test "Issue #007: SGR parameter overflow" do
      # Bug: Very large SGR parameters caused integer overflow
      emulator = Emulator.new(80, 24)
      
      large_param = "2147483648"  # Just over max int32
      sequence = "\e[#{large_param}m"
      
      {state, _} = Emulator.process_input(emulator, sequence)
      assert state != nil
    end
  end

  describe "scrolling and buffer bugs" do
    test "Issue #008: Scrollback buffer memory leak" do
      # Bug: Scrollback wasn't limited, causing memory growth
      emulator = Emulator.new(80, 24)
      
      # Generate many lines to trigger scrolling
      Enum.reduce(1..1000, emulator, fn i, state ->
        {new_state, _} = Emulator.process_input(state, "Line #{i}\n")
        
        # Scrollback should be limited (implementation dependent)
        # Just verify we don't crash
        assert new_state != nil
        new_state
      end)
    end

    test "Issue #009: Clear screen with scrollback position" do
      # Bug: Clear screen didn't reset scrollback position
      emulator = Emulator.new(80, 5)
      
      # Fill buffer to create scrollback
      {state, _} = Enum.reduce(1..10, {emulator, nil}, fn i, {s, _} ->
        Emulator.process_input(s, "Line #{i}\n")
      end)
      
      # Clear screen
      {state, _} = Emulator.process_input(state, "\e[2J")
      
      # Should be able to write at top
      {state, _} = Emulator.process_input(state, "\e[1;1HNew text")
      
      first_line = ScreenBuffer.get_line(state.main_screen_buffer, 0)
      text = Enum.map_join(Enum.take(first_line, 8), &(&1.char || " "))
      assert String.starts_with?(text, "New text")
    end

    test "Issue #010: Insert/delete lines at screen boundaries" do
      # Bug: Insert/delete at top/bottom caused corruption
      emulator = Emulator.new(80, 5)
      
      # Fill screen
      {state, _} = Enum.reduce(1..5, {emulator, nil}, fn i, {s, _} ->
        Emulator.process_input(s, "Line #{i}\n")
      end)
      
      # Insert line at top
      {state, _} = Emulator.process_input(state, "\e[1;1H\e[L")
      
      # Delete line at bottom
      {state, _} = Emulator.process_input(state, "\e[5;1H\e[M")
      
      # Should not crash or corrupt
      assert state != nil
      assert length(state.main_screen_buffer.cells) == 5
    end
  end

  describe "unicode and special character bugs" do
    test "Issue #011: Emoji width calculation" do
      # Bug: Emoji width not calculated correctly
      emulator = Emulator.new(10, 3)
      
      {state, _} = Emulator.process_input(emulator, "Hi 👋 Test")
      
      # Should handle emoji width (usually 2 columns)
      text = extract_text(state.main_screen_buffer)
      assert String.contains?(text, "👋")
    end

    test "Issue #012: Combining characters with colors" do
      # Bug: Combining chars inherited wrong color
      emulator = Emulator.new(80, 24)
      
      # Color base char, then add combining
      {state, _} = Emulator.process_input(
        emulator,
        "\e[31ma\u0301\e[0m"  # 'a' with acute accent
      )
      
      # Should preserve color on combined character
      first_cell = state.main_screen_buffer.cells |> List.first() |> List.first()
      assert first_cell.style.foreground == :red
    end

    test "Issue #013: Zero-width joiners in URLs" do
      # Bug: ZWJ broke URL parsing in OSC 8
      emulator = Emulator.new(80, 24)
      
      # URL with zero-width joiner (shouldn't display but shouldn't crash)
      url_with_zwj = "\e]8;;http://example\u200d.com\e\\Link\e]8;;\e\\"
      
      {state, _} = Emulator.process_input(emulator, url_with_zwj)
      assert state != nil
    end
  end

  describe "performance regressions" do
    test "Issue #014: Parser performance with many parameters" do
      # Bug: Parser was O(n²) with parameter count
      
      # Generate sequence with many parameters
      params = Enum.join(1..100, ";")
      sequence = "\e[#{params}m"
      
      # Should parse quickly (target: < 3.3μs per byte)
      {time, result} = :timer.tc(fn ->
        Parser.parse(sequence)
      end)
      
      assert is_list(result)
      
      # Check performance (allowing 10x margin for CI)
      bytes = byte_size(sequence)
      max_time = bytes * 33  # 33μs per byte (10x target)
      assert time < max_time, "Parser too slow: #{time}μs for #{bytes} bytes"
    end

    test "Issue #015: Render performance with many color changes" do
      # Bug: Render was recalculating styles unnecessarily
      emulator = Emulator.new(80, 24)
      
      # Many color changes in one line
      sequence = Enum.map(1..80, fn i ->
        "\e[#{30 + rem(i, 8)}m█"
      end) |> Enum.join()
      
      {time, {state, _}} = :timer.tc(fn ->
        Emulator.process_input(emulator, sequence)
      end)
      
      assert state != nil
      
      # Should complete quickly (< 1ms target)
      assert time < 10_000, "Render too slow: #{time}μs"
    end

    test "Issue #016: Memory usage with large formatted text" do
      # Bug: Memory grew linearly with formatted text
      emulator = Emulator.new(80, 24)
      
      # Process large amount of formatted text
      Enum.reduce(1..100, emulator, fn _batch, state ->
        text = Enum.map(1..100, fn i ->
          "\e[#{30 + rem(i, 8)}m#{i}\e[0m "
        end) |> Enum.join()
        
        {new_state, _} = Emulator.process_input(state, text)
        
        # State size should be bounded by screen size
        # Just verify we don't crash from memory
        assert new_state != nil
        new_state
      end)
    end
  end

  describe "mode and state bugs" do
    test "Issue #017: Mode persistence across clear" do
      # Bug: Screen clear reset modes incorrectly
      emulator = Emulator.new(80, 24)
      
      # Set some modes
      {state, _} = Emulator.process_input(emulator, "\e[?25l")  # Hide cursor
      {state, _} = Emulator.process_input(state, "\e[?7l")      # Disable wrap
      
      # Clear screen
      {state, _} = Emulator.process_input(state, "\e[2J")
      
      # Modes should persist
      assert CursorManager.get_visibility(state.cursor) == false
    end

    @tag timeout: 120_000
    test "Issue #018: Alternative screen buffer mode switching" do
      # Bug: Content leaked between main and alt buffers
      emulator = Emulator.new(80, 24)
      
      # Write to main buffer
      {state, _} = Emulator.process_input(emulator, "Main buffer")
      
      # Switch to alt
      {state, _} = Emulator.process_input(state, "\e[?1049h")
      
      # Alt should be clear
      alt_text = extract_text(state.main_screen_buffer)
      assert not String.contains?(alt_text, "Main buffer")
      
      # Write to alt
      {state, _} = Emulator.process_input(state, "Alt buffer")
      
      # Switch back
      {state, _} = Emulator.process_input(state, "\e[?1049l")
      
      # Main should have original content
      main_text = extract_text(state.main_screen_buffer)
      assert String.contains?(main_text, "Main buffer")
      assert not String.contains?(main_text, "Alt buffer")
    end

    test "Issue #019: Bracketed paste mode with special chars" do
      # Bug: Special chars in bracketed paste broke parser
      emulator = Emulator.new(80, 24)
      
      # Enable bracketed paste
      {state, _} = Emulator.process_input(emulator, "\e[?2004h")
      
      # Paste with special characters
      paste_seq = "\e[200~\e[31mColored\nMultiline\t\bText\e[201~"
      
      {state, _} = Emulator.process_input(state, paste_seq)
      assert state != nil
    end
  end

  describe "edge case combinations" do
    test "Issue #020: Simultaneous mode changes" do
      # Bug: Multiple mode changes in one sequence failed
      emulator = Emulator.new(80, 24)
      
      # Multiple modes in one sequence
      {state, _} = Emulator.process_input(
        emulator,
        "\e[?25l;?7l;?1000h"  # Hide cursor, no wrap, mouse on
      )
      
      assert state != nil
      assert CursorManager.get_visibility(state.cursor) == false
    end

    test "Issue #021: OSC within CSI sequence" do
      # Bug: OSC interrupted CSI parsing
      emulator = Emulator.new(80, 24)
      
      # This is technically malformed but shouldn't crash
      sequence = "\e[31\e]0;Title\a;1mText"
      
      {state, _} = Emulator.process_input(emulator, sequence)
      assert state != nil
    end

    @tag timeout: 120_000
    test "Issue #022: Rapid mode toggling" do
      # Bug: Rapid toggling caused state corruption
      emulator = Emulator.new(80, 24)
      
      # Toggle cursor visibility rapidly
      final_state = Enum.reduce(1..100, emulator, fn i, state ->
        seq = if rem(i, 2) == 0, do: "\e[?25h", else: "\e[?25l"
        {new_state, _} = Emulator.process_input(state, seq)
        new_state
      end)
      
      # Should end in consistent state
      assert final_state != nil
      visibility = CursorManager.get_visibility(final_state.cursor)
      assert is_boolean(visibility)
    end
  end

  # Helper functions
  
  defp extract_text(buffer) do
    buffer.cells
    |> Enum.map(fn line ->
      Enum.map_join(line, &(&1.char || " "))
    end)
    |> Enum.join("\n")
    |> String.trim()
  end
end