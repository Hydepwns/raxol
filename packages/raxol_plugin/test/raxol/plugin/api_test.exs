defmodule Raxol.Plugin.APITest do
  use ExUnit.Case, async: true

  alias Raxol.Plugin.API

  describe "error handling when PluginManager is not running" do
    test "load/2 returns error tuple" do
      assert {:error, :plugin_manager_not_running} = API.load(SomeModule, %{})
    end

    test "unload/1 returns error tuple" do
      assert {:error, :plugin_manager_not_running} = API.unload(:some_plugin)
    end

    test "enable/1 returns error tuple" do
      assert {:error, :plugin_manager_not_running} = API.enable(:some_plugin)
    end

    test "disable/1 returns error tuple" do
      assert {:error, :plugin_manager_not_running} = API.disable(:some_plugin)
    end

    test "list/0 returns empty list or error when no manager" do
      result = API.list()
      assert result == [] or match?({:error, _}, result)
    end

    test "get_state/1 returns error tuple" do
      assert {:error, :plugin_manager_not_running} = API.get_state(:some_plugin)
    end

    test "reload/1 returns error tuple" do
      assert {:error, :plugin_manager_not_running} = API.reload(:some_plugin)
    end

    test "loaded?/1 returns false or error when no manager" do
      result = API.loaded?(:some_plugin)
      assert result == false or match?({:error, _}, result)
    end

    test "get/1 returns nil or error when no manager" do
      result = API.get(:some_plugin)
      assert result == nil or match?({:error, _}, result)
    end
  end
end
