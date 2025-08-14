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

  alias Raxol.Terminal.Window.Manager.Server
  alias Raxol.Terminal.{Window, Config}

  @type t :: %{tabs: map()}
  @type window_id :: String.t()
  @type window_state :: :active | :inactive | :minimized | :maximized

  @doc """
  Ensures the Window Manager server is started.
  """
  def ensure_started do
    case Process.whereis(Server) do
      nil ->
        {:ok, _pid} = Server.start_link()
        :ok
      _pid ->
        :ok
    end
  end

  @doc """
  Creates a new window manager instance.
  For backward compatibility, returns {:ok, pid()} of the GenServer.
  """
  @spec new() :: {:ok, pid()}
  def new() do
    start_link()
  end

  @doc """
  Creates a new window manager instance for testing.
  Returns a simple map structure instead of a process.
  """
  @spec new_for_test() :: map()
  def new_for_test() do
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
  @spec start_link() :: {:ok, pid()}
  def start_link, do: start_link([])

  @spec start_link(list()) :: {:ok, pid()}
  def start_link(_opts) do
    ensure_started()
    # Return self() for backward compatibility with Process dictionary version
    {:ok, self()}
  end

  @doc """
  Gets the window manager state as a map.
  """
  @spec get_state(pid()) :: map()
  def get_state(_pid) do
    ensure_started()
    Server.get_state()
  end

  @doc """
  Gets the window state.
  """
  @spec get_window_state(pid()) :: atom()
  def get_window_state(_pid) do
    ensure_started()
    Server.get_window_state()
  end

  @doc """
  Gets the window size.
  """
  @spec get_window_size(pid()) :: {integer(), integer()}
  def get_window_size(_pid) do
    ensure_started()
    Server.get_window_size()
  end

  @doc """
  Sets the window state.
  """
  @spec set_window_state(pid(), atom()) :: :ok
  def set_window_state(pid, state) when is_pid(pid) do
    ensure_started()
    Server.set_window_state(state)
  end

  @spec set_window_state(window_id(), window_state()) ::
          {:ok, Window.t()} | {:error, :not_found}
  def set_window_state(id, state) do
    ensure_started()
    Server.set_window_state(Server, id, state)
  end

  @doc """
  Sets the window size.
  """
  @spec set_window_size(pid(), integer(), integer()) :: :ok
  def set_window_size(pid, width, height)
      when is_pid(pid) and width > 0 and height > 0 do
    ensure_started()
    Server.set_window_size(width, height)
  end

  def set_window_size(pid, _width, _height) when is_pid(pid) do
    # Ignore invalid sizes (negative or zero)
    :ok
  end

  @spec set_window_size(window_id(), integer(), integer()) ::
          {:ok, Window.t()} | {:error, :not_found}
  def set_window_size(id, width, height) do
    ensure_started()
    Server.set_window_size(Server, id, width, height)
  end

  @doc """
  Sets the window title.
  """
  @spec set_window_title(pid(), String.t()) :: :ok
  def set_window_title(pid, title) when is_pid(pid) do
    ensure_started()
    Server.set_window_title(title)
  end

  @spec set_window_title(window_id(), String.t()) ::
          {:ok, Window.t()} | {:error, :not_found}
  def set_window_title(id, title) do
    ensure_started()
    Server.set_window_title(Server, id, title)
  end

  @doc """
  Sets the icon name.
  """
  @spec set_icon_name(pid(), String.t()) :: :ok
  def set_icon_name(pid, icon_name) when is_pid(pid) do
    ensure_started()
    Server.set_icon_name(icon_name)
  end

  @spec set_icon_name(t(), String.t()) :: t()
  def set_icon_name(manager, _icon_name) do
    # For test purposes, just return the manager
    manager
  end

  @doc """
  Creates a new window with the given configuration.
  """
  @spec create_window(Config.t()) :: {:ok, Window.t()} | {:error, term()}
  def create_window(%Config{} = config) do
    ensure_started()
    Server.create_window(config)
  end

  @doc """
  Creates a new window with dimensions.
  """
  @spec create_window(integer(), integer()) ::
          {:ok, Window.t()} | {:error, term()}
  def create_window(width, height)
      when is_integer(width) and is_integer(height) do
    ensure_started()
    Server.create_window(width, height)
  end

  @doc """
  Gets a window by ID.
  """
  @spec get_window(window_id()) :: {:ok, Window.t()} | {:error, :not_found}
  def get_window(id) do
    ensure_started()
    Server.get_window(id)
  end

  @doc """
  Destroys a window by ID.
  """
  @spec destroy_window(window_id()) :: :ok | {:error, :not_found}
  def destroy_window(id) do
    ensure_started()
    Server.destroy_window(id)
  end

  @doc """
  Lists all windows.
  """
  @spec list_windows() :: {:ok, [Window.t()]}
  def list_windows do
    ensure_started()
    Server.list_windows()
  end

  # Additional helper functions

  @doc """
  Sets the active window.
  """
  def set_active_window(window_id) do
    ensure_started()
    Server.set_active_window(window_id)
  end

  @doc """
  Gets the active window.
  """
  def get_active_window do
    ensure_started()
    Server.get_active_window()
  end

  @doc """
  Moves a window to the front (top of Z-order).
  """
  def move_window_to_front(window_id) do
    ensure_started()
    Server.move_window_to_front(window_id)
  end

  @doc """
  Moves a window to the back (bottom of Z-order).
  """
  def move_window_to_back(window_id) do
    ensure_started()
    Server.move_window_to_back(window_id)
  end

  @doc """
  Registers a window's spatial position for navigation.
  """
  def register_window_position(window_id, x, y, width, height) do
    ensure_started()
    Server.register_window_position(window_id, x, y, width, height)
  end

  @doc """
  Defines a navigation path between windows.
  """
  def define_navigation_path(from_id, direction, to_id) do
    ensure_started()
    Server.define_navigation_path(from_id, direction, to_id)
  end

  @doc """
  Counts the number of windows.
  """
  def count_windows do
    ensure_started()
    {:ok, windows} = Server.list_windows()
    length(windows)
  end

  @doc """
  Checks if a window exists.
  """
  def window_exists?(window_id) do
    ensure_started()
    case Server.get_window(window_id) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Resets the window manager to initial state.
  """
  def reset do
    ensure_started()
    Server.reset()
  end
end