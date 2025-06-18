defmodule Raxol.Core.Runtime.Plugins.DependencyManager.ResolverTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager.Resolver

  describe "tarjan_sort/1" do
    test ~c"sorts a simple acyclic graph" do
      graph = %{
        "a" => [{"b", ">= 1.0.0", %{optional: false}}],
        "b" => []
      }

      result = Resolver.tarjan_sort(graph)
      assert match?({:ok, _}, result)
      {:ok, order} = result
      assert order == ["b", "a"]
    end

    test ~c"sorts a complex acyclic graph" do
      graph = %{
        "a" => [
          {"b", ">= 1.0.0", %{optional: false}},
          {"c", ">= 1.0.0", %{optional: false}}
        ],
        "b" => [{"d", ">= 1.0.0", %{optional: false}}],
        "c" => [{"d", ">= 1.0.0", %{optional: false}}],
        "d" => []
      }

      result = Resolver.tarjan_sort(graph)
      assert match?({:ok, _}, result)
      {:ok, order} = result
      # d must come before b and c, which must come before a
      d_index = Enum.find_index(order, &(&1 == "d"))
      b_index = Enum.find_index(order, &(&1 == "b"))
      c_index = Enum.find_index(order, &(&1 == "c"))
      a_index = Enum.find_index(order, &(&1 == "a"))
      assert d_index < b_index
      assert d_index < c_index
      assert b_index < a_index
      assert c_index < a_index
    end

    test ~c"detects a simple cycle" do
      graph = %{
        "a" => [{"b", ">= 1.0.0", %{optional: false}}],
        "b" => [{"a", ">= 1.0.0", %{optional: false}}]
      }

      result = Resolver.tarjan_sort(graph)
      assert match?({:error, _}, result)
      {:error, cycle} = result
      assert "a" in cycle
      assert "b" in cycle
    end

    test ~c"detects a complex cycle" do
      graph = %{
        "a" => [{"b", ">= 1.0.0", %{optional: false}}],
        "b" => [{"c", ">= 1.0.0", %{optional: false}}],
        "c" => [{"a", ">= 1.0.0", %{optional: false}}]
      }

      result = Resolver.tarjan_sort(graph)
      assert match?({:error, _}, result)
      {:error, cycle} = result
      assert "a" in cycle
      assert "b" in cycle
      assert "c" in cycle
    end

    test ~c"handles an empty graph" do
      result = Resolver.tarjan_sort(%{})
      assert match?({:ok, _}, result)
      {:ok, order} = result
      assert order == []
    end

    test ~c"handles a graph with isolated nodes" do
      graph = %{
        "a" => [],
        "b" => [],
        "c" => []
      }

      result = Resolver.tarjan_sort(graph)
      assert match?({:ok, _}, result)
      {:ok, order} = result
      assert Enum.sort(order) == ["a", "b", "c"]
    end

    test ~c"handles optional dependencies correctly" do
      graph = %{
        "a" => [
          {"b", ">= 1.0.0", %{optional: true}},
          {"c", ">= 1.0.0", %{optional: false}}
        ],
        "b" => [],
        "c" => []
      }

      result = Resolver.tarjan_sort(graph)
      assert match?({:ok, _}, result)
      {:ok, order} = result
      # c must come before a since it's required
      c_index = Enum.find_index(order, &(&1 == "c"))
      a_index = Enum.find_index(order, &(&1 == "a"))
      assert c_index < a_index
    end

    test ~c"handles diamond-shaped dependency graph" do
      graph = %{
        "a" => [
          {"b", ">= 1.0.0", %{optional: false}},
          {"c", ">= 1.0.0", %{optional: false}}
        ],
        "b" => [{"d", ">= 1.0.0", %{optional: false}}],
        "c" => [{"d", ">= 1.0.0", %{optional: false}}],
        "d" => [{"e", ">= 1.0.0", %{optional: false}}],
        "e" => []
      }

      result = Resolver.tarjan_sort(graph)
      assert match?({:ok, _}, result)
      {:ok, order} = result
      # Verify the topological order is maintained
      e_index = Enum.find_index(order, &(&1 == "e"))
      d_index = Enum.find_index(order, &(&1 == "d"))
      b_index = Enum.find_index(order, &(&1 == "b"))
      c_index = Enum.find_index(order, &(&1 == "c"))
      a_index = Enum.find_index(order, &(&1 == "a"))
      assert e_index < d_index
      assert d_index < b_index
      assert d_index < c_index
      assert b_index < a_index
      assert c_index < a_index
    end

    test ~c"handles self-referential dependencies" do
      graph = %{
        "a" => [{"a", ">= 1.0.0", %{optional: false}}]
      }

      result = Resolver.tarjan_sort(graph)
      assert match?({:error, _}, result)
      {:error, cycle} = result
      assert cycle == ["a"]
    end

    test ~c"handles version constraints in dependency graph" do
      graph = %{
        "a" => [
          {"b", ">= 1.0.0 and < 2.0.0", %{optional: false}},
          {"c", "~> 1.0", %{optional: false}}
        ],
        "b" => [{"d", ">= 0.1.0", %{optional: false}}],
        "c" => [{"d", ">= 0.1.0", %{optional: false}}],
        "d" => []
      }

      result = Resolver.tarjan_sort(graph)
      assert match?({:ok, _}, result)
      {:ok, order} = result
      d_index = Enum.find_index(order, &(&1 == "d"))
      b_index = Enum.find_index(order, &(&1 == "b"))
      c_index = Enum.find_index(order, &(&1 == "c"))
      a_index = Enum.find_index(order, &(&1 == "a"))
      assert d_index < b_index
      assert d_index < c_index
      assert b_index < a_index
      assert c_index < a_index
    end

    test ~c"handles multiple paths to same dependency" do
      graph = %{
        "a" => [{"c", ">= 1.0.0", %{optional: false}}],
        "b" => [{"c", ">= 1.0.0", %{optional: false}}],
        "c" => [{"d", ">= 1.0.0", %{optional: false}}],
        "d" => []
      }

      result = Resolver.tarjan_sort(graph)
      assert match?({:ok, _}, result)
      {:ok, order} = result
      d_index = Enum.find_index(order, &(&1 == "d"))
      c_index = Enum.find_index(order, &(&1 == "c"))
      a_index = Enum.find_index(order, &(&1 == "a"))
      b_index = Enum.find_index(order, &(&1 == "b"))
      assert d_index < c_index
      assert c_index < a_index
      assert c_index < b_index
    end

    test ~c"handles deep dependency chains" do
      graph = %{
        "a" => [{"b", ">= 1.0.0", %{optional: false}}],
        "b" => [{"c", ">= 1.0.0", %{optional: false}}],
        "c" => [{"d", ">= 1.0.0", %{optional: false}}],
        "d" => [{"e", ">= 1.0.0", %{optional: false}}],
        "e" => []
      }

      result = Resolver.tarjan_sort(graph)
      assert match?({:ok, _}, result)
      {:ok, order} = result
      e_index = Enum.find_index(order, &(&1 == "e"))
      d_index = Enum.find_index(order, &(&1 == "d"))
      c_index = Enum.find_index(order, &(&1 == "c"))
      b_index = Enum.find_index(order, &(&1 == "b"))
      a_index = Enum.find_index(order, &(&1 == "a"))
      assert e_index < d_index
      assert d_index < c_index
      assert c_index < b_index
      assert b_index < a_index
    end

    test ~c"handles disconnected components" do
      graph = %{
        "a" => [{"b", ">= 1.0.0", %{optional: false}}],
        "b" => [],
        "c" => [{"d", ">= 1.0.0", %{optional: false}}],
        "d" => []
      }

      result = Resolver.tarjan_sort(graph)
      assert match?({:ok, _}, result)
      {:ok, order} = result
      b_index = Enum.find_index(order, &(&1 == "b"))
      a_index = Enum.find_index(order, &(&1 == "a"))
      d_index = Enum.find_index(order, &(&1 == "d"))
      c_index = Enum.find_index(order, &(&1 == "c"))
      assert b_index < a_index
      assert d_index < c_index
    end
  end
end
