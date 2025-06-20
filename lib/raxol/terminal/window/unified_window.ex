defmodule Raxol.Terminal.Window.UnifiedWindow do
  @moduledoc """
  Unified window management system for the Raxol Terminal Emulator.
  Handles window creation, manipulation, state management, and ANSI sequence processing.
  """

  use GenServer
  require Raxol.Core.Runtime.Log

  # Types
  @type window_id :: String.t()
  @type window_state :: %{
          id: window_id(),
          title: String.t(),
          icon_name: String.t(),
          size: {non_neg_integer(), non_neg_integer()},
          position: {non_neg_integer(), non_neg_integer()},
          stacking_order: :normal | :above | :below,
          iconified: boolean(),
          maximized: boolean(),
          previous_size: {non_neg_integer(), non_neg_integer()} | nil,
          split_type: :none | :horizontal | :vertical,
          parent_id: window_id() | nil,
          children: [window_id()],
          buffer_id: String.t(),
          renderer_id: String.t()
        }

  @type t :: %__MODULE__{
          windows: %{window_id() => window_state()},
          active_window: window_id() | nil,
          next_id: non_neg_integer(),
          config: map()
        }

  defstruct windows: %{},
            active_window: nil,
            next_id: 1,
            config: %{
              default_size: {80, 24},
              min_size: {10, 1},
              max_size: {200, 50},
              border_style: :single,
              title_style: :center,
              scroll_history: 1000,
              focus_follows_mouse: true
            }

  # Client API

  @doc """
  Starts the window manager with optional configuration.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts,
      name: Map.get(opts, :name, __MODULE__)
    )
  end

  @doc """
  Creates a new window with the given options.
  """
  @spec create_window(map()) :: {:ok, window_id()} | {:error, String.t()}
  def create_window(opts \\ %{}) do
    GenServer.call(__MODULE__, {:create_window, opts})
  end

  @doc """
  Splits an existing window in the specified direction.
  """
  @spec split_window(window_id(), :horizontal | :vertical) ::
          {:ok, window_id()} | {:error, String.t()}
  def split_window(window_id, direction) do
    GenServer.call(__MODULE__, {:split_window, window_id, direction})
  end

  @doc """
  Closes a window and its children.
  """
  @spec close_window(window_id()) :: :ok | {:error, String.t()}
  def close_window(window_id) do
    GenServer.call(__MODULE__, {:close_window, window_id})
  end

  @doc """
  Sets the window title.
  """
  @spec set_title(window_id(), String.t()) :: :ok | {:error, String.t()}
  def set_title(window_id, title) do
    GenServer.call(__MODULE__, {:set_title, window_id, title})
  end

  @doc """
  Sets the window icon name.
  """
  @spec set_icon_name(window_id(), String.t()) :: :ok | {:error, String.t()}
  def set_icon_name(window_id, name) do
    GenServer.call(__MODULE__, {:set_icon_name, window_id, name})
  end

  @doc """
  Resizes a window to the specified dimensions.
  """
  @spec resize(window_id(), non_neg_integer(), non_neg_integer()) ::
          :ok | {:error, String.t()}
  def resize(window_id, width, height) do
    GenServer.call(__MODULE__, {:resize, window_id, width, height})
  end

  @doc """
  Moves a window to the specified position.
  """
  @spec move(window_id(), non_neg_integer(), non_neg_integer()) ::
          :ok | {:error, String.t()}
  def move(window_id, x, y) do
    GenServer.call(__MODULE__, {:move, window_id, x, y})
  end

  @doc """
  Sets the window's stacking order.
  """
  @spec set_stacking_order(window_id(), :normal | :above | :below) ::
          :ok | {:error, String.t()}
  def set_stacking_order(window_id, order) do
    GenServer.call(__MODULE__, {:set_stacking_order, window_id, order})
  end

  @doc """
  Maximizes or restores a window.
  """
  @spec set_maximized(window_id(), boolean()) :: :ok | {:error, String.t()}
  def set_maximized(window_id, maximized) do
    GenServer.call(__MODULE__, {:set_maximized, window_id, maximized})
  end

  @doc """
  Sets the active window.
  """
  @spec set_active_window(window_id()) :: :ok | {:error, String.t()}
  def set_active_window(window_id) do
    GenServer.call(__MODULE__, {:set_active_window, window_id})
  end

  @doc """
  Gets the state of a window.
  """
  @spec get_window_state(window_id()) ::
          {:ok, window_state()} | {:error, String.t()}
  def get_window_state(window_id) do
    GenServer.call(__MODULE__, {:get_window_state, window_id})
  end

  @doc """
  Gets the active window ID.
  """
  @spec get_active_window() :: window_id() | nil
  def get_active_window do
    GenServer.call(__MODULE__, :get_active_window)
  end

  @doc """
  Updates the window manager configuration.
  """
  @spec update_config(map()) :: :ok
  def update_config(config) do
    GenServer.call(__MODULE__, {:update_config, config})
  end

  @doc """
  Cleans up the window manager.
  """
  def cleanup(_window_manager) do
    # TODO: Implementation for cleanup
    :ok
  end

  # Functions expected by tests
  @doc """
  Maximizes a window.
  """
  @spec maximize(window_id()) :: :ok | {:error, String.t()}
  def maximize(window_id) do
    set_maximized(window_id, true)
  end

  @doc """
  Restores a window from maximized state.
  """
  @spec restore(window_id()) :: :ok | {:error, String.t()}
  def restore(window_id) do
    set_maximized(window_id, false)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    default_state = %__MODULE__{}
    config = Map.merge(default_state.config, opts)
    {:ok, %{default_state | config: config}}
  end

  # Internal helper to create a window (used only inside GenServer callbacks)
  defp do_create_window(opts, state) do
    window_id = "window_#{state.next_id}"

    window_state = %{
      id: window_id,
      title: Map.get(opts, :title, ""),
      icon_name: Map.get(opts, :icon_name, ""),
      size: Map.get(opts, :size, state.config.default_size),
      position: Map.get(opts, :position, {0, 0}),
      stacking_order: :normal,
      iconified: false,
      maximized: false,
      previous_size: nil,
      split_type: :none,
      parent_id: nil,
      children: [],
      buffer_id: Map.get(opts, :buffer_id),
      renderer_id: Map.get(opts, :renderer_id)
    }

    new_state = %{
      state
      | windows: Map.put(state.windows, window_id, window_state),
        next_id: state.next_id + 1,
        active_window:
          if(state.active_window == nil,
            do: window_id,
            else: state.active_window
          )
    }

    {window_id, new_state}
  end

  defp do_close_window(window_id, state) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:error, state}

      window ->
        # Recursively close child windows
        new_state =
          Enum.reduce(window.children, state, fn child_id, acc ->
            case do_close_window(child_id, acc) do
              {:ok, acc2} -> acc2
              {:error, acc2} -> acc2
            end
          end)

        # Remove window from parent's children list
        new_state =
          if window.parent_id do
            parent = Map.get(new_state.windows, window.parent_id)

            updated_parent = %{
              parent
              | children: List.delete(parent.children, window_id)
            }

            %{
              new_state
              | windows:
                  Map.put(new_state.windows, window.parent_id, updated_parent)
            }
          else
            new_state
          end

        # Remove window from windows map
        new_state = %{
          new_state
          | windows: Map.delete(new_state.windows, window_id),
            active_window:
              if(new_state.active_window == window_id,
                do: nil,
                else: new_state.active_window
              )
        }

        {:ok, new_state}
    end
  end

  @impl true
  def handle_call({:create_window, opts}, _from, state) do
    {window_id, new_state} = do_create_window(opts, state)
    {:reply, {:ok, window_id}, new_state}
  end

  @impl true
  def handle_call({:split_window, window_id, direction}, _from, state) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:reply, {:error, "Window not found"}, state}

      window ->
        # Create new window for split (use internal helper)
        {new_window_id, state1} =
          do_create_window(
            %{
              size: window.size,
              position: window.position,
              buffer_id: Map.get(state.config, :default_buffer_id),
              renderer_id: Map.get(state.config, :default_renderer_id)
            },
            state
          )

        # Update parent window
        updated_window = %{
          window
          | split_type: direction,
            children: [new_window_id | window.children]
        }

        # Update new window
        new_window = Map.get(state1.windows, new_window_id)
        updated_new_window = %{new_window | parent_id: window_id}

        new_state = %{
          state1
          | windows:
              state1.windows
              |> Map.put(window_id, updated_window)
              |> Map.put(new_window_id, updated_new_window)
        }

        {:reply, {:ok, new_window_id}, new_state}
    end
  end

  @impl true
  def handle_call({:close_window, window_id}, _from, state) do
    case do_close_window(window_id, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, _} -> {:reply, {:error, "Window not found"}, state}
    end
  end

  @impl true
  def handle_call({:set_title, window_id, title}, _from, state) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:reply, {:error, "Window not found"}, state}

      window ->
        updated_window = %{window | title: title}

        new_state = %{
          state
          | windows: Map.put(state.windows, window_id, updated_window)
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:set_icon_name, window_id, name}, _from, state) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:reply, {:error, "Window not found"}, state}

      window ->
        updated_window = %{window | icon_name: name}

        new_state = %{
          state
          | windows: Map.put(state.windows, window_id, updated_window)
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:resize, window_id, width, height}, _from, state) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:reply, {:error, "Window not found"}, state}

      window ->
        # Store current size if maximizing
        previous_size =
          if window.maximized, do: window.size, else: window.previous_size

        updated_window = %{
          window
          | size: {width, height},
            previous_size: previous_size
        }

        new_state = %{
          state
          | windows: Map.put(state.windows, window_id, updated_window)
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:move, window_id, x, y}, _from, state) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:reply, {:error, "Window not found"}, state}

      window ->
        updated_window = %{window | position: {x, y}}

        new_state = %{
          state
          | windows: Map.put(state.windows, window_id, updated_window)
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:set_stacking_order, window_id, order}, _from, state) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:reply, {:error, "Window not found"}, state}

      window ->
        updated_window = %{window | stacking_order: order}

        new_state = %{
          state
          | windows: Map.put(state.windows, window_id, updated_window)
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:set_maximized, window_id, maximized}, _from, state) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:reply, {:error, "Window not found"}, state}

      window ->
        {size, previous_size} =
          if maximized do
            {state.config.max_size, window.size}
          else
            {window.previous_size || state.config.default_size, nil}
          end

        updated_window = %{
          window
          | maximized: maximized,
            size: size,
            previous_size: previous_size
        }

        new_state = %{
          state
          | windows: Map.put(state.windows, window_id, updated_window)
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:set_active_window, window_id}, _from, state) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:reply, {:error, "Window not found"}, state}

      _window ->
        new_state = %{state | active_window: window_id}
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:get_window_state, window_id}, _from, state) do
    case Map.get(state.windows, window_id) do
      nil ->
        {:reply, {:error, "Window not found"}, state}

      window ->
        {:reply, {:ok, window}, state}
    end
  end

  @impl true
  def handle_call(:get_active_window, _from, state) do
    {:reply, state.active_window, state}
  end

  @impl true
  def handle_call({:update_config, config}, _from, state) do
    new_config = Map.merge(state.config, config)
    {:reply, :ok, %{state | config: new_config}}
  end
end
