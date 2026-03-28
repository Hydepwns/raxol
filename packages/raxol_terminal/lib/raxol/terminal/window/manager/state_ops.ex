defmodule Raxol.Terminal.Window.Manager.StateOps do
  @moduledoc """
  Pure functional state operations for the WindowManagerServer.

  Handles window CRUD, property updates, and Z-order management
  without GenServer concerns.
  """

  alias Raxol.Terminal.Window

  @doc """
  Builds a new Window struct from a config and assigns an ID.
  """
  def build_window(config, window_id) do
    %Window{
      id: window_id,
      title: Map.get(config, :title, ""),
      width: config.width,
      height: config.height,
      position: {Map.get(config, :x, 0), Map.get(config, :y, 0)},
      size: {config.width, config.height},
      state: :inactive
    }
  end

  @doc """
  Builds a child Window struct from a config, parent ID, and window ID.
  """
  def build_child_window(config, window_id, parent_id) do
    %Window{
      id: window_id,
      title: Map.get(config, :title, ""),
      width: config.width,
      height: config.height,
      position: {Map.get(config, :x, 0), Map.get(config, :y, 0)},
      size: {config.width, config.height},
      state: :inactive,
      parent: parent_id
    }
  end

  @doc """
  Optionally activates window_id if no active window exists yet.
  """
  def maybe_activate_first_window(state, nil, window_id) do
    %{state | active_window: window_id}
  end

  def maybe_activate_first_window(state, _active_window, _window_id) do
    state
  end

  @doc """
  Determines the new active window after a window is destroyed.
  """
  def update_active_after_destroy(active_window, window_id, new_window_order)
      when active_window == window_id do
    List.first(new_window_order)
  end

  def update_active_after_destroy(active_window, _window_id, _new_window_order) do
    active_window
  end

  @doc """
  Calculates split size for a child window.
  """
  def calculate_split_size({width, height}, :horizontal) do
    {width, div(height, 2)}
  end

  def calculate_split_size({width, height}, :vertical) do
    {div(width, 2), height}
  end

  @doc """
  Updates all window states when a new active window is set.
  Returns {:reply, :ok, new_state} or {:reply, {:error, :not_found}, state}.
  """
  def apply_set_active_window(false, _window_id, state) do
    {:reply, {:error, :not_found}, state}
  end

  def apply_set_active_window(true, window_id, state) do
    new_windows =
      state.windows
      |> Enum.map(fn {id, window} ->
        new_w_state = determine_window_state(id == window_id, window.state)
        {id, %{window | state: new_w_state}}
      end)
      |> Enum.into(%{})

    new_state = %{state | windows: new_windows, active_window: window_id}
    {:reply, :ok, new_state}
  end

  defp determine_window_state(true, _current_state), do: :active
  defp determine_window_state(false, :active), do: :inactive
  defp determine_window_state(false, current_state), do: current_state

  @doc """
  Moves a window to the front of the Z-order.
  Returns {:reply, result, new_state}.
  """
  def apply_move_to_front(false, _window_id, state) do
    {:reply, {:error, :not_found}, state}
  end

  def apply_move_to_front(true, window_id, state) do
    new_order = [window_id | List.delete(state.window_order, window_id)]
    {:reply, :ok, %{state | window_order: new_order}}
  end

  @doc """
  Moves a window to the back of the Z-order.
  Returns {:reply, result, new_state}.
  """
  def apply_move_to_back(false, _window_id, state) do
    {:reply, {:error, :not_found}, state}
  end

  def apply_move_to_back(true, window_id, state) do
    new_order = List.delete(state.window_order, window_id) ++ [window_id]
    {:reply, :ok, %{state | window_order: new_order}}
  end

  @doc """
  Updates a window property by ID. Takes a function that transforms the window.
  Returns {:ok, updated_window, new_state} or {:error, :not_found}.
  """
  def update_window_by_id(state, window_id, update_fn) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:error, :not_found}

      window ->
        updated_window = update_fn.(window)
        new_windows = Map.put(state.windows, window_id, updated_window)
        {:ok, updated_window, %{state | windows: new_windows}}
    end
  end

  @doc """
  Builds the legacy-format state map for get_state.
  """
  def build_legacy_state(state) do
    %{
      title: state.window_title,
      icon_name: state.icon_name,
      icon_title: state.icon_title,
      windows: state.windows,
      active_window: state.active_window,
      state: state.window_state,
      size: state.window_size
    }
  end
end
