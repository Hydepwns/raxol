defmodule Raxol.Terminal.Window.Manager.NavigationOps do
  @moduledoc """
  Pure-functional helpers for spatial navigation and position registration
  within the WindowManagerServer state.
  """

  alias Raxol.Core.NavigationUtils

  @doc "Registers a window's spatial position data in the spatial_map."
  def register_window_position(state, window_id, x, y, width, height) do
    position_data = %{
      id: window_id,
      x: x,
      y: y,
      width: width,
      height: height,
      center_x: x + div(width, 2),
      center_y: y + div(height, 2)
    }

    %{state | spatial_map: Map.put(state.spatial_map, window_id, position_data)}
  end

  @doc "Defines a navigation path between windows using NavigationUtils."
  def define_navigation_path(state, from_id, direction, to_id) do
    NavigationUtils.define_navigation_path(state, from_id, direction, to_id)
  end
end
