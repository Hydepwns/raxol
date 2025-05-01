defmodule Raxol.Terminal.ConfigTest do
  use ExUnit.Case, async: true

  # Aliases for the modules under test
  alias Raxol.Terminal.Config
  alias Raxol.Terminal.Config.{Validation, Defaults, Capabilities, Schema}

  # A configuration map matching the nested Schema structure
  @valid_config %{
    display: %{
      width: 80,
      height: 24,
      colors: 256,
      truecolor: true,
      unicode: true
    },
    input: %{
      mouse: true,
      keyboard: true,
      escape_timeout: 50
    },
    rendering: %{
      fps: 60,
      double_buffer: true,
      redraw_mode: :incremental
    },
    ansi: %{
      enabled: true,
      color_mode: :truecolor
    }
    # Add other sections/fields if needed for specific tests
  }

  describe "Validation" do
    test "validate_config/1 validates valid configuration" do
      assert {:ok, validated} = Validation.validate_config(@valid_config)
      # Check if the validated output is the same as input (or transformed if validation does that)
      assert validated == @valid_config
    end

    test "validate_config/1 rejects invalid configuration (unknown key)" do
      invalid_config = put_in(@valid_config, [:display, :invalid_key], :bad_value)
      assert {:error, reason} = Validation.validate_config(invalid_config)
      assert String.contains?(reason, "Unknown configuration keys")
      assert String.contains?(reason, "[:display]")
      assert String.contains?(reason, "[:invalid_key]")
    end

    test "validate_config/1 rejects invalid configuration (wrong type)" do
      invalid_config = put_in(@valid_config, [:display, :width], "not_an_integer")
      assert {:error, reason} = Validation.validate_config(invalid_config)
      assert String.contains?(reason, "Invalid value")
      assert String.contains?(reason, "[:display, :width]")
      assert String.contains?(reason, ":integer")
    end

    test "validate_config/1 rejects invalid configuration (bad enum value)" do
      invalid_config = put_in(@valid_config, [:rendering, :redraw_mode], :bad_enum)
      assert {:error, reason} = Validation.validate_config(invalid_config)
      assert String.contains?(reason, "not one of")
      assert String.contains?(reason, "[:rendering, :redraw_mode]")
      assert String.contains?(reason, "[:full, :incremental]")
    end
  end

  describe "Defaults" do
    test "generate_default_config/0 generates valid default configuration" do
      config = Defaults.generate_default_config()
      # Validate the generated default config against the schema
      assert {:ok, _validated} = Validation.validate_config(config)
      # Check a few key default values based on Schema/Defaults implementation
      assert Map.get(config, :display, %{})[:width] == 80 # Example check
      assert Map.get(config, :rendering, %{})[:fps] == 60 # Example check
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
