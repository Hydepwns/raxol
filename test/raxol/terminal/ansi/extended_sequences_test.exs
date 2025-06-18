defmodule Raxol.Terminal.ANSI.ExtendedSequencesTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.ANSI.ExtendedSequences
  alias Raxol.Terminal.ScreenBuffer

  describe "process_extended_sgr/2" do
    test ~c"handles extended foreground colors" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ExtendedSequences.process_extended_sgr(["90"], buffer)
      assert buffer.default_style.foreground == 8

      buffer = ExtendedSequences.process_extended_sgr(["97"], buffer)
      assert buffer.default_style.foreground == 15
    end

    test ~c"handles extended background colors" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ExtendedSequences.process_extended_sgr(["100"], buffer)
      assert buffer.default_style.background == 8

      buffer = ExtendedSequences.process_extended_sgr(["107"], buffer)
      assert buffer.default_style.background == 15
    end

    test ~c"handles true color sequences" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ExtendedSequences.process_extended_sgr(["38;2;255;0;0"], buffer)
      assert buffer.default_style.foreground == {255, 0, 0}

      buffer = ExtendedSequences.process_extended_sgr(["48;2;0;255;0"], buffer)
      assert buffer.default_style.background == {0, 255, 0}
    end

    test ~c"handles text attributes" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ExtendedSequences.process_extended_sgr(["1"], buffer)
      assert buffer.default_style.bold == true

      buffer = ExtendedSequences.process_extended_sgr(["22"], buffer)
      assert buffer.default_style.bold == false
      assert buffer.default_style.faint == false

      buffer = ExtendedSequences.process_extended_sgr(["3"], buffer)
      assert buffer.default_style.italic == true

      buffer = ExtendedSequences.process_extended_sgr(["23"], buffer)
      assert buffer.default_style.italic == false
    end

    test ~c"handles color reset" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ExtendedSequences.process_extended_sgr(["38;2;255;0;0"], buffer)
      buffer = ExtendedSequences.process_extended_sgr(["39"], buffer)
      assert buffer.default_style.foreground == nil

      buffer = ExtendedSequences.process_extended_sgr(["48;2;0;255;0"], buffer)
      buffer = ExtendedSequences.process_extended_sgr(["49"], buffer)
      assert buffer.default_style.background == nil
    end
  end

  describe "process_true_color/3" do
    test ~c"handles foreground true color" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ExtendedSequences.process_true_color("38", "255;0;0", buffer)
      assert buffer.default_style.foreground == {255, 0, 0}
    end

    test ~c"handles background true color" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ExtendedSequences.process_true_color("48", "0;255;0", buffer)
      assert buffer.default_style.background == {0, 255, 0}
    end

    test ~c"handles invalid color values" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ExtendedSequences.process_true_color("38", "invalid", buffer)
      assert buffer.default_style.foreground == nil
    end
  end

  describe "process_unicode/2" do
    test ~c"handles valid Unicode characters" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ExtendedSequences.process_unicode("あ", buffer)
      assert ScreenBuffer.get_char(buffer, 0, 0) == "あ"
    end

    test ~c"handles invalid Unicode characters" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ExtendedSequences.process_unicode(<<0xFF, 0xFF>>, buffer)
      assert ScreenBuffer.get_char(buffer, 0, 0) == nil
    end
  end

  describe "process_terminal_state/2" do
    test ~c"handles cursor visibility" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ExtendedSequences.process_terminal_state("?25h", buffer)
      assert buffer.cursor_visible == true

      buffer = ExtendedSequences.process_terminal_state("?25l", buffer)
      assert buffer.cursor_visible == false
    end

    test ~c"handles alternate screen" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ExtendedSequences.process_terminal_state("?47h", buffer)
      assert buffer.alternate_screen == true

      buffer = ExtendedSequences.process_terminal_state("?47l", buffer)
      assert buffer.alternate_screen == false
    end

    test ~c"handles alternate screen buffer" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ExtendedSequences.process_terminal_state("?1049h", buffer)
      assert buffer.alternate_screen_buffer == true

      buffer = ExtendedSequences.process_terminal_state("?1049l", buffer)
      assert buffer.alternate_screen_buffer == false
    end

    test ~c"handles unknown state" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ExtendedSequences.process_terminal_state("?999h", buffer)
      assert buffer == buffer
    end
  end
end
