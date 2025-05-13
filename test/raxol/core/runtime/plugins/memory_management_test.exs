defmodule Raxol.Core.Runtime.Plugins.MemoryManagementTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Runtime.Plugins.DependencyManager
  alias Raxol.Core.Runtime.Plugins.DependencyManagerTestHelper

  describe "memory management" do
    test "handles memory cleanup after dependency resolution" do
      plugins = DependencyManagerTestHelper.create_plugin_set(100)

      {result, memory_diff} =
        DependencyManagerTestHelper.measure_memory_usage(fn ->
          DependencyManager.resolve_load_order(plugins)
        end)

      DependencyManagerTestHelper.assert_memory_stable(memory_diff)
      assert match?({:ok, _}, result)
    end

    test "handles memory cleanup after circular dependency detection" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: [{"plugin_c", ">= 1.0.0"}]},
        "plugin_c" => %{dependencies: [{"plugin_a", ">= 1.0.0"}]}
      }

      {result, memory_diff} =
        DependencyManagerTestHelper.measure_memory_usage(fn ->
          DependencyManager.resolve_load_order(plugins)
        end)

      DependencyManagerTestHelper.assert_memory_stable(memory_diff)
      assert match?({:error, :circular_dependency, _, _}, result)
    end

    test "handles memory cleanup during repeated operations" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: []}
      }

      {_, memory_diff} =
        DependencyManagerTestHelper.measure_memory_usage(fn ->
          Enum.each(1..100, fn _ ->
            {:ok, _} = DependencyManager.resolve_load_order(plugins)

            :ok =
              DependencyManager.check_dependencies(
                "plugin_a",
                plugins["plugin_a"],
                plugins
              )
          end)
        end)

      DependencyManagerTestHelper.assert_memory_stable(memory_diff)
    end

    test "handles memory cleanup with large version requirements" do
      plugins = %{
        "plugin_a" => %{
          dependencies: [
            {"plugin_b", ">= 1.0.0 || >= 2.0.0 || ~> 1.0 || ~> 2.0"},
            {"plugin_c", ">= 1.0.0 || >= 2.0.0 || ~> 1.0 || ~> 2.0"}
          ]
        },
        "plugin_b" => %{version: "2.1.0"},
        "plugin_c" => %{version: "1.2.0"}
      }

      {_, memory_diff} =
        DependencyManagerTestHelper.measure_memory_usage(fn ->
          Enum.each(1..50, fn _ ->
            :ok =
              DependencyManager.check_dependencies(
                "plugin_a",
                plugins["plugin_a"],
                plugins
              )
          end)
        end)

      DependencyManagerTestHelper.assert_memory_stable(memory_diff)
    end

    test "handles memory cleanup with deep dependency chains" do
      plugins = DependencyManagerTestHelper.create_dependency_chain(100)

      {result, memory_diff} =
        DependencyManagerTestHelper.measure_memory_usage(fn ->
          DependencyManager.resolve_load_order(plugins)
        end)

      DependencyManagerTestHelper.assert_memory_stable(memory_diff)
      assert match?({:error, :circular_dependency, _, _}, result)
    end

    test "handles memory cleanup with concurrent operations" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: [{"plugin_c", ">= 1.0.0"}]},
        "plugin_c" => %{dependencies: []}
      }

      {_, memory_diff} =
        DependencyManagerTestHelper.measure_memory_usage(fn ->
          tasks =
            Enum.map(1..50, fn _ ->
              Task.async(fn ->
                {:ok, _} = DependencyManager.resolve_load_order(plugins)

                :ok =
                  DependencyManager.check_dependencies(
                    "plugin_a",
                    plugins["plugin_a"],
                    plugins
                  )
              end)
            end)

          Enum.map(tasks, &Task.await/1)
        end)

      DependencyManagerTestHelper.assert_memory_stable(memory_diff)
    end

    test "handles memory cleanup with rapid plugin updates" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{version: "1.0.0"}
      }

      {_, memory_diff} =
        DependencyManagerTestHelper.measure_memory_usage(fn ->
          Enum.each(1..100, fn i ->
            updated_plugins =
              Map.update!(plugins, "plugin_b", fn plugin ->
                Map.put(plugin, :version, "#{i}.0.0")
              end)

            :ok =
              DependencyManager.check_dependencies(
                "plugin_a",
                plugins["plugin_a"],
                updated_plugins
              )
          end)
        end)

      DependencyManagerTestHelper.assert_memory_stable(memory_diff)
    end

    test "handles memory cleanup with mixed operations" do
      plugins = %{
        "plugin_a" => %{dependencies: [{"plugin_b", ">= 1.0.0"}]},
        "plugin_b" => %{dependencies: [{"plugin_c", ">= 1.0.0"}]},
        "plugin_c" => %{dependencies: []}
      }

      {_, memory_diff} =
        DependencyManagerTestHelper.measure_memory_usage(fn ->
          Enum.each(1..50, fn i ->
            # Resolution
            {:ok, _} = DependencyManager.resolve_load_order(plugins)

            # Version check
            :ok =
              DependencyManager.check_dependencies(
                "plugin_a",
                plugins["plugin_a"],
                plugins
              )

            # Update and check
            updated_plugins =
              Map.update!(plugins, "plugin_c", fn plugin ->
                Map.put(plugin, :version, "#{i}.0.0")
              end)

            :ok =
              DependencyManager.check_dependencies(
                "plugin_a",
                plugins["plugin_a"],
                updated_plugins
              )
          end)
        end)

      DependencyManagerTestHelper.assert_memory_stable(memory_diff)
    end
  end
end
