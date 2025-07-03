defmodule Raxol.Core.Config.ManagerTest do
  @moduledoc """
  Tests for the configuration management system, including loading, validation,
  persistence, and error handling of configuration values.
  """
  use ExUnit.Case, async: false
  import Raxol.Guards
  alias Raxol.Core.Config.Manager

  setup do
    # Create a temporary config file for testing
    temp_file = Path.join(System.tmp_dir!(), "raxol_test_config.json")

    # Create a minimal valid config file
    config_content = """
    %{
      dev: %{
        terminal: %{
          width: 80,
          height: 24,
          mode: :normal
        },
        buffer: %{
          max_size: 1000,
          scrollback: 100
        },
        renderer: %{
          mode: :gpu,
          double_buffering: true
        }
      }
    }
    """

    config_file = Path.join(System.tmp_dir!(), "raxol_test_config.exs")
    File.write!(config_file, config_content)

    # Start the manager with the temp file
    {:ok, pid} = Manager.start_link(
      config_file: config_file,
      persistent_file: temp_file,
      env: :dev,
      validate: false  # Disable validation for tests
    )

    on_exit(fn ->
      # Clean up the temp files
      File.rm(temp_file)
      File.rm(config_file)
    end)

    {:ok, %{temp_file: temp_file, config_file: config_file, pid: pid}}
  end

  describe "configuration loading" do
    test "loads configuration from file" do
      assert {:ok, _} = Manager.reload()
      assert map?(Manager.get_all())
    end

    test "handles missing configuration file" do
      {:ok, _} =
        Manager.start_link(
          config_file: "nonexistent.exs",
          validate: false
        )

      assert %{} = Manager.get_all()
    end

    test "validates required configuration fields" do
      {:ok, _} =
        Manager.start_link(
          config_file: "test/fixtures/invalid_config.exs",
          validate: true
        )

      assert {:error, _} = Manager.reload()
    end
  end

  describe "configuration access" do
    test "gets configuration value" do
      assert {:ok, _} = Manager.reload()
      assert integer?(Manager.get(:terminal_width))
    end

    test "returns default value for missing key" do
      assert :default = Manager.get(:nonexistent_key, :default)
    end

    test "gets all configuration values" do
      assert {:ok, _} = Manager.reload()
      config = Manager.get_all()
      assert map?(config)
      assert Map.has_key?(config, :terminal)
      assert Map.has_key?(config, :buffer)
      assert Map.has_key?(config, :renderer)
    end
  end

  describe "configuration updates" do
    test "sets configuration value" do
      assert :ok = Manager.set(:terminal_width, 100)
      assert 100 = Manager.get(:terminal_width)
    end

    test "validates configuration value" do
      assert {:error, _} = Manager.set(:terminal_width, -1)
      assert {:error, _} = Manager.set(:terminal_mode, :invalid)
    end

    test "updates configuration value" do
      assert :ok = Manager.set(:terminal_width, 100)
      assert :ok = Manager.update(:terminal_width, &(&1 + 50))
      assert 150 = Manager.get(:terminal_width)
    end

    test "deletes configuration value" do
      assert :ok = Manager.set(:custom_key, "value")
      assert :ok = Manager.delete(:custom_key)
      assert nil == Manager.get(:custom_key)
    end
  end

  describe "configuration validation" do
    test "validates terminal configuration" do
      assert :ok = Manager.set(:terminal_width, 100)
      assert :ok = Manager.set(:terminal_height, 50)
      assert :ok = Manager.set(:terminal_mode, :normal)
      assert {:error, _} = Manager.set(:terminal_width, -1)
      assert {:error, _} = Manager.set(:terminal_mode, :invalid)
    end

    test "validates buffer configuration" do
      assert :ok = Manager.set(:buffer_max_size, 1000)
      assert :ok = Manager.set(:buffer_scrollback, 100)
      assert {:error, _} = Manager.set(:buffer_max_size, -1)
      assert {:error, _} = Manager.set(:buffer_scrollback, -1)
    end

    test "validates renderer configuration" do
      assert :ok = Manager.set(:renderer_mode, :gpu)
      assert :ok = Manager.set(:renderer_double_buffering, true)
      assert {:error, _} = Manager.set(:renderer_mode, :invalid)
      assert {:error, _} = Manager.set(:renderer_double_buffering, "invalid")
    end
  end

  describe "configuration persistence" do
    test "persists configuration changes", %{temp_file: temp_file} do
      # Set a configuration value
      assert :ok = Manager.set(:test_key, "test_value", persist: true)

      # Verify the value is set
      assert "test_value" = Manager.get(:test_key)

      # Check that the value was persisted to file
      assert File.exists?(temp_file)

      # Read the file and verify content
      {:ok, content} = File.read(temp_file)
      {:ok, config} = Jason.decode(content)
      assert config["test_key"] == "test_value"
    end

    test "loads persisted configuration on startup", %{temp_file: temp_file} do
      # Create a persistent config file with some data
      initial_config = %{"persisted_key" => "persisted_value"}
      {:ok, json_content} = Jason.encode(initial_config, pretty: true)
      File.write!(temp_file, json_content)

      # Start a new manager instance
      {:ok, _pid} = Manager.start_link(persistent_file: temp_file)

      # Verify the persisted value is loaded
      assert "persisted_value" = Manager.get(:persisted_key)
    end

    test "persists configuration deletions", %{temp_file: temp_file} do
      # Set a configuration value
      assert :ok =
               Manager.set(:delete_test_key, "delete_test_value", persist: true)

      # Verify the value is set
      assert "delete_test_value" = Manager.get(:delete_test_key)

      # Delete the configuration value
      assert :ok = Manager.delete(:delete_test_key, persist: true)

      # Verify the value is deleted
      assert nil = Manager.get(:delete_test_key)

      # Check that the value was removed from the persistent file
      {:ok, content} = File.read(temp_file)
      {:ok, config} = Jason.decode(content)
      refute Map.has_key?(config, "delete_test_key")
    end

    test "handles persistence failures gracefully" do
      # Try to persist to a read-only directory (should fail gracefully)
      read_only_file = "/readonly/test_config.json"

      # This should not crash the manager
      assert {:error, _reason} =
               Manager.set(:test_key, "test_value", persist: true)
    end

    test "skips persistence when persist: false", %{temp_file: temp_file} do
      # Set a configuration value without persistence
      assert :ok =
               Manager.set(:no_persist_key, "no_persist_value", persist: false)

      # Verify the value is set in memory
      assert "no_persist_value" = Manager.get(:no_persist_key)

      # Check that the value was NOT persisted to file
      if File.exists?(temp_file) do
        {:ok, content} = File.read(temp_file)
        {:ok, config} = Jason.decode(content)
        refute Map.has_key?(config, "no_persist_key")
      end
    end
  end

  describe "error handling" do
    test "handles invalid configuration file" do
      {:ok, _} =
        Manager.start_link(
          config_file: "test/fixtures/invalid_syntax.exs",
          validate: false
        )

      assert {:error, _} = Manager.reload()
    end

    test "handles invalid configuration values" do
      assert {:error, _} = Manager.set(:terminal_width, "invalid")
      assert {:error, _} = Manager.set(:buffer_max_size, "invalid")
      assert {:error, _} = Manager.set(:renderer_mode, "invalid")
    end

    test "handles invalid update function" do
      assert {:error, _} =
               Manager.update(:terminal_width, fn _ -> "invalid" end)
    end
  end
end
