defmodule Raxol.Terminal.ConfigTest do
  use ExUnit.Case, async: true
  import Mox

  # Aliases for the modules under test
  alias Raxol.Terminal.Config
  alias Raxol.Terminal.Config.{Validation, Defaults, Capabilities, Schema}
  # Added for mocking
  alias Raxol.System.EnvironmentAdapterBehaviour

  # Define the mock for the EnvironmentAdapterBehaviour
  Mox.defmock(EnvironmentAdapterMock, for: EnvironmentAdapterBehaviour)

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
    background_image: "",
    background_blur: 0.0,
    background_scale: :fit,
    animation_type: :gif,
    animation_path: "",
    animation_fps: 30,
    animation_loop: true,
    animation_blend: 0.0
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
      # Debug output
      IO.inspect(reason, label: "Unknown Key Reason")
      assert String.contains?(reason, "Unknown configuration keys")
      assert String.contains?(reason, ":unknown_key")
    end

    test "validate_config/1 rejects invalid configuration (wrong type)" do
      # Use a key that expects boolean, give it a string
      invalid_config = Map.put(@valid_config, :unicode_support, "not_a_boolean")
      assert {:error, reason} = Validation.validate_config(invalid_config)
      # Debug output
      IO.inspect(reason, label: "Wrong Type Reason")
      assert String.contains?(reason, "Invalid value")
      assert String.contains?(reason, "[:unicode_support]")
    end

    test "validate_config/1 rejects invalid configuration (bad enum value)" do
      # Use a key that expects enum, give it a wrong atom
      invalid_config = Map.put(@valid_config, :cursor_style, :invalid_style)
      assert {:error, reason} = Validation.validate_config(invalid_config)
      # Debug output
      IO.inspect(reason, label: "Bad Enum Reason")
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
    # Add Mox verification
    setup :verify_on_exit!

    test "optimized_config/1 generates optimized configuration based on detected capabilities" do
      # Mock adapter calls
      EnvironmentAdapterMock
      |> expect(:get_env, fn
        "COLUMNS" -> "120"
        "LINES" -> "40"
        "COLORTERM" -> "truecolor"
        "TERM" -> "xterm-256color"
        "LANG" -> "en_US.UTF-8"
        "DISPLAY" -> ":0"
        _ -> nil
      end)
      |> expect(:cmd, fn
        # Fallback if COLORTERM is not truecolor
        "tput", ["colors"], _ -> {"256", 0}
        # Default for other tput calls if COLUMNS/LINES not set
        "tput", _, _ -> {"", 1}
      end)

      # Get the optimized config using the mock adapter
      config = Capabilities.optimized_config(EnvironmentAdapterMock)

      # Validate the generated config
      assert {:ok, validated_config} = Validation.validate_config(config)

      # Assert specific capabilities reflected in the config
      # These assertions depend on how `optimize_config_for_capabilities` and `deep_merge_capabilities` work
      # We are primarily testing that the detection part, which now uses the mock, influences the config.

      # Assertions based on mocked environment:
      assert validated_config.width == 120
      assert validated_config.height == 40
      # Directly from COLORTERM="truecolor"
      assert validated_config.color_mode == :truecolor
      # From COLORTERM="truecolor"
      assert validated_config.truecolor == true
      # From LANG="en_US.UTF-8"
      assert validated_config.unicode_support == true
      # From TERM="xterm-256color"
      assert validated_config.mouse_support == true
      # From DISPLAY=":0"
      assert validated_config.clipboard_support == true
      # From TERM="xterm-256color"
      assert validated_config.ansi_enabled == true
    end
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
