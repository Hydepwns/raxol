defmodule Raxol.Core.Runtime.Plugins.DependencyManager.BasicIntegrationTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager

  defmodule TestPluginA do
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    @impl true
    def get_metadata do
      %{
        id: :plugin_a,
        name: "plugin_a",
        version: "1.0.0",
        dependencies: [{:plugin_b, ">= 1.0.0"}]
      }
    end

    def api_version, do: "1.0.0"

    def init(config) do
      plugin = %Raxol.Plugins.Plugin{
        name: "plugin_a",
        version: "1.0.0",
        description: "Test plugin A",
        enabled: true,
        config: config,
        dependencies: [{:plugin_b, ">= 1.0.0"}],
        api_version: "1.0.0"
      }

      {:ok, plugin}
    end

    def cleanup(_config), do: :ok
  end

  defmodule TestPluginB do
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    @impl true
    def get_metadata do
      %{
        id: :plugin_b,
        name: "plugin_b",
        version: "1.0.0",
        dependencies: []
      }
    end

    def api_version, do: "1.0.0"

    def init(config) do
      plugin = %Raxol.Plugins.Plugin{
        name: "plugin_b",
        version: "1.0.0",
        description: "Test plugin B",
        enabled: true,
        config: config,
        dependencies: [],
        api_version: "1.0.0"
      }

      {:ok, plugin}
    end

    def cleanup(_config), do: :ok
  end

  defmodule TestPluginC do
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    @impl true
    def get_metadata do
      %{
        id: :plugin_c,
        name: "plugin_c",
        version: "1.0.0",
        dependencies: [{:plugin_a, ">= 1.0.0"}, {:plugin_b, ">= 1.0.0"}]
      }
    end

    def api_version, do: "1.0.0"

    def init(config) do
      plugin = %Raxol.Plugins.Plugin{
        name: "plugin_c",
        version: "1.0.0",
        description: "Test plugin C",
        enabled: true,
        config: config,
        dependencies: [{:plugin_a, ">= 1.0.0"}, {:plugin_b, ">= 1.0.0"}],
        api_version: "1.0.0"
      }

      {:ok, plugin}
    end

    def cleanup(_config), do: :ok
  end

  defmodule TestPluginD do
    @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    @impl true
    def get_metadata do
      %{
        id: :plugin_d,
        name: "plugin_d",
        version: "1.0.0",
        dependencies: [{:plugin_c, ">= 1.0.0"}]
      }
    end

    def api_version, do: "1.0.0"

    def init(config) do
      plugin = %Raxol.Plugins.Plugin{
        name: "plugin_d",
        version: "1.0.0",
        description: "Test plugin D",
        enabled: true,
        config: config,
        dependencies: [{:plugin_c, ">= 1.0.0"}],
        api_version: "1.0.0"
      }

      {:ok, plugin}
    end

    def cleanup(_config), do: :ok
  end

  describe "basic plugin manager integration" do
    test ~c"loads plugins in correct dependency order" do
      plugins = [TestPluginA, TestPluginB, TestPluginC, TestPluginD]
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      {:ok, updated_manager} =
        Raxol.Plugins.Manager.State.load_plugins(manager, plugins)

      load_order = Map.get(updated_manager, :load_order) || []

      assert Enum.at(load_order, 0) == "plugin_b"
      assert Enum.at(load_order, 1) == "plugin_a"
      assert Enum.at(load_order, 2) == "plugin_c"
      assert Enum.at(load_order, 3) == "plugin_d"
    end

    test ~c"handles version constraints correctly" do
      defmodule TestPluginE do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_e,
            name: "plugin_e",
            version: "2.0.0",
            dependencies: [{:plugin_f, ">= 1.0.0 and < 2.0.0"}]
          }
        end

        def api_version, do: "1.0.0"

        def init(config) do
          plugin = %Raxol.Plugins.Plugin{
            name: "plugin_e",
            version: "2.0.0",
            description: "Test plugin E",
            enabled: true,
            config: config,
            dependencies: [{:plugin_f, ">= 1.0.0 and < 2.0.0"}],
            api_version: "1.0.0"
          }

          {:ok, plugin}
        end

        def cleanup(_config), do: :ok
      end

      defmodule TestPluginF do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_f,
            name: "plugin_f",
            version: "1.5.0",
            dependencies: []
          }
        end

        def api_version, do: "1.0.0"

        def init(config) do
          plugin = %Raxol.Plugins.Plugin{
            name: "plugin_f",
            version: "1.5.0",
            description: "Test plugin F",
            enabled: true,
            config: config,
            dependencies: [],
            api_version: "1.0.0"
          }

          {:ok, plugin}
        end

        def cleanup(_config), do: :ok
      end

      plugins = [TestPluginE, TestPluginF]
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      {:ok, updated_manager} =
        Raxol.Plugins.Manager.State.load_plugins(manager, plugins)

      loaded_plugins = updated_manager.loaded_plugins

      assert loaded_plugins["plugin_f"].version == "1.5.0"
      assert loaded_plugins["plugin_e"].version == "2.0.0"
    end

    test ~c"handles circular dependencies" do
      defmodule TestPluginG do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_g,
            name: "plugin_g",
            version: "1.0.0",
            dependencies: [{:plugin_h, ">= 1.0.0"}]
          }
        end

        def api_version, do: "1.0.0"

        def init(config) do
          plugin = %Raxol.Plugins.Plugin{
            name: "plugin_g",
            version: "1.0.0",
            description: "Test plugin G",
            enabled: true,
            config: config,
            dependencies: [{:plugin_h, ">= 1.0.0"}],
            api_version: "1.0.0"
          }

          {:ok, plugin}
        end

        def cleanup(_config), do: :ok
      end

      defmodule TestPluginH do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_h,
            name: "plugin_h",
            version: "1.0.0",
            dependencies: [{:plugin_g, ">= 1.0.0"}]
          }
        end

        def api_version, do: "1.0.0"

        def init(config) do
          plugin = %Raxol.Plugins.Plugin{
            name: "plugin_h",
            version: "1.0.0",
            description: "Test plugin H",
            enabled: true,
            config: config,
            dependencies: [{:plugin_g, ">= 1.0.0"}],
            api_version: "1.0.0"
          }

          {:ok, plugin}
        end

        def cleanup(_config), do: :ok
      end

      plugins = [TestPluginG, TestPluginH]
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      assert {:error, reason} =
               Raxol.Plugins.Manager.State.load_plugins(manager, plugins)

      assert String.contains?(String.downcase(reason), "circular dependency")
    end

    test ~c"handles optional dependencies" do
      defmodule TestPluginI do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_i,
            name: "plugin_i",
            version: "1.0.0",
            dependencies: [
              {:plugin_j, ">= 1.0.0", %{optional: true}},
              {:plugin_k, ">= 1.0.0", %{optional: false}}
            ]
          }
        end

        def api_version, do: "1.0.0"

        def init(config) do
          plugin = %Raxol.Plugins.Plugin{
            name: "plugin_i",
            version: "1.0.0",
            description: "Test plugin I",
            enabled: true,
            config: config,
            dependencies: [
              {:plugin_j, ">= 1.0.0", %{optional: true}},
              {:plugin_k, ">= 1.0.0", %{optional: false}}
            ],
            api_version: "1.0.0"
          }

          {:ok, plugin}
        end

        def cleanup(_config), do: :ok
      end

      defmodule TestPluginK do
        @behaviour Raxol.Core.Runtime.Plugins.PluginMetadataProvider

        @impl true
        def get_metadata do
          %{
            id: :plugin_k,
            name: "plugin_k",
            version: "1.0.0",
            description: "Test plugin K",
            dependencies: [],
            api_version: "1.0.0"
          }
        end

        def api_version, do: "1.0.0"

        def init(config) do
          plugin = %Raxol.Plugins.Plugin{
            name: "plugin_k",
            version: "1.0.0",
            description: "Test plugin K",
            enabled: true,
            config: config,
            dependencies: [],
            api_version: "1.0.0"
          }

          {:ok, plugin}
        end

        def cleanup(_config), do: :ok
      end

      plugins = [TestPluginI, TestPluginK]
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      {:ok, updated_manager} =
        Raxol.Plugins.Manager.State.load_plugins(manager, plugins)

      loaded_plugins = updated_manager.loaded_plugins

      assert loaded_plugins["plugin_k"]
      assert loaded_plugins["plugin_i"]
      refute loaded_plugins["plugin_j"]
    end

    test ~c"handles plugin unloading and reloading" do
      plugins = [TestPluginA, TestPluginB]
      {:ok, manager} = Raxol.Plugins.Manager.Core.new()

      {:ok, manager_after_load} =
        Raxol.Plugins.Manager.State.load_plugins(manager, plugins)

      assert Map.has_key?(manager_after_load.loaded_plugins, "plugin_a")
      assert Map.has_key?(manager_after_load.loaded_plugins, "plugin_b")

      assert {:ok, manager_after_unload} =
               Raxol.Plugins.Manager.Core.unload_plugin(
                 manager_after_load,
                 "plugin_a"
               )

      refute Map.has_key?(manager_after_unload.loaded_plugins, "plugin_a")
      assert Map.has_key?(manager_after_unload.loaded_plugins, "plugin_b")

      {:ok, manager_after_reload} =
        Raxol.Plugins.Manager.State.load_plugins(manager_after_unload, [
          TestPluginA
        ])

      assert Map.has_key?(manager_after_reload.loaded_plugins, "plugin_a")
      assert Map.has_key?(manager_after_reload.loaded_plugins, "plugin_b")
    end
  end
end
