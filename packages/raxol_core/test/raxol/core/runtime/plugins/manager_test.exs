defmodule Raxol.Core.Runtime.Plugins.PluginManagerTest do
  @moduledoc """
  Tests for the plugin manager facade, including initialization, plugin loading,
  and metadata retrieval.
  """
  use ExUnit.Case, async: false
  import Mox
  import Raxol.Test.TestUtils

  alias Raxol.Core.Runtime.Plugins.PluginManager

  setup :verify_on_exit!

  setup do
    {:ok, context} = setup_test_env()
    setup_common_mocks()

    plugin = create_test_plugin("test_plugin")

    {:ok, Map.put(context, :plugin, plugin)}
  end

  describe "initialize/0" do
    test "initializes the plugin registry" do
      assert :ok = PluginManager.initialize()
    end
  end

  describe "initialize_with_config/1" do
    test "initializes with configuration" do
      assert :ok = PluginManager.initialize_with_config(%{debug: true})
    end
  end

  describe "list_plugins/0" do
    test "returns a list" do
      PluginManager.initialize()
      plugins = PluginManager.list_plugins()
      assert is_list(plugins)
    end
  end

  describe "get_plugin/1" do
    test "returns nil for unknown plugin" do
      PluginManager.initialize()
      # get_plugin returns nil for unknown plugins
      result = PluginManager.get_plugin(:unknown_plugin)
      assert result == nil or match?({:error, _}, result)
    end
  end

  describe "plugin_loaded?/1" do
    test "returns false for unloaded plugin" do
      PluginManager.initialize()
      refute PluginManager.plugin_loaded?(:unknown_plugin)
    end
  end

  describe "get_commands/1" do
    test "returns empty map for state" do
      result = PluginManager.get_commands(%{})
      assert result == %{}
    end
  end

  describe "get_metadata/1" do
    test "returns empty map for state" do
      result = PluginManager.get_metadata(%{})
      assert result == %{}
    end
  end
end
