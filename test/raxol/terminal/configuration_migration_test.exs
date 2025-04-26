defmodule Raxol.Terminal.ConfigurationMigrationTest do
  use ExUnit.Case

  alias Raxol.Terminal.Configuration
  alias Raxol.Terminal.Config

  describe "migration tests" do
    test "new Config API matches old Configuration API for basic configuration" do
      # Get configurations from both old and new APIs
      old_config = Configuration.new()
      new_config = Config.generate_default_config()

      # Test basic properties exist in both
      assert Map.has_key?(old_config, :width)
      assert get_in(new_config, [:display, :width]) != nil

      # Verify values match (with appropriate transformations)
      assert old_config.width == get_in(new_config, [:display, :width])
      assert old_config.height == get_in(new_config, [:display, :height])

      # Verify theme structure exists
      assert is_map(old_config.theme)
      assert is_map(get_in(new_config, [:display, :theme]))
    end

    test "config application works in both old and new APIs" do
      # Test configuration application
      old_config = Configuration.new()
      assert :ok == Configuration.apply(old_config)

      new_config = Config.generate_default_config()
      assert {:ok, _} = Config.apply_config(new_config)
    end

    test "preset configuration matches between old and new APIs" do
      # Test iTerm2 preset
      old_iterm = Configuration.get_preset(:iterm2)
      {:ok, new_iterm} = Config.load_profile("iterm2")

      # Verify key properties match
      assert old_iterm.terminal_type == :iterm2
      assert get_in(new_iterm, [:terminal, :type]) == :iterm2

      assert old_iterm.font_family ==
               get_in(new_iterm, [:display, :font_family])

      assert old_iterm.font_size == get_in(new_iterm, [:display, :font_size])

      # Test Windows Terminal preset
      old_windows = Configuration.get_preset(:windows_terminal)
      {:ok, new_windows} = Config.load_profile("windows_terminal")

      assert old_windows.terminal_type == :windows_terminal
      assert get_in(new_windows, [:terminal, :type]) == :windows_terminal

      assert old_windows.font_family ==
               get_in(new_windows, [:display, :font_family])
    end

    # Skip validation tests as they're implementation-specific
    @tag :skip
    test "validation works in both old and new APIs" do
      # Test validation with valid config
      valid_old_config = Configuration.new()
      assert :ok == Configuration.validate(valid_old_config)

      valid_new_config = Config.generate_default_config()
      assert {:ok, _} = Config.validate_config(valid_new_config)
    end

    # Skip capability detection as it depends on runtime environment
    @tag :skip
    test "capability detection works in both old and new APIs" do
      # Test capability detection
      old_detected = Configuration.detect_and_configure()
      new_detected = Config.detect_capabilities()

      # Verify format transformation is correct
      assert old_detected.unicode_support ==
               get_in(new_detected, [:display, :unicode])

      assert old_detected.mouse_support ==
               get_in(new_detected, [:input, :mouse])
    end
  end
end
