defmodule Raxol.Animation.PathManager do
  @moduledoc """
  Manages animation target paths and state structure utilities.

  This module is responsible for:
  - Qualifying and scoping animation target paths
  - Managing state structure for animations
  - Providing utilities for state updates
  """

  @doc """
  Update an animation's target path to be properly scoped to an element.

  If the animation's `target_path` is a property (e.g., `[:opacity]`), it will be scoped to the element's state (e.g., `[:elements, element_id, :opacity]`).
  If a fully qualified path is provided, it will be used as-is.
  """
  def update_animation_path(animation_def, element_id) do
    case Map.get(animation_def, :target_path) do
      [^element_id | _] ->
        # Already starts with element_id (rare, but just in case)
        animation_def

      [:elements, ^element_id | _] ->
        # Already fully qualified
        animation_def

      [property] when is_atom(property) or is_binary(property) ->
        Map.put(animation_def, :target_path, [
          :elements,
          to_string(element_id),
          property
        ])

      path when is_list(path) ->
        qualify_path(animation_def, path, element_id)

      _ ->
        animation_def
    end
  end

  @doc """
  Qualify a path to be properly scoped to an element.
  """
  def qualify_path(animation_def, path, element_id) do
    case path do
      [:elements, id | _] ->
        id_str = if is_binary(id), do: id, else: to_string(id)
        elem_id_str = to_string(element_id)

        if id == element_id or id_str == elem_id_str do
          animation_def
        else
          Map.put(
            animation_def,
            :target_path,
            [:elements, elem_id_str] ++ path
          )
        end

      _ ->
        Map.put(
          animation_def,
          :target_path,
          [:elements, to_string(element_id)] ++ path
        )
    end
  end

  @doc """
  Set a value in a nested state structure at the specified path.
  """
  def set_in_state(state, path, value) when is_list(path) do
    case path do
      [] ->
        state

      [key] ->
        Map.put(state, key, value)

      [key | rest] ->
        current = Map.get(state, key, %{})
        updated = set_in_state(current, rest, value)
        Map.put(state, key, updated)
    end
  end

  def set_in_state(state, key, value) when is_map(state) do
    Map.put(state, key, value)
  end

  def set_in_state(state, _key, _value) do
    state
  end

  @doc """
  Ensure that a state structure has the necessary nested structure for a given path.
  """
  def ensure_state_structure(state, path) do
    case path do
      [] ->
        state

      [key | rest] ->
        current = Map.get(state, key, %{})
        updated = ensure_state_structure(current, rest)
        Map.put(state, key, updated)
    end
  end
end
