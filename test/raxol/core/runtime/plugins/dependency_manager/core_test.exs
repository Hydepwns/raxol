defmodule Raxol.Core.Runtime.Plugins.DependencyManager.CoreTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.DependencyManager.Core

  describe "check_dependencies/4" do
    test "returns :ok when all dependencies are satisfied" do
      plugin_id = "my_plugin"
      plugin_metadata = %{dependencies: [{"other_plugin", ">= 1.0.0"}]}
      loaded_plugins = %{"other_plugin" => %{version: "1.1.0"}}

      assert :ok = Core.check_dependencies(plugin_id, plugin_metadata, loaded_plugins)
    end

    test "handles missing dependencies" do
      plugin_id = "my_plugin"
      plugin_metadata = %{dependencies: [{"missing_plugin", ">= 1.0.0"}]}
      loaded_plugins = %{}

      assert {:error, :missing_dependencies, ["missing_plugin"], ["my_plugin"]} =
               Core.check_dependencies(plugin_id, plugin_metadata, loaded_plugins)
    end

    test "handles version mismatches" do
      plugin_id = "my_plugin"
      plugin_metadata = %{dependencies: [{"other_plugin", ">= 2.0.0"}]}
      loaded_plugins = %{"other_plugin" => %{version: "1.0.0"}}

      assert {:error, :version_mismatch, [{"other_plugin", "1.0.0", ">= 2.0.0"}], ["my_plugin"]} =
               Core.check_dependencies(plugin_id, plugin_metadata, loaded_plugins)
    end

    test "handles optional dependencies" do
      plugin_id = "my_plugin"
      plugin_metadata = %{dependencies: [{"optional_plugin", ">= 1.0.0", %{optional: true}}]}
      loaded_plugins = %{}

      assert :ok = Core.check_dependencies(plugin_id, plugin_metadata, loaded_plugins)
    end

    test "handles simple plugin IDs without version requirements" do
      plugin_id = "my_plugin"
      plugin_metadata = %{dependencies: ["other_plugin"]}
      loaded_plugins = %{"other_plugin" => %{version: "1.0.0"}}

      assert :ok = Core.check_dependencies(plugin_id, plugin_metadata, loaded_plugins)
    end

    test "handles multiple dependencies" do
      plugin_id = "my_plugin"
      plugin_metadata = %{
        dependencies: [
          {"plugin_a", ">= 1.0.0"},
          {"plugin_b", ">= 2.0.0"},
          {"plugin_c", ">= 3.0.0", %{optional: true}}
        ]
      }
      loaded_plugins = %{
        "plugin_a" => %{version: "1.1.0"},
        "plugin_b" => %{version: "1.0.0"}
      }

      assert {:error, :version_mismatch, [{"plugin_b", "1.0.0", ">= 2.0.0"}], ["my_plugin"]} =
               Core.check_dependencies(plugin_id, plugin_metadata, loaded_plugins)
    end

    test "handles empty dependencies" do
      plugin_id = "my_plugin"
      plugin_metadata = %{dependencies: []}
      loaded_plugins = %{}

      assert :ok = Core.check_dependencies(plugin_id, plugin_metadata, loaded_plugins)
    end

    test "handles missing dependencies key in metadata" do
      plugin_id = "my_plugin"
      plugin_metadata = %{}
      loaded_plugins = %{}

      assert :ok = Core.check_dependencies(plugin_id, plugin_metadata, loaded_plugins)
    end
  end

  describe "resolve_load_order/1" do
    test "resolves simple dependency chain" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: []}
      }

      assert {:ok, ["plugin_b", "plugin_a"]} = Core.resolve_load_order(plugins)
    end

    test "handles circular dependencies" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: [{"plugin_a", ">= 1.0.0"}]}
      }

      assert {:error, :circular_dependency, cycle, chain} = Core.resolve_load_order(plugins)
      assert length(cycle) > 0
      assert length(chain) > 0
    end

    test "handles complex dependency chains" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}, {"plugin_c", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: [{"plugin_d", ">= 1.0.0"}]},
        "plugin_c" => %{dependencies: [{"plugin_d", ">= 1.0.0"}]},
        "plugin_d" => %{dependencies: []}
      }

      assert {:ok, order} = Core.resolve_load_order(plugins)
      assert "plugin_d" in order
      assert Enum.find_index(order, &(&1 == "plugin_d")) <
               Enum.find_index(order, &(&1 == "plugin_b"))
      assert Enum.find_index(order, &(&1 == "plugin_d")) <
               Enum.find_index(order, &(&1 == "plugin_c"))
      assert Enum.find_index(order, &(&1 == "plugin_b")) <
               Enum.find_index(order, &(&1 == "plugin_a"))
      assert Enum.find_index(order, &(&1 == "plugin_c")) <
               Enum.find_index(order, &(&1 == "plugin_a"))
    end

    test "handles empty plugin map" do
      assert {:ok, []} = Core.resolve_load_order(%{})
    end

    test "handles plugins with no dependencies" do
      plugins = %{
        "plugin_a" => %{dependencies: []},
        "plugin_b" => %{dependencies: []}
      }

      assert {:ok, order} = Core.resolve_load_order(plugins)
      assert length(order) == 2
      assert "plugin_a" in order
      assert "plugin_b" in order
    end
  end
end
