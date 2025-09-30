defmodule Raxol.Terminal.Window.Manager.WindowManagerServer do
  @moduledoc """
  GenServer implementation for terminal window management in Raxol.

  This server provides a pure functional approach to window management,
  eliminating Process dictionary usage and implementing proper OTP patterns.

  ## Features
  - Window creation, destruction, and lifecycle management
  - Hierarchical window relationships (parent/child)
  - Window state tracking (active, inactive, minimized, maximized)
  - Window properties management (title, size, position)
  - Icon management for windows
  - Supervised state management with fault tolerance

  ## State Structure
  The server maintains state with the following structure:
  ```elixir
  %{
    windows: %{window_id => Window.t()},
    active_window: window_id | nil,
    window_order: [window_id],  # Z-order for stacking
    window_state: :normal | :minimized | :maximized | :fullscreen,
    window_size: {width, height},
    window_title: String.t(),
    icon_name: String.t(),
    icon_title: String.t(),
    spatial_map: %{},  # For spatial navigation
    navigation_paths: %{},  # Custom navigation paths
    next_window_id: integer()
  }
  ```
  """

  use Raxol.Core.Behaviours.BaseManager

  require Logger

  alias Raxol.Terminal.{Window, Config}
  alias Raxol.Core.NavigationUtils

  @default_state %{
    windows: %{},
    active_window: nil,
    window_order: [],
    window_state: :normal,
    window_size: {80, 24},
    window_title: "",
    icon_name: "",
    icon_title: "",
    spatial_map: %{},
    navigation_paths: %{},
    next_window_id: 1
  }

  # Client API

  @doc """
  Creates a new window with the given configuration.
  """
  def create_window(config_or_width, height_or_config \\ nil)

  def create_window(%Config{} = config, nil) do
    GenServer.call(__MODULE__, {:create_window, config})
  end

  def create_window(width, height)
      when is_integer(width) and is_integer(height) do
    create_window(%Config{width: width, height: height})
  end

  def create_window(server, %Config{} = config) when is_atom(server) do
    GenServer.call(server, {:create_window, config})
  end

  @doc """
  Gets a window by ID.
  """
  def get_window(server \\ __MODULE__, window_id) do
    GenServer.call(server, {:get_window, window_id})
  end

  @doc """
  Destroys a window by ID.
  """
  def destroy_window(server \\ __MODULE__, window_id) do
    GenServer.call(server, {:destroy_window, window_id})
  end

  @doc """
  Lists all windows.
  """
  def list_windows(server \\ __MODULE__) do
    GenServer.call(server, :list_windows)
  end

  @doc """
  Sets the active window.
  """
  def set_active_window(server \\ __MODULE__, window_id) do
    GenServer.call(server, {:set_active_window, window_id})
  end

  @doc """
  Gets the active window.
  """
  def get_active_window(server \\ __MODULE__) do
    GenServer.call(server, :get_active_window)
  end

  @doc """
  Sets the window state (normal, minimized, maximized, fullscreen).
  """
  def set_window_state(state)
      when state in [:normal, :minimized, :maximized, :fullscreen] do
    set_window_state(__MODULE__, state)
  end

  def set_window_state(server, state)
      when is_atom(server) and
             state in [:normal, :minimized, :maximized, :fullscreen] do
    GenServer.call(server, {:set_window_state, state})
  end

  @doc """
  Sets a specific window's state.
  """
  def set_window_state(server, window_id, state)
      when is_atom(server) and
             state in [:active, :inactive, :minimized, :maximized] do
    GenServer.call(server, {:set_window_state_by_id, window_id, state})
  end

  @doc """
  Gets the window manager state.
  """
  def get_window_state(server \\ __MODULE__) do
    GenServer.call(server, :get_window_state)
  end

  @doc """
  Sets the window size.
  """
  def set_window_size(width, height)
      when is_integer(width) and width > 0 and is_integer(height) and height > 0 do
    set_window_size(__MODULE__, width, height)
  end

  def set_window_size(server, width, height)
      when is_atom(server) and is_integer(width) and width > 0 and
             is_integer(height) and height > 0 do
    GenServer.call(server, {:set_window_size, width, height})
  end

  @doc """
  Sets a specific window's size.
  """
  def set_window_size(server, window_id, width, height) when is_atom(server) do
    GenServer.call(server, {:set_window_size_by_id, window_id, width, height})
  end

  @doc """
  Gets the window size.
  """
  def get_window_size(server \\ __MODULE__) do
    GenServer.call(server, :get_window_size)
  end

  @doc """
  Sets the window title.
  """
  def set_window_title(title) when is_binary(title) do
    set_window_title(__MODULE__, title)
  end

  def set_window_title(server, title)
      when is_atom(server) and is_binary(title) do
    GenServer.call(server, {:set_window_title, title})
  end

  @doc """
  Sets a specific window's title.
  """
  def set_window_title(server, window_id, title) when is_atom(server) do
    GenServer.call(server, {:set_window_title_by_id, window_id, title})
  end

  @doc """
  Sets the icon name.
  """
  def set_icon_name(server \\ __MODULE__, icon_name)
      when is_binary(icon_name) do
    GenServer.call(server, {:set_icon_name, icon_name})
  end

  @doc """
  Sets the icon title.
  """
  def set_icon_title(server \\ __MODULE__, icon_title)
      when is_binary(icon_title) do
    GenServer.call(server, {:set_icon_title, icon_title})
  end

  @doc """
  Moves a window in the Z-order.
  """
  def move_window_to_front(server \\ __MODULE__, window_id) do
    GenServer.call(server, {:move_window_to_front, window_id})
  end

  @doc """
  Moves a window to the back in Z-order.
  """
  def move_window_to_back(server \\ __MODULE__, window_id) do
    GenServer.call(server, {:move_window_to_back, window_id})
  end

  @doc """
  Registers a window's spatial position for navigation.
  """
  def register_window_position(
        server \\ __MODULE__,
        window_id,
        x,
        y,
        width,
        height
      ) do
    GenServer.call(
      server,
      {:register_window_position, window_id, x, y, width, height}
    )
  end

  @doc """
  Defines a navigation path between windows.
  """
  def define_navigation_path(server \\ __MODULE__, from_id, direction, to_id) do
    GenServer.call(server, {:define_navigation_path, from_id, direction, to_id})
  end

  @doc """
  Gets the complete state (for debugging/migration).
  """
  def get_state(server \\ __MODULE__) do
    GenServer.call(server, :get_state)
  end

  @doc """
  Resets to initial state.
  """
  def reset(server \\ __MODULE__) do
    GenServer.call(server, :reset)
  end

  # BaseManager Callbacks

  @impl true
  def init_manager(initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_manager_call({:create_window, config}, _from, state) do
    window_id = "window_#{state.next_window_id}"

    window = %Window{
      id: window_id,
      title: Map.get(config, :title, ""),
      width: config.width,
      height: config.height,
      position: {Map.get(config, :x, 0), Map.get(config, :y, 0)},
      size: {config.width, config.height},
      state: :inactive
    }

    new_windows = Map.put(state.windows, window_id, window)
    new_window_order = [window_id | state.window_order]

    new_state = %{
      state
      | windows: new_windows,
        window_order: new_window_order,
        next_window_id: state.next_window_id + 1
    }

    # Activate if it's the first window
    new_state =
      maybe_activate_first_window(new_state, state.active_window, window_id)

    {:reply, {:ok, window}, new_state}
  end

  @impl true
  def handle_manager_call({:get_window, window_id}, _from, state) do
    case Map.get(state.windows, window_id) do
      nil -> {:reply, {:error, :not_found}, state}
      window -> {:reply, {:ok, window}, state}
    end
  end

  @impl true
  def handle_manager_call({:destroy_window, window_id}, _from, state) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _window ->
        new_windows = Map.delete(state.windows, window_id)
        new_window_order = List.delete(state.window_order, window_id)

        # Update active window if necessary
        new_active =
          update_active_after_destroy(
            state.active_window,
            window_id,
            new_window_order
          )

        # Clean up spatial map and navigation paths
        new_spatial_map = Map.delete(state.spatial_map, window_id)
        new_nav_paths = Map.delete(state.navigation_paths, window_id)

        new_state = %{
          state
          | windows: new_windows,
            window_order: new_window_order,
            active_window: new_active,
            spatial_map: new_spatial_map,
            navigation_paths: new_nav_paths
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_manager_call(:list_windows, _from, state) do
    windows = Map.values(state.windows)
    {:reply, {:ok, windows}, state}
  end

  @impl true
  def handle_manager_call({:set_active_window, window_id}, _from, state) do
    handle_set_active_window(
      Map.has_key?(state.windows, window_id),
      window_id,
      state
    )
  end

  @impl true
  def handle_manager_call(:get_active_window, _from, state) do
    case state.active_window do
      nil ->
        {:reply, nil, state}

      id ->
        case Map.get(state.windows, id) do
          nil -> {:reply, nil, state}
          window -> {:reply, {:ok, window}, state}
        end
    end
  end

  @impl true
  def handle_manager_call({:set_window_state, state_value}, _from, state) do
    new_state = %{state | window_state: state_value}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call(
        {:set_window_state_by_id, window_id, state_value},
        _from,
        state
      ) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      window ->
        updated_window = %{window | state: state_value}
        new_windows = Map.put(state.windows, window_id, updated_window)
        new_state = %{state | windows: new_windows}
        {:reply, {:ok, updated_window}, new_state}
    end
  end

  @impl true
  def handle_manager_call(:get_window_state, _from, state) do
    {:reply, state.window_state, state}
  end

  @impl true
  def handle_manager_call({:set_window_size, width, height}, _from, state) do
    new_state = %{state | window_size: {width, height}}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call(
        {:set_window_size_by_id, window_id, width, height},
        _from,
        state
      ) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      window ->
        updated_window = %{
          window
          | width: width,
            height: height,
            size: {width, height}
        }

        new_windows = Map.put(state.windows, window_id, updated_window)
        new_state = %{state | windows: new_windows}
        {:reply, {:ok, updated_window}, new_state}
    end
  end

  @impl true
  def handle_manager_call(:get_window_size, _from, state) do
    {:reply, state.window_size, state}
  end

  @impl true
  def handle_manager_call({:set_window_title, title}, _from, state) do
    new_state = %{state | window_title: title}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call(
        {:set_window_title_by_id, window_id, title},
        _from,
        state
      ) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      window ->
        updated_window = %{window | title: title}
        new_windows = Map.put(state.windows, window_id, updated_window)
        new_state = %{state | windows: new_windows}
        {:reply, {:ok, updated_window}, new_state}
    end
  end

  @impl true
  def handle_manager_call({:set_icon_name, icon_name}, _from, state) do
    new_state = %{state | icon_name: icon_name}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:set_icon_title, icon_title}, _from, state) do
    new_state = %{state | icon_title: icon_title}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:move_window_to_front, window_id}, _from, state) do
    handle_move_window_to_front(
      Map.has_key?(state.windows, window_id),
      window_id,
      state
    )
  end

  @impl true
  def handle_manager_call({:move_window_to_back, window_id}, _from, state) do
    handle_move_window_to_back(
      Map.has_key?(state.windows, window_id),
      window_id,
      state
    )
  end

  @impl true
  def handle_manager_call({:set_window_position, window_id, x, y}, _from, state) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      window ->
        updated_window = %{window | position: {x, y}}
        new_windows = Map.put(state.windows, window_id, updated_window)
        new_state = %{state | windows: new_windows}
        {:reply, {:ok, updated_window}, new_state}
    end
  end

  @impl true
  def handle_manager_call(
        {:create_child_window, parent_id, config},
        _from,
        state
      ) do
    case Map.get(state.windows, parent_id) do
      nil ->
        {:reply, {:error, :parent_not_found}, state}

      parent ->
        child_id = "window_#{state.next_window_id}"

        child = %Window{
          id: child_id,
          title: Map.get(config, :title, ""),
          width: config.width,
          height: config.height,
          position: {Map.get(config, :x, 0), Map.get(config, :y, 0)},
          size: {config.width, config.height},
          state: :inactive,
          parent: parent_id
        }

        # Update parent to include child
        updated_parent = %{parent | children: [child_id | parent.children]}

        new_windows =
          state.windows
          |> Map.put(child_id, child)
          |> Map.put(parent_id, updated_parent)

        new_state = %{
          state
          | windows: new_windows,
            window_order: [child_id | state.window_order],
            next_window_id: state.next_window_id + 1
        }

        {:reply, {:ok, child}, new_state}
    end
  end

  @impl true
  def handle_manager_call({:get_child_windows, parent_id}, _from, state) do
    case Map.get(state.windows, parent_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      parent ->
        children =
          Enum.map(parent.children, &Map.get(state.windows, &1))
          |> Enum.filter(&(&1 != nil))

        {:reply, {:ok, children}, state}
    end
  end

  @impl true
  def handle_manager_call({:get_parent_window, child_id}, _from, state) do
    case Map.get(state.windows, child_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      child ->
        case child.parent do
          nil ->
            {:reply, {:error, :no_parent}, state}

          parent_id ->
            case Map.get(state.windows, parent_id) do
              nil -> {:reply, {:error, :parent_not_found}, state}
              parent -> {:reply, {:ok, parent}, state}
            end
        end
    end
  end

  @impl true
  def handle_manager_call(
        {:register_window_position, window_id, x, y, width, height},
        _from,
        state
      ) do
    position_data = %{
      id: window_id,
      x: x,
      y: y,
      width: width,
      height: height,
      center_x: x + div(width, 2),
      center_y: y + div(height, 2)
    }

    new_spatial_map = Map.put(state.spatial_map, window_id, position_data)
    new_state = %{state | spatial_map: new_spatial_map}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call(
        {:define_navigation_path, from_id, direction, to_id},
        _from,
        state
      ) do
    new_state =
      NavigationUtils.define_navigation_path(state, from_id, direction, to_id)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call(:get_state, _from, state) do
    # Return a map compatible with the original implementation
    legacy_state = %{
      title: state.window_title,
      icon_name: state.icon_name,
      icon_title: state.icon_title,
      windows: state.windows,
      active_window: state.active_window,
      state: state.window_state,
      size: state.window_size
    }

    {:reply, legacy_state, state}
  end

  @impl true
  def handle_manager_call(:reset, _from, _state) do
    {:reply, :ok, @default_state}
  end

  # Private helper functions

  defp maybe_activate_first_window(new_state, nil, window_id) do
    %{new_state | active_window: window_id}
  end

  defp maybe_activate_first_window(new_state, _active_window, _window_id) do
    new_state
  end

  defp update_active_after_destroy(active_window, window_id, new_window_order)
       when active_window == window_id do
    List.first(new_window_order)
  end

  defp update_active_after_destroy(active_window, _window_id, _new_window_order) do
    active_window
  end

  defp handle_set_active_window(false, _window_id, state) do
    {:reply, {:error, :not_found}, state}
  end

  defp handle_set_active_window(true, window_id, state) do
    # Update window states
    new_windows =
      state.windows
      |> Enum.map(fn {id, window} ->
        new_state = determine_window_state(id == window_id, window.state)
        {id, %{window | state: new_state}}
      end)
      |> Enum.into(%{})

    new_state = %{state | windows: new_windows, active_window: window_id}
    {:reply, :ok, new_state}
  end

  defp determine_window_state(true, _current_state) do
    :active
  end

  defp determine_window_state(false, :active) do
    :inactive
  end

  defp determine_window_state(false, current_state) do
    current_state
  end

  defp handle_move_window_to_front(false, _window_id, state) do
    {:reply, {:error, :not_found}, state}
  end

  defp handle_move_window_to_front(true, window_id, state) do
    new_order = [window_id | List.delete(state.window_order, window_id)]
    new_state = %{state | window_order: new_order}
    {:reply, :ok, new_state}
  end

  defp handle_move_window_to_back(false, _window_id, state) do
    {:reply, {:error, :not_found}, state}
  end

  defp handle_move_window_to_back(true, window_id, state) do
    new_order = List.delete(state.window_order, window_id) ++ [window_id]
    new_state = %{state | window_order: new_order}
    {:reply, :ok, new_state}
  end

  # Missing API function implementations

  @doc """
  Sets window position.
  """
  def set_window_position(window_id, x, y) do
    GenServer.call(__MODULE__, {:set_window_position, window_id, x, y})
  end

  @doc """
  Creates a child window.
  """
  def create_child_window(parent_id, config) do
    GenServer.call(__MODULE__, {:create_child_window, parent_id, config})
  end

  @doc """
  Gets child windows.
  """
  def get_child_windows(parent_id) do
    GenServer.call(__MODULE__, {:get_child_windows, parent_id})
  end

  @doc """
  Gets parent window.
  """
  def get_parent_window(child_id) do
    GenServer.call(__MODULE__, {:get_parent_window, child_id})
  end
end
