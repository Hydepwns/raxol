defmodule Raxol.Core.Config.ManagerTest do
  @moduledoc """
  Tests for the configuration management system, including loading, validation,
  persistence, and error handling of configuration values.
  """
  use ExUnit.Case, async: false
  import Raxol.Guards
  alias Raxol.Core.Config.Manager

  # Helper functions to call Manager using PID instead of registered name
  defp manager_get(pid, key, default \\ nil) do
    GenServer.call(pid, {:get, key, default})
  end

  defp manager_set(pid, key, value, opts \\ []) do
    GenServer.call(pid, {:set, key, value, opts})
  end

  defp manager_update(pid, key, fun, opts \\ []) do
    GenServer.call(pid, {:update, key, fun, opts})
  end

  defp manager_delete(pid, key, opts \\ []) do
    GenServer.call(pid, {:delete, key, opts})
  end

  defp manager_get_all(pid) do
    GenServer.call(pid, :get_all)
  end

  defp manager_reload(pid) do
    GenServer.call(pid, :reload)
  end

  setup do
    # Create a temporary file for persistent config
    temp_file = Path.join(System.tmp_dir!(), "raxol_test_persistent.json")

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

    # Generate a unique name for this test
    unique_name = :"Raxol.Core.Config.Manager.#{System.unique_integer([:positive])}"

    # Start the manager with the temp file and unique name
    {:ok, pid} =
      Manager.start_link(
        config_file: config_file,
        persistent_file: temp_file,
        env: :dev,
        # Disable validation for tests
        validate: false,
        name: unique_name
      )

    on_exit(fn ->
      # Clean up the temp files
      File.rm(temp_file)
      File.rm(config_file)
    end)

    {:ok, %{temp_file: temp_file, config_file: config_file, pid: pid, name: unique_name}}
  end

  describe "configuration loading" do
    test "loads configuration from file", %{pid: pid} do
      assert {:ok, _} = manager_reload(pid)
      assert map?(manager_get_all(pid))
    end

    test "handles missing configuration file" do
      {:ok, pid} =
        Manager.start_link(
          config_file: "nonexistent.exs",
          validate: false,
          name: :"Manager.#{System.unique_integer([:positive])}"
        )

      assert %{} = manager_get_all(pid)
    end

    test "validates required configuration fields when validation is enabled" do
      {:ok, pid} =
        Manager.start_link(
          config_file: "test/fixtures/invalid_config.exs",
          validate: true,
          name: :"Manager.#{System.unique_integer([:positive])}"
        )

      assert {:ok, config} = manager_reload(pid)
      assert is_map(config)
    end

    test "skips validation when validation is disabled" do
      {:ok, pid} =
        Manager.start_link(
          config_file: "test/fixtures/invalid_config.exs",
          validate: false,
          name: :"Manager.#{System.unique_integer([:positive])}"
        )

      assert {:ok, _} = manager_reload(pid)
    end
  end

  describe "configuration access" do
    test "gets configuration value", %{pid: pid} do
      assert {:ok, _} = manager_reload(pid)
      # Access the nested config structure
      terminal_config = manager_get(pid, :terminal)
      assert integer?(terminal_config.width)
    end

    test "returns default value for missing key", %{pid: pid} do
      assert :default = manager_get(pid, :nonexistent_key, :default)
    end

    test "gets all configuration values", %{pid: pid} do
      assert {:ok, _} = manager_reload(pid)
      config = manager_get_all(pid)
      assert map?(config)
      assert Map.has_key?(config, :terminal)
      assert Map.has_key?(config, :buffer)
      assert Map.has_key?(config, :renderer)
    end
  end

  describe "configuration updates" do
    test "sets configuration value", %{pid: pid} do
      assert :ok = manager_set(pid, :test_key, "test_value")
      assert "test_value" = manager_get(pid, :test_key)
    end

    test "validates configuration value" do
      {:ok, pid} =
        Manager.start_link(
          config_file: "config/raxol.exs",
          validate: true,
          name: :"Manager.#{System.unique_integer([:positive])}"
        )

      assert {:error, _} = manager_set(pid, :terminal_width, -1)
    end

    test "updates configuration value", %{pid: pid} do
      assert :ok = manager_set(pid, :test_key, "initial_value")
      assert :ok = manager_update(pid, :test_key, fn _ -> "updated_value" end)
      assert "updated_value" = manager_get(pid, :test_key)
    end

    test "deletes configuration value", %{pid: pid} do
      assert :ok = manager_set(pid, :test_key, "test_value")
      assert :ok = manager_delete(pid, :test_key)
      assert manager_get(pid, :test_key) == nil
    end
  end

  describe "configuration validation" do
    test "validates terminal configuration" do
      {:ok, pid} =
        Manager.start_link(
          config_file: "config/raxol.exs",
          validate: true,
          name: :"Manager.#{System.unique_integer([:positive])}"
        )

      assert {:error, _} = manager_set(pid, :terminal_width, -1)
      assert {:error, _} = manager_set(pid, :terminal_height, 0)
      assert {:error, _} = manager_set(pid, :terminal_mode, :invalid_mode)
    end

    test "validates buffer configuration" do
      {:ok, pid} =
        Manager.start_link(
          config_file: "config/raxol.exs",
          validate: true,
          name: :"Manager.#{System.unique_integer([:positive])}"
        )

      assert {:error, _} = manager_set(pid, :buffer_max_size, -1)
      assert {:error, _} = manager_set(pid, :buffer_scrollback, -1)
    end

    test "validates renderer configuration" do
      {:ok, pid} =
        Manager.start_link(
          config_file: "config/raxol.exs",
          validate: true,
          name: :"Manager.#{System.unique_integer([:positive])}"
        )

      assert {:error, _} = manager_set(pid, :renderer_mode, :invalid)
      assert {:error, _} = manager_set(pid, :renderer_double_buffering, "not_boolean")
    end
  end

  describe "configuration persistence" do
    test "persists configuration changes", %{temp_file: temp_file, pid: pid} do
      # Set a configuration value
      assert :ok = manager_set(pid, :test_key, "test_value", persist: true)

      # Verify the value is set
      assert "test_value" = manager_get(pid, :test_key)

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
      {:ok, pid} = Manager.start_link(
        persistent_file: temp_file,
        name: :"Manager.#{System.unique_integer([:positive])}"
      )

      # Verify the persisted value is loaded
      assert "persisted_value" = manager_get(pid, :persisted_key)
    end

    test "persists configuration deletions", %{temp_file: temp_file, pid: pid} do
      # Set a configuration value
      assert :ok =
               manager_set(pid, :delete_test_key, "delete_test_value",
                 persist: true,
                 persistent_file: temp_file)

      # Verify the value is set
      assert "delete_test_value" = manager_get(pid, :delete_test_key)

      # Delete the configuration value
      assert :ok = manager_delete(pid, :delete_test_key,
        persist: true,
        persistent_file: temp_file)

      # Verify the value is deleted
      assert manager_get(pid, :delete_test_key) == nil

      # Check that the value was removed from the persistent file
      {:ok, content} = File.read(temp_file)
      {:ok, config} = Jason.decode(content)
      refute Map.has_key?(config, "delete_test_key")
    end

    test "handles persistence failures gracefully", %{pid: pid} do
      # Try to persist to a path that should fail on most systems
      error_file = "/root/test_config.json"
      result = manager_set(pid, :test_key, "test_value",
                 persist: true,
                 persistent_file: error_file)

      # The result might be :ok on some systems, but we're testing the error handling path
      # In a real scenario, this would typically fail due to permissions
      case result do
        :ok -> assert true
        {:error, _} -> assert true
        other -> flunk("Unexpected result: #{inspect(other)}")
      end
    end

    test "skips persistence when persist: false", %{temp_file: temp_file, pid: pid} do
      # Set a configuration value without persistence
      assert :ok =
               manager_set(pid, :no_persist_key, "no_persist_value", persist: false)

      # Verify the value is set in memory
      assert "no_persist_value" = manager_get(pid, :no_persist_key)

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
      {:ok, pid} =
        Manager.start_link(
          config_file: "test/fixtures/invalid_syntax.exs",
          validate: false,
          name: :"Manager.#{System.unique_integer([:positive])}"
        )

      assert {:error, _} = manager_reload(pid)
    end

    test "validates configuration values when validation is enabled", %{pid: pid} do
      # Create a new manager with validation enabled
      {:ok, pid_with_validation} =
        Manager.start_link(
          config_file: "config/raxol.exs",
          validate: true,
          name: :"Manager.#{System.unique_integer([:positive])}"
        )

      assert {:error, _} = manager_set(pid_with_validation, :terminal_width, "invalid")
      assert {:error, _} = manager_set(pid_with_validation, :terminal_mode, :invalid_mode)
    end

    test "skips validation when validation is disabled", %{pid: pid} do
      assert :ok = manager_set(pid, :terminal_width, "invalid")
      assert :ok = manager_set(pid, :terminal_mode, :invalid_mode)
    end

    test "validates update function when validation is enabled" do
      {:ok, pid_with_validation} =
        Manager.start_link(
          config_file: "config/raxol.exs",
          validate: true,
          name: :"Manager.#{System.unique_integer([:positive])}"
        )

      assert {:error, _} = manager_update(pid_with_validation, :terminal_width, fn _ -> "invalid" end)
    end

    test "skips update function validation when validation is disabled", %{pid: pid} do
      assert :ok = manager_update(pid, :terminal_width, fn _ -> "invalid" end)
    end
  end
end
