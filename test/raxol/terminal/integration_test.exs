defmodule Raxol.Terminal.IntegrationTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Integration

  @initial_state Integration.new(80, 24)

  describe "new/4" do
    test "creates a new integrated terminal system with default values" do
      integration = Integration.new(80, 24)
      assert integration.emulator.width == 80
      assert integration.emulator.height == 24
      assert integration.buffer_manager.active_buffer.width == 80
      assert integration.buffer_manager.active_buffer.height == 24
      assert integration.scroll_buffer.max_height == 1000
      assert integration.cursor_manager.position == {0, 0}
      assert integration.memory_limit == 50 * 1024 * 1024
    end

    test "creates a new integrated terminal system with custom scrollback height" do
      integration = Integration.new(80, 24, 2000)
      assert integration.scroll_buffer.max_height == 2000
    end

    test "creates a new integrated terminal system with custom memory limit" do
      integration = Integration.new(80, 24, 1000, 10_000_000)
      assert integration.memory_limit == 10_000_000
    end
  end

  describe "write/2" do
    test "writes text to the terminal with integrated buffer and cursor management" do
      integration = Integration.write(@initial_state, "Hello")
      content = Integration.get_visible_content(integration)
      assert content =~ "Hello"
      assert integration.cursor_manager.position == {5, 0}
      assert length(Integration.get_damage_regions(integration)) > 0
    end

    test "handles line wrapping with integrated buffer and cursor management" do
      long_text = String.duplicate("a", 85)
      integration = Integration.write(@initial_state, long_text)
      assert integration.cursor_manager.position == {5, 1}
    end

    test "updates scroll buffer when content exceeds screen height" do
      # Create a terminal with small height
      integration = Integration.new(80, 3)

      # Write multiple lines
      integration =
        Integration.write(integration, "Line 1\nLine 2\nLine 3\nLine 4")

      # Check scroll buffer
      assert Integration.get_scroll_height(integration) > 0
    end
  end

  describe "move_cursor/3" do
    test "moves the cursor to the specified position with integrated cursor management" do
      integration = Integration.move_cursor(@initial_state, 10, 5)
      assert integration.cursor_manager.position == {10, 5}
      assert integration.emulator.cursor_x == 10
      assert integration.emulator.cursor_y == 5
    end

    test "handles cursor movement bounds with integrated cursor management" do
      integration = Integration.move_cursor(@initial_state, -1, -1)
      assert integration.cursor_manager.position == {0, 0}

      integration = Integration.move_cursor(@initial_state, 100, 100)
      assert integration.cursor_manager.position == {79, 23}
    end
  end

  describe "clear_screen/1" do
    test "clears the screen with integrated buffer management" do
      integration = Integration.write(@initial_state, "Hello")
      integration = Integration.clear_screen(integration)

      content = Integration.get_visible_content(integration)
      assert content == String.duplicate(" ", 80 * 24)
      assert integration.cursor_manager.position == {0, 0}
      assert length(Integration.get_damage_regions(integration)) > 0
    end
  end

  describe "scroll/2" do
    test "scrolls the terminal content with integrated scroll buffer management" do
      integration = Integration.write(@initial_state, "Line 1\nLine 2\nLine 3")
      integration = Integration.scroll(integration, 1)

      content = Integration.get_visible_content(integration)
      assert content =~ "Line 2"
      assert content =~ "Line 3"
      assert Integration.get_scroll_position(integration) == 1
    end

    test "handles negative scroll amounts" do
      integration = Integration.write(@initial_state, "Line 1\nLine 2\nLine 3")
      integration = Integration.scroll(integration, 1)
      integration = Integration.scroll(integration, -1)

      assert Integration.get_scroll_position(integration) == 0
    end
  end

  describe "cursor management" do
    test "saves and restores cursor position with integrated cursor management" do
      integration = Integration.move_cursor(@initial_state, 10, 5)
      integration = Integration.save_cursor(integration)
      assert integration.cursor_manager.saved_position == {10, 5}

      integration = Integration.move_cursor(integration, 0, 0)
      integration = Integration.restore_cursor(integration)
      assert integration.cursor_manager.position == {10, 5}
    end

    test "shows and hides cursor with integrated cursor management" do
      integration = Integration.hide_cursor(@initial_state)
      assert integration.cursor_manager.state == :hidden
      assert integration.emulator.cursor_visible == false

      integration = Integration.show_cursor(integration)
      assert integration.cursor_manager.state == :visible
      assert integration.emulator.cursor_visible == true
    end

    test "sets cursor style with integrated cursor management" do
      integration = Integration.set_cursor_style(@initial_state, :underline)
      assert integration.cursor_manager.style == :underline
    end

    test "sets cursor blink rate with integrated cursor management" do
      integration = Integration.set_cursor_blink_rate(@initial_state, 1000)
      assert integration.cursor_manager.blink_rate == 1000
    end

    test "updates cursor blink state with integrated cursor management" do
      integration = Integration.set_cursor_style(@initial_state, :blinking)
      {_integration, visible} = Integration.update_cursor_blink(integration)
      assert is_boolean(visible)
    end
  end

  describe "scroll buffer management" do
    test "gets scroll position with integrated scroll buffer management" do
      integration = Integration.scroll(@initial_state, 5)
      assert Integration.get_scroll_position(integration) == 5
    end

    test "gets scroll height with integrated scroll buffer management" do
      integration = Integration.write(@initial_state, "Line 1\nLine 2\nLine 3")
      assert Integration.get_scroll_height(integration) > 0
    end

    test "gets scroll view with integrated scroll buffer management" do
      integration = Integration.write(@initial_state, "Line 1\nLine 2\nLine 3")
      view = Integration.get_scroll_view(integration, 2)
      assert is_list(view)
    end

    test "clears scroll buffer with integrated scroll buffer management" do
      integration = Integration.write(@initial_state, "Line 1\nLine 2\nLine 3")
      integration = Integration.clear_scroll_buffer(integration)
      assert Integration.get_scroll_height(integration) == 0
    end
  end

  describe "buffer management" do
    test "gets damage regions from the buffer manager" do
      integration = Integration.write(@initial_state, "Hello")
      regions = Integration.get_damage_regions(integration)
      assert length(regions) > 0
    end

    test "clears damage regions in the buffer manager" do
      integration = Integration.write(@initial_state, "Hello")
      integration = Integration.clear_damage_regions(integration)
      assert Integration.get_damage_regions(integration) == []
    end

    test "switches buffers in the buffer manager" do
      integration = Integration.write(@initial_state, "Hello")
      integration = Integration.switch_buffers(integration)

      assert integration.buffer_manager.active_buffer !=
               integration.buffer_manager.back_buffer
    end
  end

  describe "memory management" do
    test "updates memory usage tracking in the buffer manager" do
      integration = Integration.update_memory_usage(@initial_state)
      assert integration.buffer_manager.memory_usage > 0
    end

    test "checks if memory usage is within limits" do
      # Very low memory limit
      integration = Integration.new(80, 24, 1000, 100)
      integration = Integration.write(integration, String.duplicate("a", 1000))
      integration = Integration.update_memory_usage(integration)

      refute Integration.within_memory_limits?(integration)
    end
  end

  describe "new/3" do
    test "creates a new integration with default configuration" do
      integration = Integration.new(80, 24)
      assert integration.emulator.width == 80
      assert integration.emulator.height == 24
      assert integration.config.width == 80
      assert integration.config.height == 24
      assert integration.config.enable_command_history == true
      assert integration.command_history.max_size == 1000
    end

    test "creates a new integration with custom configuration" do
      integration =
        Integration.new(80, 24,
          command_history_size: 500,
          enable_command_history: false
        )

      assert integration.config.command_history_size == 500
      assert integration.config.enable_command_history == false
    end
  end

  describe "handle_input/2" do
    test "handles text input with command history enabled" do
      integration = Integration.new(80, 24)
      integration = Integration.handle_input(integration, "ls -la")
      assert integration.command_history.current_input == "ls -la"
    end

    test "handles text input with command history disabled" do
      integration = Integration.new(80, 24, enable_command_history: false)
      integration = Integration.handle_input(integration, "ls -la")
      assert integration.command_history.current_input == ""
    end

    test "handles up arrow with command history" do
      integration = Integration.new(80, 24)
      integration = Integration.execute_command(integration, "ls -la")
      integration = Integration.execute_command(integration, "cd /tmp")
      integration = Integration.handle_input(integration, :up_arrow)
      assert integration.command_history.current_index == 0
    end

    test "handles down arrow with command history" do
      integration = Integration.new(80, 24)
      integration = Integration.execute_command(integration, "ls -la")
      integration = Integration.execute_command(integration, "cd /tmp")
      integration = Integration.handle_input(integration, :up_arrow)
      integration = Integration.handle_input(integration, :down_arrow)
      assert integration.command_history.current_index == -1
    end
  end

  describe "execute_command/2" do
    test "adds command to history when enabled" do
      integration = Integration.new(80, 24)
      integration = Integration.execute_command(integration, "ls -la")
      assert length(integration.command_history.commands) == 1
      assert hd(integration.command_history.commands) == "ls -la"
    end

    test "does not add command to history when disabled" do
      integration = Integration.new(80, 24, enable_command_history: false)
      integration = Integration.execute_command(integration, "ls -la")
      assert integration.command_history.commands == []
    end
  end

  describe "update_config/2" do
    test "updates configuration successfully" do
      integration = Integration.new(80, 24)

      {:ok, integration} =
        Integration.update_config(integration, theme: "light")

      assert integration.config.theme == "light"
    end

    test "returns error for invalid configuration" do
      integration = Integration.new(80, 24)
      {:error, _reason} = Integration.update_config(integration, width: -1)
    end
  end
end
