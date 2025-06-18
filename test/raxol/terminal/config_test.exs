defmodule Raxol.Terminal.ConfigTest do
  use ExUnit.Case, async: true
  use Raxol.DataCase
  import Mox
  # import Raxol.TestHelpers
  import Raxol.Test.TestHelper

  # Aliases for the modules under test
  alias Raxol.Terminal.Config
  alias Raxol.Terminal.Config.{Validation, Defaults, Capabilities, Schema}
  alias Raxol.Terminal.Config.EnvironmentAdapterBehaviour

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

  setup do
    # Clean up any existing config files
    File.rm_rf!("tmp/configs")
    File.mkdir_p!("tmp/configs")

    config = Config.new()
    %{config: config}
  end

  describe "Schema" do
    test 'schema/0 returns a valid schema' do
      schema = Schema.schema()
      assert is_map(schema)
      assert map_size(schema) > 0
    end

    test 'schema/0 includes all required fields' do
      schema = Schema.schema()

      required_fields = [
        :terminal_type,
        :color_mode,
        :unicode_support,
        :width,
        :height
      ]

      for field <- required_fields do
        assert Map.has_key?(schema, field)
      end
    end

    test 'schema/0 validates field types' do
      schema = Schema.schema()

      assert is_map(schema.terminal_type) and
               Map.has_key?(schema.terminal_type, :type),
             "Expected schema.terminal_type to be a map with :type key, got: #{inspect(schema.terminal_type)}"

      assert schema.terminal_type.type == :atom

      assert is_map(schema.color_mode) and
               Map.has_key?(schema.color_mode, :type),
             "Expected schema.color_mode to be a map with :type key, got: #{inspect(schema.color_mode)}"

      assert schema.color_mode.type == :atom

      assert is_map(schema.unicode_support) and
               Map.has_key?(schema.unicode_support, :type),
             "Expected schema.unicode_support to be a map with :type key, got: #{inspect(schema.unicode_support)}"

      assert schema.unicode_support.type == :boolean

      assert is_map(schema.width) and Map.has_key?(schema.width, :type),
             "Expected schema.width to be a map with :type key, got: #{inspect(schema.width)}"

      assert schema.width.type == :integer

      assert is_map(schema.height) and Map.has_key?(schema.height, :type),
             "Expected schema.height to be a map with :type key, got: #{inspect(schema.height)}"

      assert schema.height.type == :integer
    end
  end

  describe "Validation" do
    test 'validate_config/1 validates valid configuration' do
      assert {:ok, validated} = Validation.validate_config(@valid_config)
      assert validated == @valid_config
    end

    test 'validate_config/1 rejects invalid configuration (unknown key)' do
      invalid_config = Map.put(@valid_config, :unknown_key, "value")
      assert {:error, reason} = Validation.validate_config(invalid_config)
      assert String.contains?(reason, "Unknown configuration keys")
      assert String.contains?(reason, ":unknown_key")
    end

    test 'validate_config/1 rejects invalid configuration (wrong type)' do
      invalid_config = Map.put(@valid_config, :unicode_support, "not_a_boolean")
      assert {:error, reason} = Validation.validate_config(invalid_config)
      assert String.contains?(reason, "Invalid value")
      assert String.contains?(reason, "[:unicode_support]")
    end

    test 'validate_config/1 rejects invalid configuration (bad enum value)' do
      invalid_config = Map.put(@valid_config, :cursor_style, :invalid_style)
      assert {:error, reason} = Validation.validate_config(invalid_config)
      assert String.contains?(reason, "not one of")
      assert String.contains?(reason, "[:cursor_style]")
    end
  end

  describe "Defaults" do
    test 'generate_default_config/0 generates valid default configuration' do
      config = Defaults.generate_default_config()
      assert is_map(config)
      assert {:ok, _validated} = Validation.validate_config(config)
    end

    test 'minimal_config/0 generates valid minimal configuration' do
      config = Defaults.minimal_config()
      assert is_map(config)
      assert {:ok, _validated} = Validation.validate_config(config)
    end
  end

  describe "Capabilities" do
    setup :verify_on_exit!

    test 'optimized_config/1 generates optimized configuration based on detected capabilities' do
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
        "tput", ["colors"], _ -> {"256", 0}
        "tput", _, _ -> {"", 1}
      end)

      # Get the optimized config using the mock adapter
      config = Capabilities.optimized_config(EnvironmentAdapterMock)

      # Validate the generated config
      assert {:ok, validated_config} = Validation.validate_config(config)

      # Assert specific capabilities reflected in the config
      assert validated_config.width == 120
      assert validated_config.height == 40
      assert validated_config.color_mode == :truecolor
      assert validated_config.truecolor == true
      assert validated_config.unicode_support == true
      assert validated_config.mouse_support == true
      assert validated_config.clipboard_support == true
      assert validated_config.ansi_enabled == true
    end
  end

  describe "Config Facade (if applicable)" do
    # This test might be obsolete if Config is not intended as a facade
    # test 'facade module provides access to underlying module functions' do
    #   # Example: Test calling validation via Config
    #   # assert {:ok, _} = Config.validate(@valid_config)
    #
    #   # Example: Test calling defaults via Config
    #   # assert is_map(Config.defaults())
    #   assert true # Placeholder
    # end
  end

  describe "configuration validation" do
    test "validates dimensions", %{config: config} do
      # Valid dimensions
      assert {:ok, updated} = Config.update(config, %{width: 100, height: 50})
      assert updated.width == 100
      assert updated.height == 50

      # Invalid dimensions
      assert {:error, _} = Config.update(config, %{width: -1, height: 50})
      assert {:error, _} = Config.update(config, %{width: 100, height: 0})
    end

    test "validates colors", %{config: config} do
      # Valid colors
      valid_colors = %{
        background: {0, 0, 0},
        foreground: {255, 255, 255}
      }

      assert {:ok, updated} = Config.update(config, %{colors: valid_colors})
      assert updated.colors == valid_colors

      # Invalid colors
      invalid_colors = %{
        background: {300, 0, 0},
        foreground: {0, 0, 300}
      }

      assert {:error, _} = Config.update(config, %{colors: invalid_colors})
    end

    test "validates styles", %{config: config} do
      # Valid styles
      valid_styles = %{
        bold: true,
        italic: false,
        underline: :single
      }

      assert {:ok, updated} = Config.update(config, %{styles: valid_styles})
      assert updated.styles == valid_styles

      # Invalid styles
      invalid_styles = %{
        bold: "true",
        italic: 1
      }

      assert {:error, _} = Config.update(config, %{styles: invalid_styles})
    end
  end

  describe "configuration persistence" do
    test "can save and load configuration", %{config: config} do
      # Save configuration
      assert :ok = Config.save(config, "test_config")

      # Load configuration
      assert {:ok, loaded_config} = Config.load("test_config")
      assert loaded_config.width == config.width
      assert loaded_config.height == config.height
    end

    test 'can list saved configurations' do
      # Create and save multiple configurations
      config1 = Config.new(80, 24)
      config2 = Config.new(100, 50)

      Config.save(config1, "config1")
      Config.save(config2, "config2")

      # List configurations
      assert {:ok, configs} = Config.list_saved()
      assert length(configs) == 2
      assert "config1" in configs
      assert "config2" in configs
    end

    test "handles configuration migration", %{config: config} do
      # Save v1 configuration
      assert :ok = Config.save(config, "migrate_test")

      # Simulate version update
      Application.put_env(:raxol, :config_version, 2)

      # Load and verify migration
      assert {:ok, migrated_config} = Config.load("migrate_test")
      assert migrated_config.version == 2
      assert Map.has_key?(migrated_config.performance, :render_buffer_size)
    end

    test 'handles invalid configuration data' do
      # Try to load non-existent configuration
      assert {:error, _} = Config.load("nonexistent")

      # Try to load invalid configuration file
      File.write!("tmp/configs/invalid.config", "invalid data")
      assert {:error, _} = Config.load("invalid")
    end
  end
end
