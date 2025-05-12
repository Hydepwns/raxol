defmodule Raxol.Core.Runtime.Plugins.DependencyResolutionTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager
  alias Raxol.Core.Runtime.Plugins.DependencyManagerTestHelper

  describe "dependency resolution" do
    test "resolves simple dependency chain" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: []}
      }

      assert {:ok, load_order} = DependencyManager.resolve_load_order(plugins)
      assert load_order == ["plugin_b", "plugin_a"]
    end

    test "resolves complex dependency graph" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}, {"plugin_c", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: [{"plugin_c", ">= 1.0.0"}]},
        "plugin_c" => %{dependencies: []},
        "plugin_d" => %{dependencies: [{"plugin_a", ">= 1.0.0"}]}
      }

      assert {:ok, load_order} = DependencyManager.resolve_load_order(plugins)
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

      actual = DependencyManager.resolve_load_order(plugins)
      IO.inspect(actual, label: "Actual return value for circular dependency test")
      assert {:error, :circular_dependency, cycle, chain} = actual
      assert length(cycle) > 0
      assert length(chain) > 0
      assert "plugin_a" in cycle
      assert "plugin_b" in cycle
    end

    test "handles complex circular dependencies" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: [{"plugin_c", ">= 1.0.0"}]},
        "plugin_c" => %{dependencies: [{"plugin_a", ">= 1.0.0"}]}
      }

      assert {:error, :circular_dependency, cycle, chain} = DependencyManager.resolve_load_order(plugins)
      assert length(cycle) > 0
      assert length(chain) > 0
      assert "plugin_a" in cycle
      assert "plugin_b" in cycle
      assert "plugin_c" in cycle
    end

    test "handles deeply nested circular dependencies" do
      plugins = DependencyManagerTestHelper.create_dependency_chain(5)

      assert {:error, :circular_dependency, cycle, chain} = DependencyManager.resolve_load_order(plugins)
      assert length(cycle) == 5
      assert length(chain) > 5
    end

    test "handles self-dependencies" do
      plugin_metadata = %{dependencies: [{"my_plugin", ">= 1.0.0"}]}
      loaded_plugins = %{"my_plugin" => %{version: "1.0.0"}}

      assert {:error, :self_dependency, ["my_plugin"], ["my_plugin"]} ==
               DependencyManager.check_dependencies("my_plugin", plugin_metadata, loaded_plugins)
    end

    test "handles duplicate dependencies" do
      plugin_metadata = %{
        dependencies: [
          {"plugin_a", ">= 1.0.0"},
          {"plugin_a", ">= 2.0.0"},  # Duplicate with different version
          {"plugin_a", ">= 1.0.0"}   # Exact duplicate
        ]
      }
      loaded_plugins = %{"plugin_a" => %{version: "2.1.0"}}

      assert :ok == DependencyManager.check_dependencies("my_plugin", plugin_metadata, loaded_plugins)
    end

    test "handles conflicting version requirements" do
      plugin_metadata = %{
        dependencies: [
          {"plugin_a", ">= 1.0.0"},
          {"plugin_a", "<= 0.9.0"}  # Conflicting version requirement
        ]
      }
      loaded_plugins = %{"plugin_a" => %{version: "1.0.0"}}

      assert {:error, :conflicting_requirements, conflicts, ["my_plugin"]} =
               DependencyManager.check_dependencies("my_plugin", plugin_metadata, loaded_plugins)
      assert length(conflicts) == 1
    end
  end
end
