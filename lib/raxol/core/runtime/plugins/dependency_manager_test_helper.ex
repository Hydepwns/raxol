defmodule Raxol.Core.Runtime.Plugins.DependencyManagerTestHelper do
  @moduledoc """
  Test helper functions for DependencyManager tests.
  """

  @doc "Creates a complex version requirements structure for testing."
  @spec create_complex_version_requirements(term()) :: term()
  def create_complex_version_requirements(_input), do: %{}

  @doc "Creates a plugin set for dependency tests."
  @spec create_plugin_set(term()) :: term()
  def create_plugin_set(_input), do: %{}

  @doc "Creates a dependency chain for testing."
  @spec create_dependency_chain(term()) :: term()
  def create_dependency_chain(_input), do: []

  @doc "Measures the execution time of a function or operation."
  @spec measure_time((-> any())) :: integer()
  def measure_time(fun) when is_function(fun, 0) do
    start = System.monotonic_time(:microsecond)
    fun.()
    System.monotonic_time(:microsecond) - start
  end

  @doc "Measures the memory usage of a function or operation."
  @spec measure_memory_usage((-> any())) :: integer()
  def measure_memory_usage(fun) when is_function(fun, 0) do
    :erlang.garbage_collect()
    {memory_before, _} = :erlang.process_info(self(), :memory)
    fun.()
    :erlang.garbage_collect()
    {memory_after, _} = :erlang.process_info(self(), :memory)
    memory_after - memory_before
  end
end
