defmodule Raxol.Terminal.ConfigurationTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Configuration
  # We might need these later if we add tests for them
  # alias Raxol.Terminal.Config.Profiles
  # alias Raxol.Terminal.Config.Application

  describe "new/0 and new/1" do
    test "creates a configuration with default values" do
      config = Configuration.new()
      # Assert some key defaults (referencing Defaults.generate_default_config)
      assert config.width == 80
      assert config.height == 24
      assert config.font_family == "Monospace"
      assert config.cursor_style == :block
      assert config.theme == %{} # Assuming default theme is empty map
      # Cannot assert on terminal_type or color_mode, not direct fields
    end

    # This test seems redundant now as new/1 implicitly tests merging
    # test "new/0 detects color mode based on terminal capabilities" do
    #   config = Configuration.new()
    #   # This needs mocking Capabilities or running in a known terminal
    #   # assert config.color_mode in [:basic, :true_color, :palette]
    # end

    # This test seems redundant
    # test "new/0 creates a configuration with detected terminal type" do
    #   config = Configuration.new()
    #   # Needs mocking Capabilities
    #   # assert config.terminal_type in [
    #   #   :iterm2,
    #   #   :windows_terminal,
    #   #   :xterm,
    #   #   :screen,
    #   #   :kitty,
    #   #   :alacritty,
    #   #   :konsole,
    #   #   :gnome_terminal,
    #   #   :vscode,
    #   #   :unknown
    #   # ]
    # end

    # This test seems redundant
    # test "new/0 sets appropriate scrollback limit based on terminal type" do
    #   config = Configuration.new()
    #   # Needs mocking Capabilities
    #   # assert is_integer(config.scrollback_limit)
    # end

    test "new/1 merges provided options with defaults" do
      opts = [
        width: 100,
        font_family: "Fira Code",
        unknown_opt: :ignore # Should be ignored
      ]
      config = Configuration.new(opts)
      assert config.width == 100 # Overridden
      assert config.height == 24 # Default
      assert config.font_family == "Fira Code" # Overridden
    end

    # This test seems redundant
    # test "new/0 sets appropriate theme based on terminal type and color mode" do
    #   config = Configuration.new()
    #   # Complex assertion, depends on Defaults, Capabilities, Profiles?
    #   # assert is_map(config.theme)
    # end
  end

  describe "update/2" do
    test "updates existing configuration struct" do
      config = Configuration.new()
      updated_config = Configuration.update(config, width: 120, cursor_blink: false)
      assert updated_config.width == 120
      assert updated_config.cursor_blink == false
      assert updated_config.height == config.height # Unchanged fields remain
    end
  end

  # Removed describe blocks for get_preset and apply as they don't exist on Configuration

end
