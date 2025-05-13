defmodule Raxol.Core.Runtime.Plugins.DependencyManagerResolutionTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager

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
        "plugin_a" => %{
          dependencies: [{"plugin_b", ">= 1.0.0"}, {"plugin_c", ">= 1.0.0"}]
        },
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

      assert {:error, :circular_dependency, cycle, chain} =
               DependencyManager.resolve_load_order(plugins)

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

      assert {:error, :circular_dependency, cycle, chain} =
               DependencyManager.resolve_load_order(plugins)

      assert length(cycle) > 0
      assert length(chain) > 0
      assert "plugin_a" in cycle
      assert "plugin_b" in cycle
      assert "plugin_c" in cycle
    end

    test "handles deeply nested circular dependencies" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: [{"plugin_c", ">= 1.0.0"}]},
        "plugin_c" => %{dependencies: [{"plugin_d", ">= 1.0.0"}]},
        "plugin_d" => %{dependencies: [{"plugin_e", ">= 1.0.0"}]},
        "plugin_e" => %{dependencies: [{"plugin_a", ">= 1.0.0"}]}
      }

      assert {:error, :circular_dependency, cycle, chain} =
               DependencyManager.resolve_load_order(plugins)

      assert length(cycle) == 5
      assert length(chain) > 5
    end

    test "handles very long dependency chains" do
      # Create a chain of 100 plugins
      plugins =
        Enum.reduce(1..100, %{}, fn i, acc ->
          next_plugin = if i < 100, do: "plugin_#{i + 1}", else: "plugin_1"

          Map.put(acc, "plugin_#{i}", %{
            dependencies: [{next_plugin, ">= 1.0.0"}]
          })
        end)

      assert {:error, :circular_dependency, cycle, chain} =
               DependencyManager.resolve_load_order(plugins)

      assert length(cycle) > 0
      assert length(chain) > 0
    end
  end

  describe "optional dependencies" do
    test "handles optional dependencies" do
      plugin_metadata = %{
        dependencies: [
          {"required_plugin", ">= 1.0.0"},
          {"optional_plugin", ">= 2.0.0", %{optional: true}}
        ]
      }

      loaded_plugins = %{"required_plugin" => %{version: "1.1.0"}}

      assert :ok ==
               DependencyManager.check_dependencies(
                 "my_plugin",
                 plugin_metadata,
                 loaded_plugins
               )
    end

    test "logs missing optional dependencies" do
      plugin_metadata = %{
        dependencies: [
          {"optional_plugin", ">= 2.0.0", %{optional: true}}
        ]
      }

      loaded_plugins = %{}

      assert :ok ==
               DependencyManager.check_dependencies(
                 "my_plugin",
                 plugin_metadata,
                 loaded_plugins
               )
    end

    test "handles version mismatches for optional dependencies" do
      plugin_metadata = %{
        dependencies: [
          {"optional_plugin", ">= 2.0.0", %{optional: true}}
        ]
      }

      loaded_plugins = %{"optional_plugin" => %{version: "1.0.0"}}

      assert :ok ==
               DependencyManager.check_dependencies(
                 "my_plugin",
                 plugin_metadata,
                 loaded_plugins
               )
    end
  end
end
