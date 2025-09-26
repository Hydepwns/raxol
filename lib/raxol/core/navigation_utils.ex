defmodule Raxol.Core.NavigationUtils do
  @moduledoc """
  Shared utilities for navigation path management.
  Used by both KeyboardNavigator and WindowManager to avoid code duplication.
  """

  @doc """
  Updates navigation paths in state by defining a path from one ID to another in a specific direction.
  Returns the updated state with modified navigation_paths.
  """
  def define_navigation_path(state, from_id, direction, to_id) do
    from_paths = Map.get(state.navigation_paths, from_id, %{})
    updated_from_paths = Map.put(from_paths, direction, to_id)
    new_nav_paths = Map.put(state.navigation_paths, from_id, updated_from_paths)

    %{state | navigation_paths: new_nav_paths}
  end
end
