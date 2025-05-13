defmodule Raxol.Core.Runtime.Plugins.DependencyManager.GraphTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.DependencyManager.Graph

  describe "build_dependency_graph/1" do
    test "builds graph from plugin metadata" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: []}
      }

      expected = %{
        "plugin_a" => [{"plugin_b", ">= 1.0.0", %{optional: false}}],
        "plugin_b" => []
      }

      assert expected == Graph.build_dependency_graph(plugins)
    end

    test "handles optional dependencies" do
      plugins = %{
        "plugin_a" => %{
          dependencies: [{"plugin_b", ">= 1.0.0", %{optional: true}}]
        },
        "plugin_b" => %{dependencies: []}
      }

      expected = %{
        "plugin_a" => [{"plugin_b", ">= 1.0.0", %{optional: true}}],
        "plugin_b" => []
      }

      assert expected == Graph.build_dependency_graph(plugins)
    end

    test "handles simple plugin IDs" do
      plugins = %{
        "plugin_a" => %{dependencies: ["plugin_b"]},
        "plugin_b" => %{dependencies: []}
      }

      expected = %{
        "plugin_a" => [{"plugin_b", nil, %{optional: false}}],
        "plugin_b" => []
      }

      assert expected == Graph.build_dependency_graph(plugins)
    end

    test "handles empty plugin map" do
      assert %{} == Graph.build_dependency_graph(%{})
    end

    test "handles plugins with no dependencies" do
      plugins = %{
        "plugin_a" => %{dependencies: []},
        "plugin_b" => %{}
      }

      expected = %{
        "plugin_a" => [],
        "plugin_b" => []
      }

      assert expected == Graph.build_dependency_graph(plugins)
    end
  end

  describe "build_dependency_chain/2" do
    test "builds chain for cycle" do
      cycle = ["plugin_a", "plugin_b"]

      graph = %{
        "plugin_a" => [{"plugin_b", ">= 1.0.0", %{optional: false}}],
        "plugin_b" => [{"plugin_a", ">= 1.0.0", %{optional: false}}]
      }

      assert ["plugin_a", "plugin_b", "plugin_a"] ==
               Graph.build_dependency_chain(cycle, graph)
    end

    test "handles single node cycle" do
      cycle = ["plugin_a"]

      graph = %{
        "plugin_a" => [{"plugin_a", ">= 1.0.0", %{optional: false}}]
      }

      assert ["plugin_a", "plugin_a"] ==
               Graph.build_dependency_chain(cycle, graph)
    end
  end

  describe "get_all_dependencies/3" do
    test "gets all dependencies for a plugin" do
      plugin_id = "plugin_a"

      graph = %{
        "plugin_a" => [{"plugin_b", ">= 1.0.0", %{optional: false}}],
        "plugin_b" => [{"plugin_c", ">= 1.0.0", %{optional: false}}],
        "plugin_c" => []
      }

      assert {:ok, deps} = Graph.get_all_dependencies(plugin_id, graph)
      assert length(deps) == 2
      assert "plugin_b" in deps
      assert "plugin_c" in deps
    end

    test "detects circular dependencies" do
      plugin_id = "plugin_a"

      graph = %{
        "plugin_a" => [{"plugin_b", ">= 1.0.0", %{optional: false}}],
        "plugin_b" => [{"plugin_a", ">= 1.0.0", %{optional: false}}]
      }

      assert {:error, :circular_dependency, cycle} =
               Graph.get_all_dependencies(plugin_id, graph)

      assert length(cycle) > 0
    end

    test "handles plugins with no dependencies" do
      plugin_id = "plugin_a"

      graph = %{
        "plugin_a" => []
      }

      assert {:ok, []} = Graph.get_all_dependencies(plugin_id, graph)
    end

    test "handles plugins not in graph" do
      plugin_id = "plugin_a"
      graph = %{}

      assert {:ok, []} = Graph.get_all_dependencies(plugin_id, graph)
    end

    test "handles complex dependency chains" do
      plugin_id = "plugin_a"

      graph = %{
        "plugin_a" => [
          {"plugin_b", ">= 1.0.0", %{optional: false}},
          {"plugin_c", ">= 1.0.0", %{optional: false}}
        ],
        "plugin_b" => [{"plugin_d", ">= 1.0.0", %{optional: false}}],
        "plugin_c" => [{"plugin_d", ">= 1.0.0", %{optional: false}}],
        "plugin_d" => []
      }

      assert {:ok, deps} = Graph.get_all_dependencies(plugin_id, graph)
      assert length(deps) == 3
      assert "plugin_b" in deps
      assert "plugin_c" in deps
      assert "plugin_d" in deps
    end
  end
end
