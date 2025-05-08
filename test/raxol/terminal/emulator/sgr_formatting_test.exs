defmodule Raxol.Terminal.Emulator.SgrFormattingTest do
  use ExUnit.Case

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ANSI.TextFormatting

  describe "text formatting (SGR)" do
    # Tests focus on verifying the emulator's style state after processing SGR sequences.

    test "handles SGR reset (0)" do
      emulator = Emulator.new()
      # Set some attributes
      # Bold, Red FG
      {emulator, _} = Emulator.process_input(emulator, "\e[1;31m")
      assert emulator.style.bold == true
      assert emulator.style.foreground == :red

      # Reset
      {emulator, _} = Emulator.process_input(emulator, "\e[0m")
      # Assert attributes are back to default
      assert emulator.style.bold == false
      assert emulator.style.foreground == nil
      # Add checks for other potentially modified attributes if needed
      assert emulator.style.italic == false
      assert emulator.style.underline == false
    end

    test "handles SGR bold (1) and normal intensity (22)" do
      emulator = Emulator.new()
      assert emulator.style.bold == false
      # Set bold
      {emulator, _} = Emulator.process_input(emulator, "\e[1m")
      assert emulator.style.bold == true
      # Reset bold (Normal Intensity)
      {emulator, _} = Emulator.process_input(emulator, "\e[22m")
      assert emulator.style.bold == false
    end

    test "handles SGR italic (3) and not italic (23)" do
      emulator = Emulator.new()
      assert emulator.style.italic == false
      {emulator, _} = Emulator.process_input(emulator, "\e[3m")
      assert emulator.style.italic == true
      {emulator, _} = Emulator.process_input(emulator, "\e[23m")
      assert emulator.style.italic == false
    end

    test "handles SGR underline (4) and not underlined (24)" do
      emulator = Emulator.new()
      assert emulator.style.underline == false
      assert emulator.style.double_underline == false
      {emulator, _} = Emulator.process_input(emulator, "\e[4m")
      assert emulator.style.underline == true
      # Single underline clears double
      assert emulator.style.double_underline == false
      {emulator, _} = Emulator.process_input(emulator, "\e[24m")
      assert emulator.style.underline == false
      assert emulator.style.double_underline == false
    end

    test "handles SGR foreground colors (30-37) and default (39)" do
      emulator = Emulator.new()
      # Blue
      {emulator, _} = Emulator.process_input(emulator, "\e[34m")
      assert emulator.style.foreground == :blue
      # Default
      {emulator, _} = Emulator.process_input(emulator, "\e[39m")
      assert emulator.style.foreground == nil
    end

    test "handles SGR background colors (40-47) and default (49)" do
      emulator = Emulator.new()
      # Green BG
      {emulator, _} = Emulator.process_input(emulator, "\e[42m")
      assert emulator.style.background == :green
      # Default BG
      {emulator, _} = Emulator.process_input(emulator, "\e[49m")
      assert emulator.style.background == nil
    end

    test "handles SGR faint (2) - treated as non-bold" do
      emulator = Emulator.new()
      # Start with bold ON
      {emulator, _} = Emulator.process_input(emulator, "\e[1m")
      assert emulator.style.bold == true

      # Apply faint (SGR 2)
      {emulator, _} = Emulator.process_input(emulator, "\e[2m")
      # Assert faint is ON, bold should remain ON (SGR 2 doesn't reset bold)
      assert emulator.style.faint == true, "Faint should be true after SGR 2"

      # Apply normal intensity (SGR 22)
      {emulator, _} = Emulator.process_input(emulator, "\e[22m")
      # Assert both bold and faint are OFF
      assert emulator.style.bold == false, "Bold should be false after SGR 22"
      assert emulator.style.faint == false, "Faint should be false after SGR 22"
    end

    test "handles SGR blink (5, 6) and not blinking (25)" do
      emulator = Emulator.new()
      assert emulator.style.blink == false
      # Slow blink
      {emulator, _} = Emulator.process_input(emulator, "\e[5m")
      assert emulator.style.blink == true
      # Reset blink
      {emulator, _} = Emulator.process_input(emulator, "\e[25m")
      assert emulator.style.blink == false
      # Rapid blink (treated same as slow)
      {emulator, _} = Emulator.process_input(emulator, "\e[6m")
      assert emulator.style.blink == true
      # Reset blink again
      {emulator, _} = Emulator.process_input(emulator, "\e[25m")
      assert emulator.style.blink == false
    end

    test "handles SGR reverse (7) and not reversed (27)" do
      emulator = Emulator.new()
      assert emulator.style.reverse == false
      {emulator, _} = Emulator.process_input(emulator, "\e[7m")
      assert emulator.style.reverse == true
      {emulator, _} = Emulator.process_input(emulator, "\e[27m")
      assert emulator.style.reverse == false
    end

    test "handles SGR conceal (8) and reveal (28)" do
      emulator = Emulator.new()
      assert emulator.style.conceal == false
      {emulator, _} = Emulator.process_input(emulator, "\e[8m")
      assert emulator.style.conceal == true
      {emulator, _} = Emulator.process_input(emulator, "\e[28m")
      assert emulator.style.conceal == false
    end

    test "handles SGR strikethrough (9) and not strikethrough (29)" do
      emulator = Emulator.new()
      assert emulator.style.strikethrough == false
      {emulator, _} = Emulator.process_input(emulator, "\e[9m")
      assert emulator.style.strikethrough == true
      {emulator, _} = Emulator.process_input(emulator, "\e[29m")
      assert emulator.style.strikethrough == false
    end

    test "handles SGR fraktur (20) and not fraktur (23)" do
      emulator = Emulator.new()
      assert emulator.style.fraktur == false
      {emulator, _} = Emulator.process_input(emulator, "\e[20m")
      assert emulator.style.fraktur == true
      # Resetting italic (23) also resets fraktur
      {emulator, _} = Emulator.process_input(emulator, "\e[23m")
      assert emulator.style.fraktur == false
    end

    test "handles SGR double underline (21) and not underlined (24)" do
      emulator = Emulator.new()

      # TEST 1: Ensure SGR 24 correctly sets defaults from scratch
      # Apply ONLY SGR 24
      {emulator_after_24_only, _} = Emulator.process_input(emulator, "\e[24m")

      assert emulator_after_24_only.style.underline == false,
             "[SGR 24 Only] Underline should be false"

      assert emulator_after_24_only.style.double_underline == false,
             "[SGR 24 Only] Double underline should be false"

      # TEST 2: Original test - Apply double underline first
      # Start with fresh emulator again
      {emulator, _} = Emulator.process_input(emulator, "\e[21m")

      assert emulator.style.double_underline == true,
             "Double underline should be true after SGR 21"

      # Apply not underlined (should reset both single and double)
      {emulator, _} = Emulator.process_input(emulator, "\e[24m")

      assert emulator.style.underline == false,
             "Underline should be false after SGR 24"

      assert emulator.style.double_underline == false,
             "Double underline should be false after SGR 24"

      # Ensure single underline also works after SGR 24
      {emulator, _} = Emulator.process_input(emulator, "\e[4m")

      assert emulator.style.underline == true,
             "Underline should be true after SGR 4"

      assert emulator.style.double_underline == false,
             "Double underline should still be false after SGR 4"

      # Ensure resetting works again
      {emulator, _} = Emulator.process_input(emulator, "\e[24m")

      assert emulator.style.underline == false,
             "Underline should be false after second SGR 24"

      assert emulator.style.double_underline == false,
             "Double underline should be false after second SGR 24"
    end

    test "handles SGR bright foreground colors (90-97)" do
      emulator = Emulator.new()
      # Bright red (expect red + bold)
      {emulator, _} = Emulator.process_input(emulator, "\e[91m")
      assert emulator.style.foreground == :red
      # Bright implies bold
      assert emulator.style.bold == true
      # Reset style
      {emulator, _} = Emulator.process_input(emulator, "\e[0m")
      # Bright cyan (expect cyan + bold)
      {emulator, _} = Emulator.process_input(emulator, "\e[96m")
      assert emulator.style.foreground == :cyan
      assert emulator.style.bold == true
    end

    test "handles SGR bright background colors (100-107)" do
      emulator = Emulator.new()
      # Bright green background (expect green BG, no bold change)
      {emulator, _} = Emulator.process_input(emulator, "\e[102m")
      assert emulator.style.background == :green
      assert emulator.style.bold == false
      # Reset style
      {emulator, _} = Emulator.process_input(emulator, "\e[0m")
      # Bright blue background (expect blue BG, no bold change)
      {emulator, _} = Emulator.process_input(emulator, "\e[104m")
      assert emulator.style.background == :blue
      assert emulator.style.bold == false
    end
  end
end
