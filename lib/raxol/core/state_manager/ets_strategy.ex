defmodule Raxol.Core.StateManager.ETSStrategy do
  @moduledoc """
  ETS-backed state operations for StateManager.
  All functions operate on a named ETS table.
  """

  @default_table :raxol_unified_state

  @doc "Returns the table name from opts, defaulting to :raxol_unified_state."
  def table_name_from_opts(opts) do
    Keyword.get(opts, :table_name, @default_table)
  end

  @doc "Creates the ETS table if it does not exist."
  def init_if_needed(opts) do
    table = table_name_from_opts(opts)

    case :ets.info(table) do
      :undefined ->
        _ =
          :ets.new(table, [
            :set,
            :public,
            :named_table,
            {:read_concurrency, true}
          ])

        :ok

      _ ->
        :ok
    end
  end

  @doc "Gets a single key; returns default when missing."
  def get(key, default, opts) do
    table = table_name_from_opts(opts)

    case :ets.lookup(table, normalize_key(key)) do
      [{_key, value}] -> value
      [] -> default
    end
  end

  @doc "Stores a single key/value pair."
  def set(key, value, opts) do
    table = table_name_from_opts(opts)
    :ets.insert(table, {normalize_key(key), value})
    increment_version(opts)
    :ok
  end

  @doc "Stores a nested key path, updating both tuple key and parent map."
  def set_nested(keys, value, opts) when is_list(keys) do
    table = table_name_from_opts(opts)
    :ets.insert(table, {List.to_tuple(keys), value})

    if length(keys) > 1 do
      parent_key = List.first(keys)

      existing =
        case :ets.lookup(table, parent_key) do
          [{_key, map}] when is_map(map) -> map
          _ -> %{}
        end

      nested = build_nested_map(tl(keys), value)
      updated = Map.merge(existing, nested)
      :ets.insert(table, {parent_key, updated})
    end

    increment_version(opts)
    :ok
  end

  @doc "Updates a key using an update function."
  def update(key, update_fn, opts) do
    table = table_name_from_opts(opts)
    key_normalized = normalize_key(key)

    old_value =
      case :ets.lookup(table, key_normalized) do
        [{_key, value}] -> value
        [] -> nil
      end

    new_value = update_fn.(old_value)
    :ets.insert(table, {key_normalized, new_value})
    increment_version(opts)
    :ok
  end

  @doc "Deletes a single key."
  def delete(key, opts) do
    table = table_name_from_opts(opts)
    :ets.delete(table, normalize_key(key))
    increment_version(opts)
    :ok
  end

  @doc "Deletes a nested key path."
  def delete_nested(keys, opts) when is_list(keys) do
    table = table_name_from_opts(opts)
    :ets.delete(table, List.to_tuple(keys))

    if length(keys) > 1 do
      remove_from_parent_nested_structure(table, keys)
    end

    increment_version(opts)
    :ok
  end

  @doc "Deletes all objects in the table."
  def clear(opts) do
    table = table_name_from_opts(opts)
    :ets.delete_all_objects(table)
    :ok
  end

  @doc "Merges a map of key/value pairs into ETS."
  def merge(state1, state2, opts) when is_map(state1) and is_map(state2) do
    merged = Map.merge(state1, state2)

    Enum.each(merged, fn {key, value} ->
      set(key, value, opts)
    end)

    :ok
  end

  @doc "Returns the entire table as a map (excluding :__version__)."
  def get_all(opts) do
    table = table_name_from_opts(opts)
    version = get_version(opts)

    state_map =
      :ets.tab2list(table)
      |> Enum.reject(fn {k, _v} -> k == :__version__ end)
      |> Enum.into(%{})

    state_map
    |> Map.put(:table, table)
    |> Map.put(:version, version)
  end

  @doc "Gets a nested key path, trying tuple key first then parent map."
  def get_nested(keys, opts) do
    table = table_name_from_opts(opts)

    case :ets.lookup(table, List.to_tuple(keys)) do
      [{_key, value}] ->
        value

      [] ->
        get_from_parent_nested_structure(table, keys)
    end
  end

  @doc "Returns the current version counter."
  def get_version(opts) do
    table = table_name_from_opts(opts)

    case :ets.lookup(table, :__version__) do
      [{:__version__, version}] ->
        version

      [] ->
        :ets.insert(table, {:__version__, 0})
        0
    end
  end

  @doc "Increments the version counter."
  def increment_version(opts) do
    table = table_name_from_opts(opts)
    :ets.update_counter(table, :__version__, 1, {:__version__, 0})
  end

  # --- private helpers ---

  defp normalize_key(key) when is_atom(key) or is_binary(key), do: key
  defp normalize_key(keys) when is_list(keys), do: List.to_tuple(keys)

  defp build_nested_map([key], value), do: %{key => value}

  defp build_nested_map([head | tail], value) do
    %{head => build_nested_map(tail, value)}
  end

  defp get_from_parent_nested_structure(table, keys) do
    parent_key = List.first(keys)

    case :ets.lookup(table, parent_key) do
      [{_key, map}] when is_map(map) -> get_nested_value(map, tl(keys))
      _ -> nil
    end
  end

  defp remove_from_parent_nested_structure(table, keys) do
    parent_key = List.first(keys)

    case :ets.lookup(table, parent_key) do
      [{_key, map}] when is_map(map) ->
        updated = delete_from_nested_map(map, tl(keys))

        if updated == %{} do
          :ets.delete(table, parent_key)
        else
          :ets.insert(table, {parent_key, updated})
        end

      _ ->
        :ok
    end
  end

  defp get_nested_value(map, []) when is_map(map), do: map
  defp get_nested_value(map, [key]) when is_map(map), do: Map.get(map, key)

  defp get_nested_value(map, [head | tail]) when is_map(map) do
    case Map.get(map, head) do
      nested when is_map(nested) -> get_nested_value(nested, tail)
      _ -> nil
    end
  end

  defp delete_from_nested_map(map, [key]) when is_map(map) do
    Map.delete(map, key)
  end

  defp delete_from_nested_map(map, [head | tail]) when is_map(map) do
    case Map.get(map, head) do
      nested when is_map(nested) ->
        updated = delete_from_nested_map(nested, tail)

        if map_size(updated) == 0 do
          Map.delete(map, head)
        else
          Map.put(map, head, updated)
        end

      _ ->
        map
    end
  end

  defp delete_from_nested_map(map, _), do: map
end
