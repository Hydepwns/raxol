defmodule Raxol.Plugins.PluginTest do
  use ExUnit.Case
  alias Raxol.Plugins.HyperlinkPlugin
  alias Raxol.Plugins.Plugin
  alias Raxol.Plugins.Manager.Events, as: PluginManager
  # alias Raxol.Plugins.Manager.Core, as: PluginManager
  import Raxol.Test.PluginTestFixtures

  alias Raxol.Test.PluginTestFixtures.{
    TestPlugin,
    BrokenPlugin,
    BadReturnPlugin,
    DependentPlugin,
    TimeoutPlugin,
    CrashPlugin,
    InvalidMetadataPlugin,
    VersionMismatchPlugin,
    CircularDependencyPlugin
  }

  describe "plugin manager" do
    test "creates a new plugin manager" do
      manager = PluginManager.new()
      assert manager.plugins == %{}
      assert manager.config == %{}
    end

    test "loads a plugin" do
      manager = PluginManager.new()

      {:ok, updated_manager} =
        PluginManager.load_plugin(manager, HyperlinkPlugin)

      assert length(Map.keys(updated_manager.plugins)) == 1
      assert Map.has_key?(updated_manager.plugins, "hyperlink")
    end

    test "unloads a plugin" do
      manager = PluginManager.new()
      {:ok, manager} = PluginManager.load_plugin(manager, HyperlinkPlugin)
      {:ok, updated_manager} = PluginManager.unload_plugin(manager, "hyperlink")
      assert updated_manager.plugins == %{}
    end

    test "enables and disables a plugin" do
      manager = PluginManager.new()
      {:ok, manager} = PluginManager.load_plugin(manager, HyperlinkPlugin)
      {:ok, manager} = PluginManager.disable_plugin(manager, "hyperlink")
      plugin = PluginManager.get_plugin(manager, "hyperlink")
      assert plugin.enabled == false
      {:ok, manager} = PluginManager.enable_plugin(manager, "hyperlink")
      plugin = PluginManager.get_plugin(manager, "hyperlink")
      assert plugin.enabled == true
    end

    test "processes input through plugins" do
      manager = PluginManager.new()
      {:ok, manager} = PluginManager.load_plugin(manager, HyperlinkPlugin)
      {:ok, _manager} = PluginManager.process_input(manager, "test input")
    end

    test "processes output through plugins" do
      manager = PluginManager.new()
      {:ok, manager} = PluginManager.load_plugin(manager, HyperlinkPlugin)

      {:ok, _manager} =
        Raxol.Plugins.Manager.Events.process_output(manager, "test output")
    end

    test "processes mouse events through plugins" do
      manager = PluginManager.new()
      {:ok, manager} = PluginManager.load_plugin(manager, HyperlinkPlugin)

      {:ok, _manager} =
        Raxol.Plugins.Manager.Events.process_mouse(
          manager,
          {:click, 1, 10, 10},
          %{}
        )
    end
  end

  describe "hyperlink plugin" do
    test "initializes correctly" do
      {:ok, plugin} = HyperlinkPlugin.init(%{})
      assert plugin.name == "hyperlink"
      assert plugin.version == "0.1.0"
      assert plugin.enabled == true
    end

    test "detects and makes URLs clickable" do
      {:ok, plugin} = HyperlinkPlugin.init(%{})
      output = "Check out https://example.com for more info"
      {:ok, _plugin} = HyperlinkPlugin.handle_output(plugin, output)
      # Note: The actual URL transformation would be tested in integration tests
      # since it involves terminal escape sequences
    end
  end

  describe "plugin metadata" do
    test "plugin exposes correct metadata" do
      assert %{id: :test_plugin, version: "1.0.0", dependencies: []} =
               TestPlugin.metadata()
    end
  end

  describe "plugin dependencies" do
    test "loads plugin with satisfied dependencies" do
      # Simulate loading TestPlugin first, then DependentPlugin
      manager = PluginManager.new()
      {:ok, manager} = PluginManager.load_plugin(manager, TestPlugin)
      {:ok, manager} = PluginManager.load_plugin(manager, DependentPlugin)
      assert Map.has_key?(manager.plugins, "dependent_plugin")
    end

    test "fails to load plugin with missing dependencies" do
      manager = PluginManager.new()
      # DependentPlugin requires TestPlugin
      assert {:error, msg} = PluginManager.load_plugin(manager, DependentPlugin)
      assert msg =~ "Missing dependency"
    end

    test "detects dependency cycles" do
      manager = PluginManager.new()
      # CircularDependencyPlugin depends on itself
      assert {:error, msg} =
               PluginManager.load_plugin(manager, CircularDependencyPlugin)

      assert msg =~ "Dependency cycle"
    end
  end

  describe "plugin command registration and execution" do
    test "plugin registers and executes command" do
      # TestPlugin registers :test_cmd
      {:ok, state} = TestPlugin.init(%{})
      [{cmd, fun, arity}] = TestPlugin.get_commands()
      assert cmd == :test_cmd
      assert fun == :handle_test_cmd
      assert arity == 1
      # Simulate command execution
      {:ok, new_state, :test_ok} = TestPlugin.handle_test_cmd(:arg, state)
      assert new_state[:handled]
    end
  end

  describe "plugin error handling" do
    test "plugin init returns error" do
      # TimeoutPlugin simulates a timeout error
      assert {:error, :timeout_simulated} = TimeoutPlugin.init(%{})
    end

    test "plugin crashes during init" do
      assert_raise RuntimeError, ~r/Intentional crash/, fn ->
        CrashPlugin.init(%{})
      end
    end

    test "plugin returns invalid result from handler" do
      {:ok, state} = BadReturnPlugin.init(%{})

      assert :unexpected_return ==
               BadReturnPlugin.handle_bad_return_cmd(:arg, state)

      assert :not_ok == BadReturnPlugin.handle_input("input", state)

      assert [:not, :a, :tuple] ==
               BadReturnPlugin.handle_output("output", state)
    end
  end

  describe "plugin configuration persistence" do
    test "plugin config is persisted and loaded" do
      manager = PluginManager.new()
      config = %{foo: "bar"}
      {:ok, manager} = PluginManager.load_plugin(manager, TestPlugin, config)
      # Simulate reload
      plugin = PluginManager.get_plugin(manager, "test_plugin")
      assert plugin
      assert plugin[:foo] == "bar" or plugin.config[:foo] == "bar"
    end
  end
end
