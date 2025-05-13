defmodule Raxol.Core.Runtime.Plugins.DependencyManagerTestHelper do
  @moduledoc """
  Helper module for dependency manager tests providing common test utilities and fixtures.
  """

  def create_plugin_set(count, opts \\ []) do
    dependencies_per_plugin = Keyword.get(opts, :dependencies_per_plugin, 3)
    version_constraint = Keyword.get(opts, :version_constraint, ">= 1.0.0")

    Enum.reduce(1..count, %{}, fn i, acc ->
      deps =
        Enum.map(1..dependencies_per_plugin, fn j ->
          dep_id = "plugin_#{Enum.random(1..count)}"
          {dep_id, version_constraint}
        end)

      Map.put(acc, "plugin_#{i}", %{dependencies: deps})
    end)
  end

  def create_dependency_chain(length) do
    Enum.reduce(1..length, %{}, fn i, acc ->
      next_plugin = if i < length, do: "plugin_#{i + 1}", else: "plugin_1"
      Map.put(acc, "plugin_#{i}", %{dependencies: [{next_plugin, ">= 1.0.0"}]})
    end)
  end

  def create_complex_version_requirements(count) do
    Enum.reduce(1..count, %{}, fn i, acc ->
      deps =
        Enum.map(1..5, fn j ->
          {"plugin_#{j}", ">= #{i}.0.0 || >= #{i + 1}.0.0 || ~> #{i}.0"}
        end)

      Map.put(acc, "plugin_#{i}", %{dependencies: deps})
    end)
  end

  # Performance helpers are now provided by Raxol.Test.PerformanceHelper
  # def measure_memory_usage(fun) do
  #   :erlang.garbage_collect()
  #   before = :erlang.memory(:total)
  #   result = fun.()
  #   :erlang.garbage_collect()
  #   mem_after = :erlang.memory(:total)
  #   {result, mem_after - before}
  # end

  # def measure_time(fun) do
  #   {time, result} = :timer.tc(fun)
  #   {result, time}
  # end

  # def assert_memory_stable(memory_diff, max_diff \\ 1_000_000) do
  #   assert abs(memory_diff) < max_diff
  # end

  # def assert_performance(time, max_time) do
  #   assert time < max_time
  # end
end
