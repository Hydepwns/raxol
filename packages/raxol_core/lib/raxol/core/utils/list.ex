defmodule Raxol.Core.Utils.List do
  @moduledoc """
  Shared list and collection utilities.
  """

  @doc """
  Wraps a non-list value in a list. Returns lists unchanged.

  ## Examples

      iex> Raxol.Core.Utils.List.ensure_list([1, 2])
      [1, 2]

      iex> Raxol.Core.Utils.List.ensure_list(:foo)
      [:foo]
  """
  @spec ensure_list(list()) :: list()
  @spec ensure_list(term()) :: [term()]
  def ensure_list(value) when is_list(value), do: value
  def ensure_list(value), do: [value]

  @doc """
  Zips two lists, padding the shorter one with `nil`.

  Unlike `Enum.zip/2`, this does not truncate to the shorter list.

  ## Examples

      iex> Raxol.Core.Utils.List.zip_longest([1, 2, 3], [:a, :b])
      [{1, :a}, {2, :b}, {3, nil}]

      iex> Raxol.Core.Utils.List.zip_longest([1], [2, 3])
      [{1, 2}, {nil, 3}]
  """
  @spec zip_longest(list(), list()) :: [{term(), term()}]
  def zip_longest([], []), do: []
  def zip_longest([], [b | bs]), do: [{nil, b} | zip_longest([], bs)]
  def zip_longest([a | as], []), do: [{a, nil} | zip_longest(as, [])]
  def zip_longest([a | as], [b | bs]), do: [{a, b} | zip_longest(as, bs)]
end
