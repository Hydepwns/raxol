defmodule Raxol.Terminal.Display.AsciiArtTest do
  use ExUnit.Case
  alias Raxol.Terminal.Display.AsciiArt

  describe "logo/0" do
    test 'returns a non-empty string containing the Raxol logo' do
      logo = AsciiArt.logo()
      assert is_binary(logo)
      assert String.length(logo) > 0

      # assert String.contains?(logo, "Raxol") # Removed: Logo is graphical, doesn't contain the text
    end
  end

  describe "success/0" do
    test 'returns a success message with checkmark' do
      success = AsciiArt.success()
      assert is_binary(success)
      assert String.contains?(success, "✓")
      assert String.contains?(success, "successful")
    end
  end

  describe "error/0" do
    test 'returns an error message with x mark' do
      error = AsciiArt.error()
      assert is_binary(error)
      assert String.contains?(error, "✗")
      assert String.contains?(error, "failed")
    end
  end

  describe "warning/0" do
    test 'returns a warning message with warning symbol' do
      warning = AsciiArt.warning()
      assert is_binary(warning)
      assert String.contains?(warning, "⚠")
      assert String.contains?(warning, "Warning")
    end
  end

  describe "header/1" do
    test 'returns a centered header with the given text' do
      text = "Test Header"
      header = AsciiArt.header(text)
      assert is_binary(header)
      assert String.contains?(header, text)
      assert String.contains?(header, "╔")
      assert String.contains?(header, "╗")
      assert String.contains?(header, "╚")
      assert String.contains?(header, "╝")
    end

    test 'handles empty text' do
      header = AsciiArt.header("")
      assert is_binary(header)
      assert String.contains?(header, "╔")
      assert String.contains?(header, "╗")
    end
  end

  describe "help/0" do
    test 'returns a help screen with command reference' do
      help = AsciiArt.help()
      assert is_binary(help)
      assert String.contains?(help, "TERMINAL COMMAND REFERENCE")
      assert String.contains?(help, "help")
      assert String.contains?(help, "clear")
      assert String.contains?(help, "echo")
    end
  end

  describe "theme_preview/0" do
    test 'returns a theme preview with available options' do
      preview = AsciiArt.theme_preview()
      assert is_binary(preview)
      assert String.contains?(preview, "AVAILABLE THEME OPTIONS")
      assert String.contains?(preview, "light")
      assert String.contains?(preview, "dark")
      assert String.contains?(preview, "dim")
      assert String.contains?(preview, "high-contrast")
    end
  end

  describe "progress_bar/1" do
    test 'returns a progress bar with the given percentage' do
      progress = AsciiArt.progress_bar(50)
      assert is_binary(progress)
      assert String.contains?(progress, "50%")
      assert String.contains?(progress, "█")
      assert String.contains?(progress, "░")
    end

    test 'handles 0% progress' do
      progress = AsciiArt.progress_bar(0)
      assert is_binary(progress)
      assert String.contains?(progress, "0%")
      assert String.contains?(progress, "░")
      refute String.contains?(progress, "█")
    end

    test 'handles 100% progress' do
      progress = AsciiArt.progress_bar(100)
      assert is_binary(progress)
      assert String.contains?(progress, "100%")
      assert String.contains?(progress, "█")
      refute String.contains?(progress, "░")
    end

    test 'raises error for invalid percentage' do
      assert_raise FunctionClauseError, fn ->
        AsciiArt.progress_bar(-1)
      end

      assert_raise FunctionClauseError, fn ->
        AsciiArt.progress_bar(101)
      end
    end
  end

  describe "box/1" do
    test 'returns a box with the given text' do
      text = "Test\nMulti\nLine"
      box = AsciiArt.box(text)
      assert is_binary(box)
      assert String.contains?(box, "Test")
      assert String.contains?(box, "Multi")
      assert String.contains?(box, "Line")
      assert String.contains?(box, "╭")
      assert String.contains?(box, "╮")
      assert String.contains?(box, "╰")
      assert String.contains?(box, "╯")
    end

    test 'handles empty text' do
      box = AsciiArt.box("")
      assert is_binary(box)
      assert String.contains?(box, "╭")
      assert String.contains?(box, "╮")
    end
  end

  describe "table/2" do
    test 'returns a formatted table with headers and rows' do
      headers = ["Name", "Age", "City"]

      rows = [
        ["John", "25", "New York"],
        ["Alice", "30", "London"],
        ["Bob", "35", "Paris"]
      ]

      table = AsciiArt.table(headers, rows)
      assert is_binary(table)
      assert String.contains?(table, "Name")
      assert String.contains?(table, "Age")
      assert String.contains?(table, "City")
      assert String.contains?(table, "John")
      assert String.contains?(table, "Alice")
      assert String.contains?(table, "Bob")
    end

    test 'handles empty table' do
      headers = ["Name"]
      rows = []
      table = AsciiArt.table(headers, rows)
      assert is_binary(table)
      assert String.contains?(table, "Name")
    end
  end

  describe "spinner/1" do
    test 'returns different spinner frames for different steps' do
      frames =
        for step <- 0..9 do
          AsciiArt.spinner(step)
        end

      assert length(Enum.uniq(frames)) > 1
      assert Enum.all?(frames, &String.contains?(&1, "Processing"))
    end
  end

  describe "loading/2" do
    test 'returns loading animation with dots' do
      text = "Loading"

      frames =
        for step <- 0..3 do
          AsciiArt.loading(text, step)
        end

      assert length(Enum.uniq(frames)) == 4
      assert Enum.all?(frames, &String.starts_with?(&1, text))
    end
  end
end
