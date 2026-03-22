defmodule Raxol.Core.Runtime.Plugins.DependencyManagerTestHelper do
  @moduledoc """
  Test helper functions for DependencyManager tests.
  """

  @doc "Creates a complex version requirements structure for testing."
  @spec create_complex_version_requirements(term()) :: %{}
  def create_complex_version_requirements(_input), do: %{}

  @doc "Creates a plugin set for dependency tests."
  @spec create_plugin_set(term()) :: %{}
  def create_plugin_set(_input), do: %{}

  @doc "Creates a dependency chain for testing."
  @spec create_dependency_chain(term()) :: []
  def create_dependency_chain(_input), do: []

  @doc "Measures the execution time of a function or operation."
  @spec measure_time((-> term())) :: integer()
  def measure_time(fun) when is_function(fun, 0) do
    start = System.monotonic_time(:microsecond)
    _ = fun.()
    System.monotonic_time(:microsecond) - start
  end

  @doc "Measures the memory usage of a function or operation."
  @spec measure_memory_usage((-> term())) :: integer()
  def measure_memory_usage(fun) when is_function(fun, 0) do
    :erlang.garbage_collect()
    {:memory, memory_before} = :erlang.process_info(self(), :memory)
    _ = fun.()
    :erlang.garbage_collect()
    {:memory, memory_after} = :erlang.process_info(self(), :memory)
    memory_after - memory_before
  end
end
