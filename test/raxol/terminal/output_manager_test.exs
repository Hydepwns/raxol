defmodule Raxol.Terminal.OutputManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.OutputManager

  describe "format_ansi_sequences/1" do
    test "handles cursor movement sequences" do
      assert OutputManager.format_ansi_sequences("\e[5A") == "CURSOR_UP(5)"
      assert OutputManager.format_ansi_sequences("\e[3B") == "CURSOR_DOWN(3)"
      assert OutputManager.format_ansi_sequences("\e[2C") == "CURSOR_FORWARD(2)"

      assert OutputManager.format_ansi_sequences("\e[4D") ==
               "CURSOR_BACKWARD(4)"

      assert OutputManager.format_ansi_sequences("\e[10;20H") ==
               "CURSOR_POSITION(10;20)"

      assert OutputManager.format_ansi_sequences("\e[H") == "CURSOR_HOME"
      assert OutputManager.format_ansi_sequences("\e[s") == "CURSOR_SAVE"
      assert OutputManager.format_ansi_sequences("\e[u") == "CURSOR_RESTORE"
    end

    test "handles cursor movement edge cases" do
      # Zero or missing parameters
      assert OutputManager.format_ansi_sequences("\e[0A") == "CURSOR_UP(0)"
      assert OutputManager.format_ansi_sequences("\e[A") == "CURSOR_UP(1)"

      assert OutputManager.format_ansi_sequences("\e[;H") ==
               "CURSOR_POSITION(1;1)"

      # Large numbers
      assert OutputManager.format_ansi_sequences("\e[9999A") ==
               "CURSOR_UP(9999)"

      assert OutputManager.format_ansi_sequences("\e[9999;9999H") ==
               "CURSOR_POSITION(9999;9999)"

      # Multiple parameters
      assert OutputManager.format_ansi_sequences("\e[1;2;3H") ==
               "CURSOR_POSITION(1;2;3)"
    end

    test "handles text attribute sequences" do
      assert OutputManager.format_ansi_sequences("\e[0m") == "RESET_ATTRIBUTES"
      assert OutputManager.format_ansi_sequences("\e[1;31m") == "SGR(1;31)"

      assert OutputManager.format_ansi_sequences("\e[38;5;196m") ==
               "SGR(38;5;196)"

      assert OutputManager.format_ansi_sequences("\e[48;2;255;0;0m") ==
               "SGR(48;2;255;0;0)"
    end

    test "handles text attribute edge cases" do
      # Empty parameters
      assert OutputManager.format_ansi_sequences("\e[m") == "RESET_ATTRIBUTES"

      # Multiple attributes
      assert OutputManager.format_ansi_sequences("\e[1;3;4;5;7;9m") ==
               "SGR(1;3;4;5;7;9)"

      # True color with alpha
      assert OutputManager.format_ansi_sequences("\e[38;2;255;0;0;1m") ==
               "SGR(38;2;255;0;0;1)"

      # Invalid color codes
      assert OutputManager.format_ansi_sequences("\e[38;5;999m") ==
               "SGR(38;5;999)"

      assert OutputManager.format_ansi_sequences("\e[38;2;999;999;999m") ==
               "SGR(38;2;999;999;999)"
    end

    test "handles screen manipulation sequences" do
      assert OutputManager.format_ansi_sequences("\e[2J") == "CLEAR_SCREEN(2)"
      assert OutputManager.format_ansi_sequences("\e[K") == "CLEAR_LINE(0)"
      assert OutputManager.format_ansi_sequences("\e[1L") == "INSERT_LINE(1)"
    end

    test "handles screen manipulation edge cases" do
      # All clear screen modes
      assert OutputManager.format_ansi_sequences("\e[0J") == "CLEAR_SCREEN(0)"
      assert OutputManager.format_ansi_sequences("\e[1J") == "CLEAR_SCREEN(1)"
      assert OutputManager.format_ansi_sequences("\e[2J") == "CLEAR_SCREEN(2)"
      assert OutputManager.format_ansi_sequences("\e[3J") == "CLEAR_SCREEN(3)"

      # All clear line modes
      assert OutputManager.format_ansi_sequences("\e[0K") == "CLEAR_LINE(0)"
      assert OutputManager.format_ansi_sequences("\e[1K") == "CLEAR_LINE(1)"
      assert OutputManager.format_ansi_sequences("\e[2K") == "CLEAR_LINE(2)"

      # Multiple lines
      assert OutputManager.format_ansi_sequences("\e[5L") == "INSERT_LINE(5)"
      assert OutputManager.format_ansi_sequences("\e[5M") == "DELETE_LINE(5)"
    end

    test "handles mode setting sequences" do
      assert OutputManager.format_ansi_sequences("\e[?25h") == "SET_MODE(25)"
      assert OutputManager.format_ansi_sequences("\e[?25l") == "RESET_MODE(25)"
    end

    test "handles mode setting edge cases" do
      # Common DEC private modes
      # Cursor keys mode
      assert OutputManager.format_ansi_sequences("\e[?1h") == "SET_MODE(1)"
      # 132 column mode
      assert OutputManager.format_ansi_sequences("\e[?3h") == "SET_MODE(3)"
      # Reverse video
      assert OutputManager.format_ansi_sequences("\e[?5h") == "SET_MODE(5)"
      # Origin mode
      assert OutputManager.format_ansi_sequences("\e[?6h") == "SET_MODE(6)"
      # Wraparound mode
      assert OutputManager.format_ansi_sequences("\e[?7h") == "SET_MODE(7)"
      # Auto-repeat
      assert OutputManager.format_ansi_sequences("\e[?8h") == "SET_MODE(8)"
      # X10 mouse
      assert OutputManager.format_ansi_sequences("\e[?9h") == "SET_MODE(9)"
      # Cursor blink
      assert OutputManager.format_ansi_sequences("\e[?12h") == "SET_MODE(12)"
      # Cursor visibility
      assert OutputManager.format_ansi_sequences("\e[?25h") == "SET_MODE(25)"
      # Alternate screen
      assert OutputManager.format_ansi_sequences("\e[?47h") == "SET_MODE(47)"
      # Mouse tracking
      assert OutputManager.format_ansi_sequences("\e[?1000h") ==
               "SET_MODE(1000)"

      # Cell motion
      assert OutputManager.format_ansi_sequences("\e[?1002h") ==
               "SET_MODE(1002)"

      # All motion
      assert OutputManager.format_ansi_sequences("\e[?1003h") ==
               "SET_MODE(1003)"

      # Focus tracking
      assert OutputManager.format_ansi_sequences("\e[?1004h") ==
               "SET_MODE(1004)"

      # UTF-8 mouse
      assert OutputManager.format_ansi_sequences("\e[?1005h") ==
               "SET_MODE(1005)"

      # SGR mouse
      assert OutputManager.format_ansi_sequences("\e[?1006h") ==
               "SET_MODE(1006)"

      # URXVT mouse
      assert OutputManager.format_ansi_sequences("\e[?1015h") ==
               "SET_MODE(1015)"

      # Alt screen
      assert OutputManager.format_ansi_sequences("\e[?1049h") ==
               "SET_MODE(1049)"
    end

    test "handles device status sequences" do
      assert OutputManager.format_ansi_sequences("\e[6n") == "DEVICE_STATUS(6)"
    end

    test "handles device status edge cases" do
      # All device status report types
      # Device status
      assert OutputManager.format_ansi_sequences("\e[5n") == "DEVICE_STATUS(5)"
      # Cursor position
      assert OutputManager.format_ansi_sequences("\e[6n") == "DEVICE_STATUS(6)"
      # Printer status
      assert OutputManager.format_ansi_sequences("\e[7n") == "DEVICE_STATUS(7)"
      # UDK status
      assert OutputManager.format_ansi_sequences("\e[8n") == "DEVICE_STATUS(8)"
      # Printer port
      assert OutputManager.format_ansi_sequences("\e[15n") ==
               "DEVICE_STATUS(15)"

      # UDK status
      assert OutputManager.format_ansi_sequences("\e[25n") ==
               "DEVICE_STATUS(25)"

      # Keyboard status
      assert OutputManager.format_ansi_sequences("\e[26n") ==
               "DEVICE_STATUS(26)"

      # Locator status
      assert OutputManager.format_ansi_sequences("\e[53n") ==
               "DEVICE_STATUS(53)"
    end

    test "handles character set sequences" do
      assert OutputManager.format_ansi_sequences("\e(B") ==
               "DESIGNATE_CHARSET(G0,B)"

      assert OutputManager.format_ansi_sequences("\e)0") ==
               "DESIGNATE_CHARSET(G1,0)"
    end

    test "handles character set edge cases" do
      # All character set designations
      # UK
      assert OutputManager.format_ansi_sequences("\e(A") ==
               "DESIGNATE_CHARSET(G0,A)"

      # US ASCII
      assert OutputManager.format_ansi_sequences("\e(B") ==
               "DESIGNATE_CHARSET(G0,B)"

      # DEC Special
      assert OutputManager.format_ansi_sequences("\e(0") ==
               "DESIGNATE_CHARSET(G0,0)"

      # DEC Alt
      assert OutputManager.format_ansi_sequences("\e(1") ==
               "DESIGNATE_CHARSET(G0,1)"

      # DEC Alt Special
      assert OutputManager.format_ansi_sequences("\e(2") ==
               "DESIGNATE_CHARSET(G0,2)"

      # DEC Technical
      assert OutputManager.format_ansi_sequences("\e(3") ==
               "DESIGNATE_CHARSET(G0,3)"

      # DEC Supplemental
      assert OutputManager.format_ansi_sequences("\e(4") ==
               "DESIGNATE_CHARSET(G0,4)"

      # DEC Supplemental Graphic
      assert OutputManager.format_ansi_sequences("\e(5") ==
               "DESIGNATE_CHARSET(G0,5)"

      # DEC Supplemental Graphic
      assert OutputManager.format_ansi_sequences("\e(6") ==
               "DESIGNATE_CHARSET(G0,6)"

      # DEC Supplemental Graphic
      assert OutputManager.format_ansi_sequences("\e(7") ==
               "DESIGNATE_CHARSET(G0,7)"

      # DEC Supplemental Graphic
      assert OutputManager.format_ansi_sequences("\e(8") ==
               "DESIGNATE_CHARSET(G0,8)"

      # DEC Supplemental Graphic
      assert OutputManager.format_ansi_sequences("\e(9") ==
               "DESIGNATE_CHARSET(G0,9)"
    end

    test "handles OSC sequences" do
      assert OutputManager.format_ansi_sequences("\e]0;title\a") ==
               "OSC(0,title)"
    end

    test "handles OSC edge cases" do
      # Common OSC sequences
      # Window title
      assert OutputManager.format_ansi_sequences("\e]0;Window Title\a") ==
               "OSC(0,Window Title)"

      # Icon title
      assert OutputManager.format_ansi_sequences("\e]1;Icon Title\a") ==
               "OSC(1,Icon Title)"

      # Both titles
      assert OutputManager.format_ansi_sequences("\e]2;Both Titles\a") ==
               "OSC(2,Both Titles)"

      # Color 0
      assert OutputManager.format_ansi_sequences("\e]4;0;rgb:ff/00/00\a") ==
               "OSC(4;0;rgb:ff/00/00)"

      # Color 1
      assert OutputManager.format_ansi_sequences("\e]4;1;rgb:00/ff/00\a") ==
               "OSC(4;1;rgb:00/ff/00)"

      # Color 2
      assert OutputManager.format_ansi_sequences("\e]4;2;rgb:00/00/ff\a") ==
               "OSC(4;2;rgb:00/00/ff)"

      # Foreground
      assert OutputManager.format_ansi_sequences("\e]10;rgb:ff/ff/ff\a") ==
               "OSC(10;rgb:ff/ff/ff)"

      # Background
      assert OutputManager.format_ansi_sequences("\e]11;rgb:00/00/00\a") ==
               "OSC(11;rgb:00/00/00)"

      # Cursor
      assert OutputManager.format_ansi_sequences("\e]12;rgb:ff/00/00\a") ==
               "OSC(12;rgb:ff/00/00)"

      # Highlight
      assert OutputManager.format_ansi_sequences("\e]17;rgb:ff/ff/ff\a") ==
               "OSC(17;rgb:ff/ff/ff)"

      # Highlight background
      assert OutputManager.format_ansi_sequences("\e]19;rgb:00/00/00\a") ==
               "OSC(19;rgb:00/00/00)"

      # Clipboard
      assert OutputManager.format_ansi_sequences("\e]52;c;base64\a") ==
               "OSC(52;c;base64)"

      # Notification
      assert OutputManager.format_ansi_sequences("\e]777;notify;Title;Body\a") ==
               "OSC(777;notify;Title;Body)"
    end

    test "preserves plain text" do
      text = "Hello, World!"
      assert OutputManager.format_ansi_sequences(text) == text
    end

    test "handles mixed content" do
      input = "Hello\e[31mWorld\e[0m!"
      expected = "HelloSGR(31)WorldRESET_ATTRIBUTES!"
      assert OutputManager.format_ansi_sequences(input) == expected
    end

    test "handles complex mixed content" do
      input = "Hello\e[31mWorld\e[0m!\e[?25h\e[2J\e[H\e]0;Title\a"

      expected =
        "HelloSGR(31)WorldRESET_ATTRIBUTES!SET_MODE(25)CLEAR_SCREEN(2)CURSOR_HOMEOSC(0,Title)"

      assert OutputManager.format_ansi_sequences(input) == expected
    end
  end

  describe "format_control_chars/1" do
    test "formats C0 control characters" do
      assert OutputManager.format_control_chars("\x00") == "^@"
      assert OutputManager.format_control_chars("\x01") == "^A"
      assert OutputManager.format_control_chars("\x1A") == "^Z"
      assert OutputManager.format_control_chars("\x1B") == "^["
      assert OutputManager.format_control_chars("\x1F") == "^_"
    end

    test "formats special control characters" do
      assert OutputManager.format_control_chars("\x7F") == "^?"
    end

    test "preserves printable characters" do
      text = "Hello, World!"
      assert OutputManager.format_control_chars(text) == text
    end

    test "handles mixed content" do
      input = "Hello\x01World\x7F!"
      expected = "Hello^AWorld^?!"
      assert OutputManager.format_control_chars(input) == expected
    end
  end

  describe "format_unicode/1" do
    test "formats Unicode characters outside BMP" do
      # Emoji: grinning face
      assert OutputManager.format_unicode("A") == "U+0041"
      # Unicode: Latin capital A
      assert OutputManager.format_unicode("B") == "U+0042"
    end

    test "preserves basic Unicode characters" do
      text = "Hello, 世界!"
      assert OutputManager.format_unicode(text) == text
    end

    test "handles mixed content" do
      input = "Hello, 世界! 😀"
      expected = "Hello, 世界! U+1F600"
      assert OutputManager.format_unicode(input) == expected
    end
  end

  describe "integration" do
    test "formats complex output with multiple sequence types" do
      input = "Hello\x01\e[31mWorld\e[0m! 😀"
      expected = "Hello^ASGR(31)WorldRESET_ATTRIBUTES! U+1F600"

      assert OutputManager.format_ansi_sequences(input)
             |> OutputManager.format_control_chars()
             |> OutputManager.format_unicode() == expected
    end

    test "handles empty input" do
      assert OutputManager.format_ansi_sequences("") == ""
      assert OutputManager.format_control_chars("") == ""
      assert OutputManager.format_unicode("") == ""
    end

    test "handles invalid sequences" do
      # Invalid ANSI sequence
      assert OutputManager.format_ansi_sequences("\e[invalid") == "\e[invalid"
      # Invalid control character
      assert OutputManager.format_control_chars("\xFF") == "\xFF"
      # Invalid Unicode character
      # assert OutputManager.format_unicode("\u{110000}") == "\u{110000}"
    end
  end
end
