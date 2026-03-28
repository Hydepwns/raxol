defmodule Raxol.Core.Runtime.Plugins.DependencyResolverTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.{DependencyResolver, Manifest}

  defp manifest(id, opts \\ []) do
    %Manifest{
      id: id,
      name: to_string(id),
      version: "1.0.0",
      module: Module.concat([Test, Macro.camelize(to_string(id))]),
      depends_on: Keyword.get(opts, :depends_on, []),
      conflicts_with: Keyword.get(opts, :conflicts_with, []),
      provides: Keyword.get(opts, :provides, []),
      requires: Keyword.get(opts, :requires, [])
    }
  end

  describe "resolve/1" do
    test "resolves independent plugins in stable order" do
      manifests = [manifest(:a), manifest(:b), manifest(:c)]
      assert {:ok, order} = DependencyResolver.resolve(manifests)
      assert length(order) == 3
      assert MapSet.new(order) == MapSet.new([:a, :b, :c])
    end

    test "resolves linear dependency chain" do
      manifests = [
        manifest(:c, depends_on: [{:b, ">= 1.0.0"}]),
        manifest(:b, depends_on: [{:a, ">= 1.0.0"}]),
        manifest(:a)
      ]

      assert {:ok, [:a, :b, :c]} = DependencyResolver.resolve(manifests)
    end

    test "resolves diamond dependency" do
      manifests = [
        manifest(:d, depends_on: [{:b, ">= 0"}, {:c, ">= 0"}]),
        manifest(:b, depends_on: [{:a, ">= 0"}]),
        manifest(:c, depends_on: [{:a, ">= 0"}]),
        manifest(:a)
      ]

      assert {:ok, order} = DependencyResolver.resolve(manifests)
      assert hd(order) == :a
      assert List.last(order) == :d

      assert Enum.find_index(order, &(&1 == :a)) <
               Enum.find_index(order, &(&1 == :b))

      assert Enum.find_index(order, &(&1 == :a)) <
               Enum.find_index(order, &(&1 == :c))
    end

    test "detects cycle" do
      manifests = [
        manifest(:a, depends_on: [{:b, ">= 0"}]),
        manifest(:b, depends_on: [{:a, ">= 0"}])
      ]

      assert {:error, {:cycle, cycle_ids}} =
               DependencyResolver.resolve(manifests)

      assert :a in cycle_ids
      assert :b in cycle_ids
    end

    test "detects missing dependency" do
      manifests = [
        manifest(:a, depends_on: [{:missing, ">= 0"}])
      ]

      assert {:error, {:missing, :a, :missing}} =
               DependencyResolver.resolve(manifests)
    end

    test "detects conflicts" do
      manifests = [
        manifest(:a, conflicts_with: [:b]),
        manifest(:b)
      ]

      assert {:error, {:conflict, :a, :b}} =
               DependencyResolver.resolve(manifests)
    end

    test "detects unmet capabilities" do
      manifests = [
        manifest(:a, requires: [:navigation])
      ]

      assert {:error, {:unmet_capability, :a, :navigation}} =
               DependencyResolver.resolve(manifests)
    end

    test "capabilities satisfied by another plugin" do
      manifests = [
        manifest(:a, requires: [:navigation]),
        manifest(:b, provides: [:navigation])
      ]

      assert {:ok, _order} = DependencyResolver.resolve(manifests)
    end
  end

  describe "resolve_incremental/2" do
    test "treats already_loaded as satisfied" do
      manifests = [
        manifest(:b, depends_on: [{:a, ">= 0"}])
      ]

      assert {:ok, [:b]} =
               DependencyResolver.resolve_incremental(manifests, [:a])
    end

    test "detects missing when not in already_loaded" do
      manifests = [
        manifest(:b, depends_on: [{:a, ">= 0"}])
      ]

      assert {:error, {:missing, :b, :a}} =
               DependencyResolver.resolve_incremental(manifests, [])
    end
  end

  describe "check_conflicts/1" do
    test "no conflicts returns :ok" do
      assert :ok =
               DependencyResolver.check_conflicts([manifest(:a), manifest(:b)])
    end

    test "conflict returns error" do
      assert {:error, {:conflict, :a, :b}} =
               DependencyResolver.check_conflicts([
                 manifest(:a, conflicts_with: [:b]),
                 manifest(:b)
               ])
    end
  end

  describe "satisfy_capabilities/1" do
    test "no requirements returns :ok" do
      assert :ok = DependencyResolver.satisfy_capabilities([manifest(:a)])
    end

    test "unmet requirement returns error" do
      assert {:error, {:unmet_capability, :a, :nav}} =
               DependencyResolver.satisfy_capabilities([
                 manifest(:a, requires: [:nav])
               ])
    end

    test "met requirement returns :ok" do
      assert :ok =
               DependencyResolver.satisfy_capabilities([
                 manifest(:a, requires: [:nav]),
                 manifest(:b, provides: [:nav])
               ])
    end
  end
end
