defmodule Raxol.Terminal.ConfigurationTest do
  use ExUnit.Case
  alias Raxol.System.TerminalPlatform
  alias Raxol.Terminal.Configuration

  describe "new/0" do
    test "creates a configuration with detected terminal type" do
      config = Configuration.new()
      assert is_map(config)

      assert config.terminal_type in [
               :iterm2,
               :windows_terminal,
               :xterm,
               :screen,
               :unknown
             ]
    end

    test "detects color mode based on terminal capabilities" do
      config = Configuration.new()
      assert config.color_mode in [:basic, :true_color, :palette]
    end

    test "sets appropriate font family based on terminal type" do
      config = Configuration.new()
      assert is_binary(config.font_family)

      assert config.font_family in [
               "Fira Code",
               "Cascadia Code",
               "DejaVu Sans Mono",
               "Monospace"
             ]
    end

    test "sets appropriate font size based on terminal type" do
      config = Configuration.new()
      assert is_integer(config.font_size)
      assert config.font_size in [12, 14]
    end

    test "sets appropriate line height based on terminal type" do
      config = Configuration.new()
      assert is_float(config.line_height)
      assert config.line_height in [1.0, 1.1, 1.2]
    end

    test "sets appropriate cursor style based on terminal type" do
      config = Configuration.new()
      assert config.cursor_style in [:block, :underline, :bar]
    end

    test "sets appropriate scrollback limit based on terminal type" do
      config = Configuration.new()
      assert is_integer(config.scrollback_limit)
      assert config.scrollback_limit in [1000, 5000, 10000]
    end

    test "sets appropriate batch size based on terminal type" do
      config = Configuration.new()
      assert is_integer(config.batch_size)
      assert config.batch_size in [100, 150, 200]
    end

    test "sets appropriate theme based on terminal type and color mode" do
      config = Configuration.new()
      assert is_map(config.theme)
      assert Map.has_key?(config.theme, :background)
      assert Map.has_key?(config.theme, :foreground)
    end
  end

  describe "get_preset/1" do
    test "returns iTerm2 preset" do
      config = Configuration.get_preset(:iterm2)
      assert config.terminal_type == :iterm2
      assert config.color_mode == :true_color
      assert config.font_family == "Fira Code"
      assert config.font_size == 14
      assert config.line_height == 1.2
      assert config.cursor_style == :block
      assert config.cursor_blink == true
      assert config.scrollback_limit == 10000
      assert config.batch_size == 200
      assert config.virtual_scroll == true
    end

    test "returns Windows Terminal preset" do
      config = Configuration.get_preset(:windows_terminal)
      assert config.terminal_type == :windows_terminal
      assert config.color_mode == :true_color
      assert config.font_family == "Cascadia Code"
      assert config.font_size == 12
      assert config.line_height == 1.1
      assert config.cursor_style == :block
      assert config.cursor_blink == true
      assert config.scrollback_limit == 5000
      assert config.batch_size == 150
      assert config.virtual_scroll == true
    end

    test "returns xterm preset" do
      config = Configuration.get_preset(:xterm)
      assert config.terminal_type == :xterm
      assert config.color_mode == :palette
      assert config.font_family == "DejaVu Sans Mono"
      assert config.font_size == 12
      assert config.line_height == 1.0
      assert config.cursor_style == :underline
      assert config.cursor_blink == true
      assert config.scrollback_limit == 1000
      assert config.batch_size == 100
      assert config.virtual_scroll == false
    end

    test "returns screen preset" do
      config = Configuration.get_preset(:screen)
      assert config.terminal_type == :screen
      assert config.color_mode == :palette
      assert config.font_family == "DejaVu Sans Mono"
      assert config.font_size == 12
      assert config.line_height == 1.0
      assert config.cursor_style == :underline
      assert config.cursor_blink == false
      assert config.scrollback_limit == 1000
      assert config.batch_size == 100
      assert config.virtual_scroll == false
    end

    test "returns default preset for unknown terminal type" do
      config = Configuration.get_preset(:unknown)
      assert config.terminal_type == :unknown
      assert config.color_mode == :basic
      assert config.font_family == "Monospace"
      assert config.font_size == 12
      assert config.line_height == 1.0
      assert config.cursor_style == :block
      assert config.cursor_blink == true
      assert config.scrollback_limit == 1000
      assert config.batch_size == 100
      assert config.virtual_scroll == false
    end
  end

  describe "apply/1" do
    test "applies configuration settings" do
      config = Configuration.new()
      assert :ok == Configuration.apply(config)
    end

    test "saves relevant settings to user preferences" do
      config = Configuration.new()
      Configuration.apply(config)

      # Verify that settings were saved to preferences
      saved_config = Raxol.Core.UserPreferences.get(:terminal_config)
      assert is_map(saved_config)
      assert Map.has_key?(saved_config, :font_family)
      assert Map.has_key?(saved_config, :font_size)
      assert Map.has_key?(saved_config, :line_height)
      assert Map.has_key?(saved_config, :cursor_style)
      assert Map.has_key?(saved_config, :cursor_blink)
      assert Map.has_key?(saved_config, :theme)
    end
  end
end
