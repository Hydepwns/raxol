defmodule Raxol.Terminal.ANSITest do
  use ExUnit.Case
  alias Raxol.Terminal.{ANSI, Emulator}

  describe "process_escape/2" do
    test "handles cursor movement" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[10;5H")
      
      assert emulator.cursor_x == 4  # 1-based to 0-based conversion
      assert emulator.cursor_y == 9
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

    test "handles text attributes" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[1m")
      
      assert emulator.attributes.bold == true
    end

    test "handles screen clearing" do
      emulator = Emulator.new(80, 24)
      emulator = Emulator.write(emulator, "Hello")
      emulator = ANSI.process_escape(emulator, "\e[2J")
      
      assert emulator.cursor_x == 0
      assert emulator.cursor_y == 0
      assert Enum.all?(hd(emulator.screen_buffer), &(&1 == " "))
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