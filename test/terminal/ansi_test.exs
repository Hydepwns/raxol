defmodule Raxol.Terminal.ANSITest do
  use ExUnit.Case
  alias Raxol.Terminal.{ANSI, Emulator}

  describe "process_escape/2" do
    test "handles cursor movement" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[10;5H")

      # 1-based to 0-based conversion
      assert emulator.cursor_x == 4
      assert emulator.cursor_y == 9
    end

    test "handles cursor up movement" do
      emulator = Emulator.new(80, 24)
      emulator = %{emulator | cursor_y: 10}
      emulator = ANSI.process_escape(emulator, "\e[5A")

      assert emulator.cursor_y == 5
    end

    test "handles cursor down movement" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[3B")

      assert emulator.cursor_y == 3
    end

    test "handles cursor forward movement" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[5C")

      assert emulator.cursor_x == 5
    end

    test "handles cursor backward movement" do
      emulator = Emulator.new(80, 24)
      emulator = %{emulator | cursor_x: 10}
      emulator = ANSI.process_escape(emulator, "\e[3D")

      assert emulator.cursor_x == 7
    end

    test "handles foreground color" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[31m")

      assert emulator.attributes.foreground == :red
    end

    test "handles background color" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[42m")

      assert emulator.attributes.background == :green
    end

    test "handles 256 color foreground" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[38;5;123m")

      assert emulator.attributes.foreground_256 == 123
    end

    test "handles 256 color background" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[48;5;123m")

      assert emulator.attributes.background_256 == 123
    end

    test "handles true color foreground" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[38;2;255;128;0m")

      assert emulator.attributes.foreground_true == {255, 128, 0}
    end

    test "handles true color background" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[48;2;255;128;0m")

      assert emulator.attributes.background_true == {255, 128, 0}
    end

    test "handles text attributes" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[1m")

      assert emulator.attributes.bold == true
    end

    test "handles multiple text attributes" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[1;4;7m")

      assert emulator.attributes.bold == true
      assert emulator.attributes.underline == true
      assert emulator.attributes.reverse == true
    end

    test "handles attribute reset" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[1;4;7m")
      emulator = ANSI.process_escape(emulator, "\e[0m")

      assert emulator.attributes.bold == false
      assert emulator.attributes.underline == false
      assert emulator.attributes.reverse == false
    end

    test "handles individual attribute resets" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[1;4;7m")
      # Reset underline
      emulator = ANSI.process_escape(emulator, "\e[24m")

      assert emulator.attributes.bold == true
      assert emulator.attributes.underline == false
      assert emulator.attributes.reverse == true
    end

    test "handles screen clearing" do
      emulator = Emulator.new(80, 24)
      emulator = Emulator.write(emulator, "Hello")
      emulator = ANSI.process_escape(emulator, "\e[2J")

      assert emulator.cursor_x == 0
      assert emulator.cursor_y == 0
      assert Enum.all?(hd(emulator.screen_buffer), &(&1 == " "))
    end

    test "handles line erasing" do
      emulator = Emulator.new(80, 24)
      emulator = Emulator.write(emulator, "Hello")
      emulator = ANSI.process_escape(emulator, "\e[2K")

      assert Enum.all?(
               Enum.at(emulator.screen_buffer, emulator.cursor_y),
               &(&1 == " ")
             )
    end

    test "handles line insertion" do
      emulator = Emulator.new(80, 24)
      emulator = Emulator.write(emulator, "Hello")
      emulator = ANSI.process_escape(emulator, "\e[2L")

      assert length(emulator.screen_buffer) == 24

      assert Enum.at(emulator.screen_buffer, emulator.cursor_y) ==
               List.duplicate(" ", 80)
    end

    test "handles line deletion" do
      emulator = Emulator.new(80, 24)
      emulator = Emulator.write(emulator, "Hello")
      emulator = ANSI.process_escape(emulator, "\e[2M")

      assert length(emulator.screen_buffer) == 24

      assert Enum.at(emulator.screen_buffer, emulator.cursor_y) ==
               List.duplicate(" ", 80)
    end

    test "handles scroll region setting" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[5;20r")

      assert emulator.scroll_region_top == 4
      assert emulator.scroll_region_bottom == 19
    end

    test "handles cursor save and restore" do
      emulator = Emulator.new(80, 24)
      emulator = %{emulator | cursor_x: 10, cursor_y: 5}
      emulator = ANSI.process_escape(emulator, "\e[s")

      assert emulator.cursor_saved == {10, 5}

      emulator = %{emulator | cursor_x: 0, cursor_y: 0}
      emulator = ANSI.process_escape(emulator, "\e[u")

      assert emulator.cursor_x == 10
      assert emulator.cursor_y == 5
    end

    test "handles cursor visibility" do
      emulator = Emulator.new(80, 24)

      emulator = ANSI.process_escape(emulator, "\e[?25l")
      assert emulator.cursor_visible == false

      emulator = ANSI.process_escape(emulator, "\e[?25h")
      assert emulator.cursor_visible == true
    end

    test "handles bright colors" do
      emulator = Emulator.new(80, 24)

      emulator = ANSI.process_escape(emulator, "\e[91m")
      assert emulator.attributes.foreground == :bright_red

      emulator = ANSI.process_escape(emulator, "\e[101m")
      assert emulator.attributes.background == :bright_red
    end

    test "handles RGB cube colors in 256-color mode" do
      emulator = Emulator.new(80, 24)

      # Test a few colors from the RGB cube
      # First color in RGB cube
      emulator = ANSI.process_escape(emulator, "\e[38;5;16m")
      assert emulator.attributes.foreground_256 == 16

      # Last color in RGB cube
      emulator = ANSI.process_escape(emulator, "\e[38;5;231m")
      assert emulator.attributes.foreground_256 == 231
    end

    test "handles grayscale colors in 256-color mode" do
      emulator = Emulator.new(80, 24)

      # Test grayscale colors
      # First grayscale
      emulator = ANSI.process_escape(emulator, "\e[38;5;232m")
      assert emulator.attributes.foreground_256 == 232

      # Last grayscale
      emulator = ANSI.process_escape(emulator, "\e[38;5;255m")
      assert emulator.attributes.foreground_256 == 255
    end

    test "handles complex true color sequences" do
      emulator = Emulator.new(80, 24)

      # Test various RGB combinations
      # Black
      emulator = ANSI.process_escape(emulator, "\e[38;2;0;0;0m")
      assert emulator.attributes.foreground_true == {0, 0, 0}

      # White
      emulator = ANSI.process_escape(emulator, "\e[38;2;255;255;255m")
      assert emulator.attributes.foreground_true == {255, 255, 255}

      # Gray
      emulator = ANSI.process_escape(emulator, "\e[38;2;128;128;128m")
      assert emulator.attributes.foreground_true == {128, 128, 128}
    end

    test "handles multiple attributes in a single sequence" do
      emulator = Emulator.new(80, 24)

      # Test combining colors and text attributes
      emulator = ANSI.process_escape(emulator, "\e[1;4;31;42m")

      assert emulator.attributes.bold == true
      assert emulator.attributes.underline == true
      assert emulator.attributes.foreground == :red
      assert emulator.attributes.background == :green
    end
  end

  describe "generate_sequence/2" do
    test "generates cursor movement sequence" do
      sequence = ANSI.generate_sequence(:cursor_move, [10, 5])
      assert sequence == "\e[5;10H"
    end

    test "generates foreground color sequence" do
      sequence = ANSI.generate_sequence(:set_foreground, [:red])
      assert sequence == "\e[31m"
    end

    test "generates background color sequence" do
      sequence = ANSI.generate_sequence(:set_background, [:green])
      assert sequence == "\e[42m"
    end

    test "generates attribute sequence" do
      sequence = ANSI.generate_sequence(:set_attribute, [:bold])
      assert sequence == "\e[1m"
    end

    test "generates screen clearing sequence" do
      sequence = ANSI.generate_sequence(:clear_screen, [2])
      assert sequence == "\e[2J"
    end
  end
end
