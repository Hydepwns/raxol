defmodule Raxol.Utils.MapUtils do
  @moduledoc """
  Common utility functions for map operations.

  This module consolidates frequently used map transformation functions
  to avoid code duplication across the codebase.
  """

  @doc """
  Recursively converts all map keys to strings.

  ## Examples

      iex> Raxol.Utils.MapUtils.stringify_keys(%{foo: "bar", nested: %{key: "value"}})
      %{"foo" => "bar", "nested" => %{"key" => "value"}}

      iex> Raxol.Utils.MapUtils.stringify_keys(%{:atom => [%{inner: "value"}]})
      %{"atom" => [%{"inner" => "value"}]}
  """
  @spec stringify_keys(any()) :: any()
  def stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {to_string(key), stringify_keys(value)}
    end)
  end

  def stringify_keys(list) when is_list(list),
    do: Enum.map(list, &stringify_keys/1)

  def stringify_keys(value), do: value

  @doc """
  Recursively converts all map keys to atoms.

  ## Examples

      iex> Raxol.Utils.MapUtils.atomize_keys(%{"foo" => "bar", "nested" => %{"key" => "value"}})
      %{foo: "bar", nested: %{key: "value"}}

      iex> Raxol.Utils.MapUtils.atomize_keys(%{"atom" => [%{"inner" => "value"}]})
      %{atom: [%{inner: "value"}]}
  """
  @spec atomize_keys(any()) :: any()
  def atomize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {to_atom_key(key), atomize_keys(value)}
    end)
  end

  def atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys/1)
  def atomize_keys(value), do: value

  defp to_atom_key(key) when is_atom(key), do: key
  defp to_atom_key(key) when is_binary(key), do: String.to_atom(key)
  defp to_atom_key(key), do: String.to_atom(to_string(key))

  @doc """
  Safely atomizes keys, only converting strings that already exist as atoms.
  This prevents atom exhaustion attacks.

  ## Examples

      iex> Raxol.Utils.MapUtils.safe_atomize_keys(%{"foo" => "bar"})
      %{"foo" => "bar"}  # "foo" atom doesn't exist

      iex> _ = :existing_atom
      iex> Raxol.Utils.MapUtils.safe_atomize_keys(%{"existing_atom" => "value"})
      %{existing_atom: "value"}
  """
  @spec safe_atomize_keys(any()) :: any()
  def safe_atomize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {to_safe_atom_key(key), safe_atomize_keys(value)}
    end)
  rescue
    ArgumentError -> map
  end

  def safe_atomize_keys(list) when is_list(list),
    do: Enum.map(list, &safe_atomize_keys/1)

  def safe_atomize_keys(value), do: value

  defp to_safe_atom_key(key) when is_atom(key), do: key

  defp to_safe_atom_key(key) when is_binary(key),
    do: String.to_existing_atom(key)

  defp to_safe_atom_key(key), do: key
end
