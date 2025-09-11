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
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      string_key = to_string(key)

      stringified_value =
        case value do
          v when is_map(v) -> stringify_keys(v)
          v when is_list(v) -> Enum.map(v, &stringify_keys/1)
          v -> v
        end

      Map.put(acc, string_key, stringified_value)
    end)
  end

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
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      atom_key = 
        cond do
          is_atom(key) -> key
          is_binary(key) -> String.to_atom(key)
          true -> String.to_atom(to_string(key))
        end

      atomized_value =
        case value do
          v when is_map(v) -> atomize_keys(v)
          v when is_list(v) -> Enum.map(v, &atomize_keys/1)
          v -> v
        end

      Map.put(acc, atom_key, atomized_value)
    end)
  end

  def atomize_keys(value), do: value

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
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      safe_key =
        cond do
          is_atom(key) -> key
          is_binary(key) -> String.to_existing_atom(key)
          true -> key
        end
        |> case do
          key when is_atom(key) -> key
          _ -> key
        end

      safe_value =
        case value do
          v when is_map(v) -> safe_atomize_keys(v)
          v when is_list(v) -> Enum.map(v, &safe_atomize_keys/1)
          v -> v
        end

      Map.put(acc, safe_key, safe_value)
    end)
  rescue
    ArgumentError -> map
  end

  def safe_atomize_keys(value), do: value
end