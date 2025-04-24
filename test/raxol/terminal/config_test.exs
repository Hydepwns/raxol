defmodule Raxol.Terminal.ConfigTest do
  use ExUnit.Case
  alias Raxol.Terminal.Config
  alias Raxol.Terminal.Config.{Schema, Validation, Defaults, Capabilities}

  describe "config_schema/0" do
    test "returns a valid schema" do
      schema = Schema.config_schema()
      assert is_map(schema)
      assert Map.has_key?(schema, :display)
      assert Map.has_key?(schema, :input)
      assert Map.has_key?(schema, :rendering)
      assert Map.has_key?(schema, :ansi)
    end
  end

  describe "validate_config/1" do
    test "validates valid configuration" do
      config = Defaults.generate_default_config()
      assert {:ok, _validated} = Validation.validate_config(config)
    end

    test "rejects invalid configuration" do
      # Invalid color mode
      invalid_config = put_in(Defaults.generate_default_config(), [:ansi, :color_mode], :invalid_mode)
      assert {:error, _reason} = Validation.validate_config(invalid_config)

      # Invalid data type
      invalid_config = put_in(Defaults.generate_default_config(), [:display, :width], "not_an_integer")
      assert {:error, _reason} = Validation.validate_config(invalid_config)
    end
  end

  describe "generate_default_config/0" do
    test "generates valid default configuration" do
      config = Defaults.generate_default_config()
      assert is_map(config)
      assert Map.has_key?(config, :display)
      assert Map.has_key?(config, :input)
      assert Map.has_key?(config, :rendering)
      assert Map.has_key?(config, :ansi)
      assert Map.has_key?(config, :behavior)

      # Check if defaults are valid
      assert {:ok, _validated} = Validation.validate_config(config)
    end
  end

  describe "minimal_config/0" do
    test "generates valid minimal configuration" do
      config = Defaults.minimal_config()
      assert is_map(config)
      assert Map.has_key?(config, :display)
      assert Map.has_key?(config, :input)
      assert Map.has_key?(config, :rendering)
      assert Map.has_key?(config, :ansi)
      assert Map.has_key?(config, :behavior)

      # Check if defaults are valid
      assert {:ok, _validated} = Validation.validate_config(config)
    end
  end

  describe "detect_capabilities/0" do
    test "detects terminal capabilities" do
      capabilities = Capabilities.detect_capabilities()
      assert is_map(capabilities)
      assert Map.has_key?(capabilities, :display)
      assert Map.has_key?(capabilities, :input)
      assert Map.has_key?(capabilities, :ansi)
    end
  end

  describe "optimized_config/0" do
    test "generates optimized configuration" do
      config = Capabilities.optimized_config()
      assert is_map(config)
      assert Map.has_key?(config, :display)
      assert Map.has_key?(config, :input)
      assert Map.has_key?(config, :rendering)
      assert Map.has_key?(config, :ansi)
      assert Map.has_key?(config, :behavior)

      # Check if optimized config is valid
      assert {:ok, _validated} = Validation.validate_config(config)
    end
  end

  describe "facade module" do
    test "provides access to all underlying module functions" do
      # Test Schema functions
      assert is_map(Config.config_schema())

      # Test Validation functions
      config = Config.generate_default_config()
      assert {:ok, _validated} = Config.validate_config(config)

      # Test capabilities functions
      assert is_map(Config.detect_capabilities())
      assert is_map(Config.optimized_config())

      # Test default functions
      assert is_map(Config.generate_default_config())
      assert is_map(Config.minimal_config())
    end
  end
end
