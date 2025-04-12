defmodule Raxol.Plugins.PluginDependencyTest do
  use ExUnit.Case
  alias Raxol.Plugins.PluginDependency

  describe "plugin dependency resolution" do
    test "resolves dependencies in correct order" do
      # Create mock plugins with dependencies
      plugins = [
        %{
          name: "plugin_a",
          version: "1.0.0",
          dependencies: [
            %{"name" => "plugin_b", "version" => ">= 1.0.0"},
            %{"name" => "plugin_c", "version" => ">= 1.0.0"}
          ]
        },
        %{
          name: "plugin_b",
          version: "1.0.0",
          dependencies: [
            %{"name" => "plugin_c", "version" => ">= 1.0.0"}
          ]
        },
        %{
          name: "plugin_c",
          version: "1.0.0",
          dependencies: []
        }
      ]

      # Resolve dependencies
      {:ok, sorted_plugins} = PluginDependency.resolve_dependencies(plugins)

      # Check that plugins are sorted in dependency order
      assert Enum.at(sorted_plugins, 0) == "plugin_c"
      assert Enum.at(sorted_plugins, 1) == "plugin_b"
      assert Enum.at(sorted_plugins, 2) == "plugin_a"
    end

    test "detects circular dependencies" do
      # Create mock plugins with circular dependencies
      plugins = [
        %{
          name: "plugin_a",
          version: "1.0.0",
          dependencies: [
            %{"name" => "plugin_b", "version" => ">= 1.0.0"}
          ]
        },
        %{
          name: "plugin_b",
          version: "1.0.0",
          dependencies: [
            %{"name" => "plugin_a", "version" => ">= 1.0.0"}
          ]
        }
      ]

      # Resolve dependencies
      {:error, error_message} = PluginDependency.resolve_dependencies(plugins)

      # Check that circular dependency is detected
      assert String.contains?(error_message, "Circular dependency detected")
    end

    test "checks version compatibility" do
      # Test various version constraints
      assert :ok ==
               PluginDependency.check_version_compatibility("1.0.0", ">= 1.0.0")

      assert :ok ==
               PluginDependency.check_version_compatibility("1.0.0", ">= 0.9.0")

      assert :ok ==
               PluginDependency.check_version_compatibility("1.0.0", "<= 1.1.0")

      assert :ok ==
               PluginDependency.check_version_compatibility("1.0.0", "= 1.0.0")

      assert {:error, _} =
               PluginDependency.check_version_compatibility("1.0.0", ">= 1.1.0")

      assert {:error, _} =
               PluginDependency.check_version_compatibility("1.0.0", "<= 0.9.0")
    end

    test "checks plugin dependencies" do
      # Create a plugin with dependencies
      plugin = %{
        name: "test_plugin",
        version: "1.0.0",
        dependencies: [
          %{"name" => "dependency_a", "version" => ">= 1.0.0"},
          %{
            "name" => "dependency_b",
            "version" => ">= 1.0.0",
            "optional" => true
          }
        ]
      }

      # Create loaded plugins
      loaded_plugins = [
        %{name: "dependency_a", version: "1.0.0"},
        %{name: "other_plugin", version: "1.0.0"}
      ]

      # Check dependencies
      {:ok, _} = PluginDependency.check_dependencies(plugin, loaded_plugins)

      # Test with missing required dependency
      loaded_plugins = [
        %{name: "other_plugin", version: "1.0.0"}
      ]

      {:error, error_message} =
        PluginDependency.check_dependencies(plugin, loaded_plugins)

      assert String.contains?(
               error_message,
               "Required dependency 'dependency_a' not found"
             )

      # Test with version mismatch
      loaded_plugins = [
        %{name: "dependency_a", version: "0.9.0"},
        %{name: "other_plugin", version: "1.0.0"}
      ]

      {:error, error_message} =
        PluginDependency.check_dependencies(plugin, loaded_plugins)

      assert String.contains?(error_message, "Version mismatch")
    end

    test "checks API compatibility" do
      # Test compatible API versions
      assert :ok == PluginDependency.check_api_compatibility("1.0.0", "1.0.0")
      assert :ok == PluginDependency.check_api_compatibility("1.1.0", "1.0.0")
      assert :ok == PluginDependency.check_api_compatibility("1.0.0", "1.1.0")

      # Test incompatible API versions
      assert {:error, _} =
               PluginDependency.check_api_compatibility("2.0.0", "1.0.0")

      assert {:error, _} =
               PluginDependency.check_api_compatibility("1.0.0", "2.0.0")
    end
  end
end
