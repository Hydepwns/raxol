defmodule Raxol.Core.Config.ManagerTest do
  use ExUnit.Case, async: false
  alias Raxol.Core.Config.Manager

  setup do
    {:ok, _pid} = Manager.start_link(
      config_file: "test/fixtures/config.exs",
      validate: true
    )
    on_exit(fn -> :ok = Manager.delete(:all) end)
    :ok
  end

  describe "configuration loading" do
    test "loads configuration from file" do
      assert {:ok, _} = Manager.reload()
      assert is_map(Manager.get_all())
    end

    test "handles missing configuration file" do
      {:ok, _} = Manager.start_link(
        config_file: "nonexistent.exs",
        validate: false
      )
      assert %{} = Manager.get_all()
    end

    test "validates required configuration fields" do
      {:ok, _} = Manager.start_link(
        config_file: "test/fixtures/invalid_config.exs",
        validate: true
      )
      assert {:error, _} = Manager.reload()
    end
  end

  describe "configuration access" do
    test "gets configuration value" do
      assert {:ok, _} = Manager.reload()
      assert is_integer(Manager.get(:terminal_width))
    end

    test "returns default value for missing key" do
      assert :default = Manager.get(:nonexistent_key, :default)
    end

    test "gets all configuration values" do
      assert {:ok, _} = Manager.reload()
      config = Manager.get_all()
      assert is_map(config)
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
      assert nil = Manager.get(:custom_key)
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
    test "persists configuration changes" do
      assert :ok = Manager.set(:custom_key, "value", persist: true)
      assert "value" = Manager.get(:custom_key)
      # TODO: Add persistence verification
    end

    test "skips persistence when requested" do
      assert :ok = Manager.set(:custom_key, "value", persist: false)
      assert "value" = Manager.get(:custom_key)
      # TODO: Add persistence verification
    end
  end

  describe "error handling" do
    test "handles invalid configuration file" do
      {:ok, _} = Manager.start_link(
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
      assert {:error, _} = Manager.update(:terminal_width, fn _ -> "invalid" end)
    end
  end
end
