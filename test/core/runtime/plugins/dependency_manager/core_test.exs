defmodule Raxol.Core.Runtime.Plugins.DependencyManager.CoreTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager.Core

  describe "check_dependencies/4" do
    test "returns :ok when all dependencies are satisfied" do
      plugin_id = "test_plugin"
      plugin_metadata = %{dependencies: [{"dep_plugin", ">= 1.0.0"}]}
      loaded_plugins = %{"dep_plugin" => %{version: "1.1.0"}}

      assert :ok =
               Core.check_dependencies(
                 plugin_id,
                 plugin_metadata,
                 loaded_plugins
               )
    end

    test "handles missing dependencies" do
      plugin_id = "test_plugin"
      plugin_metadata = %{dependencies: [{"missing_plugin", ">= 1.0.0"}]}
      loaded_plugins = %{}

      assert {:error, :missing_dependencies, ["missing_plugin"],
              ["test_plugin"]} =
               Core.check_dependencies(
                 plugin_id,
                 plugin_metadata,
                 loaded_plugins
               )
    end

    test "handles version mismatches" do
      plugin_id = "test_plugin"
      plugin_metadata = %{dependencies: [{"dep_plugin", ">= 2.0.0"}]}
      loaded_plugins = %{"dep_plugin" => %{version: "1.0.0"}}

      assert {:error, :version_mismatch, [{"dep_plugin", "1.0.0", ">= 2.0.0"}],
              ["test_plugin"]} =
               Core.check_dependencies(
                 plugin_id,
                 plugin_metadata,
                 loaded_plugins
               )
    end

    test "handles optional dependencies" do
      plugin_id = "test_plugin"

      plugin_metadata = %{
        dependencies: [{"opt_plugin", ">= 1.0.0", %{optional: true}}]
      }

      loaded_plugins = %{}

      assert :ok =
               Core.check_dependencies(
                 plugin_id,
                 plugin_metadata,
                 loaded_plugins
               )
    end

    test "handles simple plugin IDs without version constraints" do
      plugin_id = "test_plugin"
      plugin_metadata = %{dependencies: ["dep_plugin"]}
      loaded_plugins = %{"dep_plugin" => %{version: "1.0.0"}}

      assert :ok =
               Core.check_dependencies(
                 plugin_id,
                 plugin_metadata,
                 loaded_plugins
               )
    end

    test "handles multiple dependencies" do
      plugin_id = "test_plugin"

      plugin_metadata = %{
        dependencies: [
          {"dep1", ">= 1.0.0"},
          {"dep2", ">= 2.0.0"},
          {"opt_dep", ">= 1.0.0", %{optional: true}}
        ]
      }

      loaded_plugins = %{
        "dep1" => %{version: "1.1.0"},
        "dep2" => %{version: "2.1.0"}
      }

      assert :ok =
               Core.check_dependencies(
                 plugin_id,
                 plugin_metadata,
                 loaded_plugins
               )
    end
  end

  describe "resolve_load_order/1" do
    test "resolves simple dependency chain" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: []}
      }

      assert {:ok, load_order} = Core.resolve_load_order(plugins)
      assert load_order == ["plugin_b", "plugin_a"]
    end

    test "resolves complex dependency graph" do
      plugins = %{
        "plugin_a" => %{
          dependencies: [{"plugin_b", ">= 1.0.0"}, {"plugin_c", ">= 1.0.0"}]
        },
        "plugin_b" => %{dependencies: [{"plugin_c", ">= 1.0.0"}]},
        "plugin_c" => %{dependencies: []},
        "plugin_d" => %{dependencies: [{"plugin_a", ">= 1.0.0"}]}
      }

      assert {:ok, load_order} = Core.resolve_load_order(plugins)
      assert "plugin_c" in load_order
      assert "plugin_b" in load_order
      assert "plugin_a" in load_order
      assert "plugin_d" in load_order

      # Verify dependencies are loaded before dependents
      c_index = Enum.find_index(load_order, &(&1 == "plugin_c"))
      b_index = Enum.find_index(load_order, &(&1 == "plugin_b"))
      a_index = Enum.find_index(load_order, &(&1 == "plugin_a"))
      d_index = Enum.find_index(load_order, &(&1 == "plugin_d"))

      assert c_index < b_index
      assert b_index < a_index
      assert a_index < d_index
    end

    test "detects circular dependencies" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: [{"plugin_a", ">= 1.0.0"}]}
      }

      assert {:error, :circular_dependency, cycle, chain} =
               Core.resolve_load_order(plugins)

      assert length(cycle) > 0
      assert length(chain) > 0
      assert "plugin_a" in cycle
      assert "plugin_b" in cycle
    end

    test "handles plugins with no dependencies" do
      plugins = %{
        "plugin_a" => %{dependencies: []},
        "plugin_b" => %{dependencies: []}
      }

      assert {:ok, load_order} = Core.resolve_load_order(plugins)
      assert length(load_order) == 2
      assert "plugin_a" in load_order
      assert "plugin_b" in load_order
    end
  end
end
