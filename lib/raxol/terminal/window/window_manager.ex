defmodule Raxol.Terminal.Window.Manager do
  @moduledoc """
  Refactored Window.Manager that delegates to GenServer implementation.

  This module provides the same API as the original Terminal.Window.Manager but uses
  a supervised GenServer instead of the Process dictionary for state management.

  ## Migration Notice
  This module is a drop-in replacement for `Raxol.Terminal.Window.Manager`.
  All functions maintain backward compatibility while providing improved
  fault tolerance and functional programming patterns.

  ## Benefits over Process Dictionary
  - Supervised state management with fault tolerance
  - Pure functional window management
  - Z-order window stacking support
  - Spatial navigation mapping
  - Better debugging and testing capabilities
  - No global state pollution

  ## New Features
  - Window Z-ordering for proper stacking
  - Spatial position tracking for navigation
  - Custom navigation paths between windows
  - Hierarchical window relationships
  """

  alias Raxol.Terminal.Config
  alias Raxol.Terminal.Window.Manager.WindowManagerServer, as: Server

  @type t :: %{tabs: map()}
  @type window_id :: String.t()
  @type window_state :: :active | :inactive | :minimized | :maximized

  @doc """
  Ensures the Window Manager server is started.
  """
  def ensure_started do
    case Process.whereis(Server) do
      nil ->
        case Server.start_link(name: Server) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          error -> error
        end

      _pid ->
        :ok
    end
  end

  @doc """
  Creates a new window manager instance.
  For backward compatibility, returns {:ok, pid()} of the GenServer.
  """
  def new do
    start_link()
  end

  @doc """
  Creates a new window manager instance for testing.
  Returns a simple map structure instead of a process.
  """
  def new_for_test do
    %{
      title: "",
      icon_name: "",
      icon_title: "",
      windows: %{},
      active_window: nil,
      state: :normal,
      size: {80, 24}
    }
  end

  @doc """
  Starts the window manager.
  """
  def start_link, do: start_link([])

  def start_link(_opts) do
    _ = ensure_started()
    # Return self() for backward compatibility with Process dictionary version
    {:ok, self()}
  end

  @doc """
  Gets the window manager state as a map.
  """
  def get_state(_pid) do
    _ = ensure_started()
    Server.get_state()
  end

  @doc """
  Gets the window state.
  """
  def get_window_state(_pid) do
    _ = ensure_started()
    Server.get_window_state()
  end

  @doc """
  Gets the window size.
  """
  def get_window_size(_pid) do
    _ = ensure_started()
    Server.get_window_size()
  end

  @doc """
  Sets the window state.
  """
  def set_window_state(pid, state) when is_pid(pid) do
    _ = ensure_started()
    Server.set_window_state(state)
  end

  def set_window_state(id, state) do
    _ = ensure_started()
    Server.set_window_state(Server, id, state)
  end

  @doc """
  Sets the window size.
  """
  def set_window_size(pid, width, height)
      when is_pid(pid) and width > 0 and height > 0 do
    _ = ensure_started()
    Server.set_window_size(width, height)
  end

  def set_window_size(pid, _width, _height) when is_pid(pid) do
    # Ignore invalid sizes (negative or zero)
    :ok
  end

  def set_window_size(id, width, height) do
    _ = ensure_started()
    Server.set_window_size(Server, id, width, height)
  end

  @doc """
  Sets the window title.
  """
  def set_window_title(pid, title) when is_pid(pid) do
    _ = ensure_started()
    Server.set_window_title(title)
  end

  def set_window_title(id, title) do
    _ = ensure_started()
    Server.set_window_title(Server, id, title)
  end

  @doc """
  Sets the icon name.
  """
  def set_icon_name(pid, icon_name) when is_pid(pid) do
    _ = ensure_started()
    Server.set_icon_name(icon_name)
  end

  def set_icon_name(manager, _icon_name) do
    # For test purposes, just return the manager
    manager
  end

  @doc """
  Creates a new window with the given configuration.
  """
  def create_window(%Config{} = config) do
    _ = ensure_started()
    Server.create_window(config)
  end

  @doc """
  Creates a new window with dimensions.
  """
  def create_window(width, height)
      when is_integer(width) and is_integer(height) do
    _ = ensure_started()
    Server.create_window(width, height)
  end

  @doc """
  Gets a window by ID.
  """
  def get_window(id) do
    _ = ensure_started()
    Server.get_window(id)
  end

  @doc """
  Destroys a window by ID.
  """
  def destroy_window(id) do
    _ = ensure_started()
    Server.destroy_window(id)
  end

  @doc """
  Lists all windows.
  """
  def list_windows do
    _ = ensure_started()
    Server.list_windows()
  end

  # Additional helper functions

  @doc """
  Sets the active window.
  """
  def set_active_window(window_id) do
    _ = ensure_started()
    Server.set_active_window(window_id)
  end

  @doc """
  Gets the active window.
  """
  def get_active_window do
    _ = ensure_started()
    Server.get_active_window()
  end

  @doc """
  Moves a window to the front (top of Z-order).
  """
  def move_window_to_front(window_id) do
    _ = ensure_started()
    Server.move_window_to_front(window_id)
  end

  @doc """
  Moves a window to the back (bottom of Z-order).
  """
  def move_window_to_back(window_id) do
    _ = ensure_started()
    Server.move_window_to_back(window_id)
  end

  @doc """
  Registers a window's spatial position for navigation.
  """
  def register_window_position(window_id, x, y, width, height) do
    _ = ensure_started()
    Server.register_window_position(window_id, x, y, width, height)
  end

  @doc """
  Defines a navigation path between windows.
  """
  def define_navigation_path(from_id, direction, to_id) do
    _ = ensure_started()
    Server.define_navigation_path(from_id, direction, to_id)
  end

  @doc """
  Counts the number of windows.
  """
  def count_windows do
    _ = ensure_started()
    {:ok, windows} = Server.list_windows()
    length(windows)
  end

  @doc """
  Checks if a window exists.
  """
  def window_exists?(window_id) do
    _ = ensure_started()

    case Server.get_window(window_id) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Sets the window position.
  """
  def set_window_position(id, x, y) do
    _ = ensure_started()
    Server.set_window_position(id, x, y)
  end

  @doc """
  Creates a child window.
  """
  def create_child_window(parent_id, config) do
    _ = ensure_started()
    Server.create_child_window(parent_id, config)
  end

  @doc """
  Gets child windows of a parent.
  """
  def get_child_windows(parent_id) do
    _ = ensure_started()
    Server.get_child_windows(parent_id)
  end

  @doc """
  Gets the parent window of a child.
  """
  def get_parent_window(child_id) do
    _ = ensure_started()
    Server.get_parent_window(child_id)
  end

  @doc """
  Resets the window manager to initial state.
  """
  def reset do
    _ = ensure_started()
    Server.reset()
  end

  @doc """
  Resizes a window. Alias for set_window_size/3.
  """
  def resize(window_id, width, height) do
    set_window_size(window_id, width, height)
  end

  @doc """
  Split a window horizontally or vertically.
  """
  def split_window(window_id, direction) do
    Server.split_window(window_id, direction)
  end

  @doc """
  Set the title of a window.
  """
  def set_title(window_id, title) do
    Server.set_window_title(Server, window_id, title)
  end

  @doc """
  Move a window to the specified position.
  """
  def move(window_id, x, y) do
    set_window_position(window_id, x, y)
  end

  @doc """
  Set the stacking order of a window.
  """
  def set_stacking_order(window_id, order) do
    case order do
      :front -> move_window_to_front(window_id)
      :back -> move_window_to_back(window_id)
      _ -> {:error, :invalid_order}
    end
  end

  @doc """
  Updates the window manager configuration.
  """
  def update_config(config) do
    _ = ensure_started()
    Server.update_config(config)
  end

  @doc """
  Cleanup the window manager. Alias for reset/0.
  """
  def cleanup do
    reset()
  end
end
