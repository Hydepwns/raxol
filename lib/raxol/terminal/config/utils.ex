defmodule Raxol.Terminal.Config.Utils do
  import Raxol.Guards

  @moduledoc """
  Utility functions for handling terminal configuration maps.
  """

  @doc """
  Deeply merges two maps.

  Keys in the right map take precedence. If both values for a key are maps,
  they are merged recursively.
  """
  @spec deep_merge(map(), map()) :: map()
  def deep_merge(left, right) when map?(left) and map?(right) do
    Map.merge(left, right, fn
      _key, left_value, right_value
      when map?(left_value) and map?(right_value) ->
        deep_merge(left_value, right_value)

      _key, _left_value, right_value ->
        right_value
    end)
  end

  def deep_merge(_, right) when map?(right), do: right

  def deep_merge(_, _), do: %{}

  @doc """
  Converts a keyword list or map of potentially nested options into a nested map.

  Handles flat keys like `theme: "light"` and nested paths represented
  by lists like `[behavior: [scrollback: 100]]` within the keyword list.
  """
  @spec opts_to_nested_map(Keyword.t() | map()) :: map()
  def opts_to_nested_map(opts) when list?(opts) or map?(opts) do
    Enum.reduce(opts, %{}, fn {key, value}, acc ->
      nested_map = create_nested_map(key, value)
      deep_merge(acc, nested_map)
    end)
  end

  # Creates a potentially nested map from a single key-value pair.
  # Key can be an atom or a list of atoms representing the path.
  defp create_nested_map(key, value) when atom?(key) do
    %{key => value}
  end

  defp create_nested_map(path, value) when list?(path) do
    path_to_nested_map(path, value)
  end

  # Helper to build the nested map structure from a path list
  defp path_to_nested_map([key], value) when atom?(key) do
    %{key => value}
  end

  defp path_to_nested_map([head | tail], value)
       when atom?(head) and list?(tail) do
    %{head => path_to_nested_map(tail, value)}
  end

  @doc """
  Merges configuration options into an existing configuration map.

  The `opts` are first converted into a nested map structure and then
  deeply merged into the `current_config`.
  """
  @spec merge_opts(map(), Keyword.t() | map()) :: map()
  def merge_opts(current_config, opts) when map?(current_config) do
    nested_opts_map = opts_to_nested_map(opts)
    deep_merge(current_config, nested_opts_map)
  end
end
