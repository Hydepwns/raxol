defmodule Raxol.Core.Runtime.Plugins.DependencyManager.GraphTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager.Graph

  describe "build_dependency_graph/1" do
    test "builds graph from plugin metadata" do
      plugins = %{
        "plugin_a" => %{
          dependencies: [{"plugin_b", ">= 1.0.0"}],
          version: "1.0.0"
        },
        "plugin_b" => %{dependencies: [], version: "1.0.0"}
      }

      graph = Graph.build_dependency_graph(plugins)
      assert graph["plugin_a"] == [{"plugin_b", ">= 1.0.0", %{optional: false}}]
      assert graph["plugin_b"] == []
    end

    test "handles optional dependencies" do
      plugins = %{
        "plugin_a" => %{
          dependencies: [{"plugin_b", ">= 1.0.0", %{optional: true}}],
          version: "1.0.0"
        },
        "plugin_b" => %{dependencies: [], version: "1.0.0"}
      }

      graph = Graph.build_dependency_graph(plugins)
      assert graph["plugin_a"] == [{"plugin_b", ">= 1.0.0", %{optional: true}}]
    end

    test "handles simple plugin IDs" do
      plugins = %{
        "plugin_a" => %{dependencies: ["plugin_b"], version: "1.0.0"},
        "plugin_b" => %{dependencies: [], version: "1.0.0"}
      }

      graph = Graph.build_dependency_graph(plugins)
      assert graph["plugin_a"] == [{"plugin_b", nil, %{optional: false}}]
    end

    test "handles empty plugin map" do
      graph = Graph.build_dependency_graph(%{})
      assert graph == %{}
    end

    test "handles plugins with no dependencies" do
      plugins = %{
        "plugin_a" => %{dependencies: [], version: "1.0.0"},
        "plugin_b" => %{dependencies: [], version: "1.0.0"}
      }

      graph = Graph.build_dependency_graph(plugins)
      assert graph["plugin_a"] == []
      assert graph["plugin_b"] == []
    end
  end

  describe "build_dependency_chain/2" do
    test "builds chain for circular dependencies" do
      graph = %{
        "plugin_a" => [{"plugin_b", ">= 1.0.0", %{optional: false}}],
        "plugin_b" => [{"plugin_a", ">= 1.0.0", %{optional: false}}]
      }

      chain = Graph.build_dependency_chain(["plugin_a", "plugin_b"], graph)
      assert chain == ["plugin_a", "plugin_b", "plugin_a"]
    end

    test "handles single-node cycles" do
      graph = %{
        "plugin_a" => [{"plugin_a", ">= 1.0.0", %{optional: false}}]
      }

      chain = Graph.build_dependency_chain(["plugin_a"], graph)
      assert chain == ["plugin_a", "plugin_a"]
    end
  end

  describe "get_all_dependencies/3" do
    test "gets all dependencies for a plugin" do
      graph = %{
        "plugin_a" => [{"plugin_b", ">= 1.0.0", %{optional: false}}],
        "plugin_b" => [{"plugin_c", ">= 1.0.0", %{optional: false}}],
        "plugin_c" => []
      }

      result = Graph.get_all_dependencies("plugin_a", graph)
      assert match?({:ok, _}, result)
      {:ok, deps} = result
      assert "plugin_b" in deps
      assert "plugin_c" in deps
    end

    test "detects circular dependencies" do
      graph = %{
        "plugin_a" => [{"plugin_b", ">= 1.0.0", %{optional: false}}],
        "plugin_b" => [{"plugin_a", ">= 1.0.0", %{optional: false}}]
      }

      result = Graph.get_all_dependencies("plugin_a", graph)
      assert match?({:error, :circular_dependency, _}, result)
      {:error, :circular_dependency, cycle} = result
      assert "plugin_a" in cycle
      assert "plugin_b" in cycle
    end

    test "handles plugins with no dependencies" do
      graph = %{
        "plugin_a" => []
      }

      result = Graph.get_all_dependencies("plugin_a", graph)
      assert match?({:ok, []}, result)
    end

    test "handles plugins not in the graph" do
      graph = %{
        "plugin_a" => []
      }

      result = Graph.get_all_dependencies("nonexistent", graph)
      assert match?({:ok, []}, result)
    end

    test "handles complex dependency chains" do
      graph = %{
        "plugin_a" => [
          {"plugin_b", ">= 1.0.0", %{optional: false}},
          {"plugin_c", ">= 1.0.0", %{optional: false}}
        ],
        "plugin_b" => [{"plugin_d", ">= 1.0.0", %{optional: false}}],
        "plugin_c" => [{"plugin_d", ">= 1.0.0", %{optional: false}}],
        "plugin_d" => []
      }

      result = Graph.get_all_dependencies("plugin_a", graph)
      assert match?({:ok, _}, result)
      {:ok, deps} = result
      assert "plugin_b" in deps
      assert "plugin_c" in deps
      assert "plugin_d" in deps

      assert length(deps) == 3
    end
  end
end
