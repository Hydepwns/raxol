defmodule Raxol.Terminal.ConfigTest do
  use ExUnit.Case, async: true

  # Aliases for the modules under test
  alias Raxol.Terminal.Config
  alias Raxol.Terminal.Config.{Validation, Defaults, Capabilities, Schema}

  # Updated valid config based on flat schema
  @valid_config %{
    terminal_type: :xterm,
    color_mode: :truecolor,
    unicode_support: true,
    mouse_support: true,
    clipboard_support: true,
    bracketed_paste: true,
    focus_support: true,
    title_support: true,
    hyperlinks: true,
    sixel_support: false,
    image_support: false,
    sound_support: true,
    width: 80,
    height: 24,
    font_family: "monospace",
    font_size: 12,
    cursor_style: :block,
    cursor_blink: true,
    cursor_color: "#FFFFFF",
    selection_color: "rgba(100, 100, 100, 0.5)",
    line_height: 1.2,
    ligatures: false,
    font_rendering: :antialiased,
    batch_size: 100,
    scrollback_limit: 1000,
    prompt: "> ",
    welcome_message: "Welcome!",
    command_history_size: 500,
    enable_command_history: true,
    enable_syntax_highlighting: true,
    enable_fullscreen: false,
    accessibility_mode: false,
    virtual_scroll: true,
    memory_limit: 1_000_000_000,
    cleanup_interval: 60_000,
    background_type: :solid,
    background_opacity: 1.0,
    background_image: nil,
    background_blur: 0.0,
    background_scale: :fit,
    animation_type: nil,
    animation_path: nil,
    animation_fps: nil,
    animation_loop: nil,
    animation_blend: nil
  }

  describe "Schema" do
    # ... tests for Schema ...
  end

  describe "Validation" do
    test "validate_config/1 validates valid configuration" do
      assert {:ok, validated} = Validation.validate_config(@valid_config)
      # Check if validated config matches input (assuming validation doesn't change values here)
      assert validated == @valid_config
    end

    test "validate_config/1 rejects invalid configuration (unknown key)" do
      invalid_config = Map.put(@valid_config, :unknown_key, "value")
      assert {:error, reason} = Validation.validate_config(invalid_config)
      IO.inspect(reason, label: "Unknown Key Reason") # Debug output
      assert String.contains?(reason, "Unknown configuration keys")
      assert String.contains?(reason, ":unknown_key")
    end

    test "validate_config/1 rejects invalid configuration (wrong type)" do
      # Use a key that expects boolean, give it a string
      invalid_config = Map.put(@valid_config, :unicode_support, "not_a_boolean")
      assert {:error, reason} = Validation.validate_config(invalid_config)
      IO.inspect(reason, label: "Wrong Type Reason") # Debug output
      assert String.contains?(reason, "Invalid value")
      assert String.contains?(reason, "[:unicode_support]")
    end

    test "validate_config/1 rejects invalid configuration (bad enum value)" do
      # Use a key that expects enum, give it a wrong atom
      invalid_config = Map.put(@valid_config, :cursor_style, :invalid_style)
      assert {:error, reason} = Validation.validate_config(invalid_config)
      IO.inspect(reason, label: "Bad Enum Reason") # Debug output
      assert String.contains?(reason, "not one of")
      assert String.contains?(reason, "[:cursor_style]")
    end
  end

  describe "Defaults" do
    test "generate_default_config/0 generates valid default configuration" do
      config = Defaults.generate_default_config()
      assert is_map(config)
      # Validate the generated default config
      assert {:ok, _validated} = Validation.validate_config(config)
    end

    # Test for minimal_config needs to be added if the function exists
    # test "minimal_config/0 generates valid minimal configuration" do
    #   # Check if Defaults.minimal_config/0 exists
    #   if function_exported?(Defaults, :minimal_config, 0) do
    #     config = Defaults.minimal_config()
    #     assert {:ok, _validated} = Validation.validate_config(config)
    #   else
    #     # Skip or mark as pending if function doesn't exist
    #     assert true # Or use ExUnit tags to skip
    #   end
    # end
  end

  describe "Capabilities" do
    # Tests for Capabilities.optimized_config might need setup/mocking
    # test "optimized_config/0 generates optimized configuration" do
    #   # Mocking :ets or system calls might be required here
    #   # Example: :meck.expect(:ets, :lookup, fn(:raxol_terminal_capabilities, :truecolor) -> {:ok, true} end)
    #   # config = Capabilities.optimized_config()
    #   # assert {:ok, _validated} = Validation.validate_config(config)
    #   # assert config.rendering == ... # Check optimized values
    #   # :meck.unload(:ets)
    #   assert true # Placeholder
    # end
  end

  describe "Config Facade (if applicable)" do
    # This test might be obsolete if Config is not intended as a facade
    # test "facade module provides access to underlying module functions" do
    #   # Example: Test calling validation via Config
    #   # assert {:ok, _} = Config.validate(@valid_config)
    #
    #   # Example: Test calling defaults via Config
    #   # assert is_map(Config.defaults())
    #   assert true # Placeholder
    # end
  end
end
