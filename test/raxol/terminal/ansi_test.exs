defmodule Raxol.Terminal.ANSITest do
  use ExUnit.Case
  alias Raxol.Terminal.{ANSI, Emulator}
  alias Raxol.Style.Colors.{Color, Advanced}
  alias Raxol.Terminal.Integration

  setup do
    integration = Integration.new(80, 24)
    %{integration: integration}
  end

  describe "color handling" do
    test "handles true color with brightness preservation" do
      emulator = Emulator.new(80, 24)
      color = Color.from_hex("#FF0000")
      adapted_color = Advanced.adapt_color_advanced(color, preserve_brightness: true)
      
      emulator = ANSI.process_escape(emulator, "\e[38;2;#{adapted_color.r};#{adapted_color.g};#{adapted_color.b}m")
      
      assert emulator.attributes.foreground_true == {adapted_color.r, adapted_color.g, adapted_color.b}
    end

    test "handles true color background with brightness preservation" do
      emulator = Emulator.new(80, 24)
      color = Color.from_hex("#0000FF")
      adapted_color = Advanced.adapt_color_advanced(color, preserve_brightness: true)
      
      emulator = ANSI.process_escape(emulator, "\e[48;2;#{adapted_color.r};#{adapted_color.g};#{adapted_color.b}m")
      
      assert emulator.attributes.background_true == {adapted_color.r, adapted_color.g, adapted_color.b}
    end

    test "handles 256 color with brightness preservation" do
      emulator = Emulator.new(80, 24)
      color = Color.from_hex("#FF0000")
      adapted_color = Advanced.adapt_color_advanced(color, preserve_brightness: true)
      color_index = Advanced.rgb_to_256color(adapted_color)
      
      emulator = ANSI.process_escape(emulator, "\e[38;5;#{color_index}m")
      
      assert emulator.attributes.foreground_256 == color_index
    end

    test "handles 256 color background with brightness preservation" do
      emulator = Emulator.new(80, 24)
      color = Color.from_hex("#0000FF")
      adapted_color = Advanced.adapt_color_advanced(color, preserve_brightness: true)
      color_index = Advanced.rgb_to_256color(adapted_color)
      
      emulator = ANSI.process_escape(emulator, "\e[48;5;#{color_index}m")
      
      assert emulator.attributes.background_256 == color_index
    end

    test "handles basic colors with contrast enhancement" do
      emulator = Emulator.new(80, 24)
      color = Color.from_hex("#FF0000")
      adapted_color = Advanced.adapt_color_advanced(color, enhance_contrast: true)
      
      emulator = ANSI.process_escape(emulator, "\e[31m")
      
      assert emulator.attributes.foreground == :red
    end

    test "handles basic background colors with contrast enhancement" do
      emulator = Emulator.new(80, 24)
      color = Color.from_hex("#0000FF")
      adapted_color = Advanced.adapt_color_advanced(color, enhance_contrast: true)
      
      emulator = ANSI.process_escape(emulator, "\e[44m")
      
      assert emulator.attributes.background == :blue
    end

    test "handles color blind safe colors" do
      emulator = Emulator.new(80, 24)
      color = Color.from_hex("#FF0000")
      adapted_color = Advanced.adapt_color_advanced(color, color_blind_safe: true)
      
      emulator = ANSI.process_escape(emulator, "\e[31m")
      
      assert emulator.attributes.foreground == :red
    end
  end

  describe "cursor movement" do
    test "handles cursor movement" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[5;10H")
      
      assert emulator.cursor_x == 9  # 1-based to 0-based conversion
      assert emulator.cursor_y == 4
    end

    test "handles cursor up movement" do
      emulator = Emulator.new(80, 24)
      emulator = %{emulator | cursor_x: 0, cursor_y: 10}
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
  end

  describe "screen manipulation" do
    test "handles screen clearing" do
      emulator = Emulator.new(80, 24)
      emulator = %{emulator | buffer: ["Some text"]}
      emulator = ANSI.process_escape(emulator, "\e[2J")
      
      assert emulator.buffer == []
    end

    test "handles line clearing" do
      emulator = Emulator.new(80, 24)
      emulator = %{emulator | buffer: ["Some text"]}
      emulator = ANSI.process_escape(emulator, "\e[2K")
      
      assert emulator.buffer == []
    end

    test "handles line insertion" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[3L")
      
      # Line insertion would be handled by the buffer management system
      assert emulator.buffer == []
    end

    test "handles line deletion" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[3M")
      
      # Line deletion would be handled by the buffer management system
      assert emulator.buffer == []
    end
  end

  describe "text attributes" do
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
      emulator = ANSI.process_escape(emulator, "\e[24m")  # Reset underline
      
      assert emulator.attributes.bold == true
      assert emulator.attributes.underline == false
      assert emulator.attributes.reverse == true
    end
  end

  describe "cursor state" do
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
  end

  describe "character set switching" do
    test "sets character set for G0", %{integration: integration} do
      integration = Integration.set_character_set(integration, "0", "B")
      emulator = integration.emulator
      
      # Check that G0 is set to us_ascii
      g_sets = emulator.character_sets.g_sets
      assert g_sets.g0 == :us_ascii
    end

    test "invokes character set", %{integration: integration} do
      # Set G0 to us_ascii and G1 to latin1
      integration = Integration.set_character_set(integration, "0", "B")
      integration = Integration.set_character_set(integration, "1", "L")
      
      # Invoke G0
      integration = Integration.invoke_character_set(integration, "0")
      assert integration.emulator.character_sets.active_set == :us_ascii
      
      # Invoke G1
      integration = Integration.invoke_character_set(integration, "1")
      assert integration.emulator.character_sets.active_set == :latin1
    end
  end

  describe "screen modes" do
    test "sets and resets screen mode", %{integration: integration} do
      # Set alternate screen mode
      integration = Integration.set_screen_mode(integration, "?47")
      assert Integration.screen_mode_enabled?(integration, :alternate_screen)
      
      # Reset alternate screen mode
      integration = Integration.reset_screen_mode(integration, "?47")
      refute Integration.screen_mode_enabled?(integration, :alternate_screen)
    end

    test "switches to alternate buffer", %{integration: integration} do
      # Write some text to the main buffer
      integration = Integration.write(integration, "Hello, World!")
      
      # Switch to alternate buffer
      integration = Integration.switch_to_alternate_buffer(integration)
      
      # Check that the alternate buffer is empty
      assert integration.emulator.screen_buffer == Emulator.create_empty_buffer(80, 24)
      
      # Check that the main buffer is saved
      assert integration.emulator.alternate_buffer != nil
      
      # Switch back to main buffer
      integration = Integration.switch_to_main_buffer(integration)
      
      # Check that the main buffer is restored
      assert integration.emulator.screen_buffer != Emulator.create_empty_buffer(80, 24)
    end
  end

  describe "device status queries" do
    test "handles cursor position query", %{integration: integration} do
      # Move cursor to position (5, 10)
      integration = Integration.move_cursor(integration, 5, 10)
      
      # Query cursor position
      response = Integration.handle_device_status_query(integration, "6")
      
      # Check response format
      assert response =~ ~r/\e\[\d+;\d+R/
    end

    test "handles device attributes query", %{integration: integration} do
      # Query device attributes
      response = Integration.handle_device_status_query(integration, "0")
      
      # Check response
      assert response == "\e[?1;2c"
    end
  end

  describe "ANSI escape sequence parsing" do
    test "parses character set sequences", %{integration: integration} do
      # Process character set sequence
      emulator = ANSI.process_escape(integration.emulator, "\e[0B")
      
      # Check that G0 is set to us_ascii
      g_sets = emulator.character_sets.g_sets
      assert g_sets.g0 == :us_ascii
    end

    test "parses screen mode sequences", %{integration: integration} do
      # Process screen mode sequence
      emulator = ANSI.process_escape(integration.emulator, "\e[?47h")
      
      # Check that alternate screen mode is enabled
      assert emulator.screen_modes[:alternate_screen] == true
      
      # Process screen mode reset sequence
      emulator = ANSI.process_escape(emulator, "\e[?47l")
      
      # Check that alternate screen mode is disabled
      assert emulator.screen_modes[:alternate_screen] == nil
    end

    test "parses device status queries", %{integration: integration} do
      # Process device status query
      emulator = ANSI.process_escape(integration.emulator, "\e[6n")
      
      # Check that the query was processed
      assert emulator == integration.emulator
    end
  end

  describe "advanced text formatting" do
    test "handles double-height top sequence" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[#3")
      
      assert emulator.text_style.double_height == :top
      assert emulator.text_style.double_width == true
    end

    test "handles double-height bottom sequence" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[#4")
      
      assert emulator.text_style.double_height == :bottom
      assert emulator.text_style.double_width == true
    end

    test "handles single-width sequence" do
      emulator = Emulator.new(80, 24)
      emulator = %{emulator | text_style: %{emulator.text_style | double_width: true}}
      emulator = ANSI.process_escape(emulator, "\e[#5")
      
      assert emulator.text_style.double_width == false
      assert emulator.text_style.double_height == :none
    end

    test "handles double-width sequence" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[#6")
      
      assert emulator.text_style.double_width == true
      assert emulator.text_style.double_height == :none
    end
  end

  describe "device status reports" do
    test "handles cursor position report" do
      emulator = Emulator.new(80, 24)
      emulator = %{emulator | cursor: {5, 10}}
      emulator = ANSI.process_escape(emulator, "\e[6n")
      
      assert hd(emulator.output_buffer) == "\e[11;6R"
    end

    test "handles device status report" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[5n")
      
      assert hd(emulator.output_buffer) == "\e[0n"
    end

    test "handles device ok report" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[0n")
      
      assert hd(emulator.output_buffer) == "\e[0n"
    end

    test "handles device malfunction report" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[3n")
      
      assert hd(emulator.output_buffer) == "\e[3n"
    end
  end

  describe "terminal identification" do
    test "handles primary device attributes" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[c")
      
      assert hd(emulator.output_buffer) == "\e[?1;2c"
    end

    test "handles secondary device attributes" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[>c")
      
      assert hd(emulator.output_buffer) == "\e[>1;95;0c"
    end

    test "handles tertiary device attributes" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[=c")
      
      assert hd(emulator.output_buffer) == "\eP!|00000000\e\\"
    end

    test "handles fourth device attributes" do
      emulator = Emulator.new(80, 24)
      emulator = ANSI.process_escape(emulator, "\e[<c")
      
      assert hd(emulator.output_buffer) == "\eP>|Raxol 1.0.0\e\\"
    end
  end
end 