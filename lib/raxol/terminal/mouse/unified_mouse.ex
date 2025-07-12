defmodule Raxol.Terminal.Mouse.UnifiedMouse do
  @moduledoc """
  Provides unified mouse handling functionality for the terminal emulator.
  This module handles mouse events, tracking, and state management.
  """

  use GenServer
  require Logger

  alias Raxol.Terminal.Integration.State

  # Types
  @type mouse_id :: non_neg_integer()
  @type mouse_button :: :left | :middle | :right | :wheel_up | :wheel_down
  @type mouse_event ::
          :press | :release | :move | :drag | :click | :double_click
  @type mouse_modifier :: :shift | :ctrl | :alt | :meta
  @type mouse_config :: %{
          optional(:tracking) => boolean(),
          optional(:reporting) => boolean(),
          optional(:sgr_mode) => boolean(),
          optional(:urxvt_mode) => boolean(),
          optional(:pixel_mode) => boolean()
        }

  # Client API
  @doc """
  Starts the mouse manager with the given options.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a new mouse context with the given configuration.
  """
  @spec create_mouse(map()) :: {:ok, mouse_id()} | {:error, term()}
  def create_mouse(config \\ %{}) do
    GenServer.call(__MODULE__, {:create_mouse, config})
  end

  @doc """
  Gets the list of all mouse contexts.
  """
  @spec get_mice() :: list(mouse_id())
  def get_mice do
    GenServer.call(__MODULE__, :get_mice)
  end

  @doc """
  Gets the active mouse context ID.
  """
  @spec get_active_mouse() :: {:ok, mouse_id()} | {:error, :no_active_mouse}
  def get_active_mouse do
    GenServer.call(__MODULE__, :get_active_mouse)
  end

  @doc """
  Sets the active mouse context.
  """
  @spec set_active_mouse(mouse_id()) :: :ok | {:error, term()}
  def set_active_mouse(mouse_id) do
    GenServer.call(__MODULE__, {:set_active_mouse, mouse_id})
  end

  @doc """
  Gets the state of a specific mouse context.
  """
  @spec get_mouse_state(mouse_id()) :: {:ok, map()} | {:error, term()}
  def get_mouse_state(mouse_id) do
    GenServer.call(__MODULE__, {:get_mouse_state, mouse_id})
  end

  @doc """
  Updates the configuration of a specific mouse context.
  """
  @spec update_mouse_config(mouse_id(), mouse_config()) ::
          :ok | {:error, term()}
  def update_mouse_config(mouse_id, config) do
    GenServer.call(__MODULE__, {:update_mouse_config, mouse_id, config})
  end

  @doc """
  Processes a mouse event.
  """
  @spec process_mouse_event(
          mouse_id(),
          mouse_event(),
          mouse_button(),
          {integer(), integer()},
          list(mouse_modifier())
        ) :: :ok | {:error, term()}
  def process_mouse_event(mouse_id, event, button, position, modifiers) do
    GenServer.call(
      __MODULE__,
      {:process_mouse_event, mouse_id, event, button, position, modifiers}
    )
  end

  @doc """
  Processes a mouse event from an event map.
  The event map should contain: button, action, modifiers, x, y
  """
  @spec process_mouse_event(mouse_id(), map()) :: :ok | {:error, term()}
  def process_mouse_event(mouse_id, %{} = event) do
    button = Map.get(event, :button, :left)
    action = Map.get(event, :action, :press)
    modifiers = Map.get(event, :modifiers, [])
    x = Map.get(event, :x, 0)
    y = Map.get(event, :y, 0)
    position = {x, y}

    process_mouse_event(mouse_id, action, button, position, modifiers)
  end

  @doc """
  Gets the current mouse position.
  """
  @spec get_mouse_position(mouse_id()) ::
          {:ok, {integer(), integer()}} | {:error, term()}
  def get_mouse_position(mouse_id) do
    GenServer.call(__MODULE__, {:get_mouse_position, mouse_id})
  end

  @doc """
  Gets the current mouse button state.
  """
  @spec get_mouse_button_state(mouse_id()) ::
          {:ok, list(mouse_button())} | {:error, term()}
  def get_mouse_button_state(mouse_id) do
    GenServer.call(__MODULE__, {:get_mouse_button_state, mouse_id})
  end

  @doc """
  Closes a mouse context.
  """
  @spec close_mouse(mouse_id()) :: :ok | {:error, term()}
  def close_mouse(mouse_id) do
    GenServer.call(__MODULE__, {:close_mouse, mouse_id})
  end

  @doc """
  Updates the mouse manager configuration.
  """
  @spec update_config(map()) :: :ok
  def update_config(config) do
    GenServer.call(__MODULE__, {:update_config, config})
  end

  @doc """
  Cleans up resources.
  """
  @spec cleanup() :: :ok
  def cleanup do
    GenServer.call(__MODULE__, :cleanup)
  end

  # Server Callbacks
  def init(opts) do
    state = %{
      mice: %{},
      active_mouse: nil,
      next_id: 1,
      config: Map.merge(default_config(), opts)
    }

    {:ok, state}
  end

  def handle_call({:create_mouse, config}, _from, state) do
    mouse_id = state.next_id

    mouse_state = %{
      id: mouse_id,
      config: Map.merge(default_mouse_config(), config),
      position: {0, 0},
      button_state: %{},
      modifiers: [],
      created_at: System.system_time(:millisecond),
      last_update: System.system_time(:millisecond)
    }

    new_state = %{
      state
      | mice: Map.put(state.mice, mouse_id, mouse_state),
        next_id: mouse_id + 1
    }

    # If this is the first mouse context, make it active
    new_state =
      if state.active_mouse == nil do
        %{new_state | active_mouse: mouse_id}
      else
        new_state
      end

    {:reply, {:ok, mouse_id}, new_state}
  end

  def handle_call(:get_mice, _from, state) do
    {:reply, Map.keys(state.mice), state}
  end

  def handle_call(:get_active_mouse, _from, state) do
    case state.active_mouse do
      nil -> {:reply, {:error, :no_active_mouse}, state}
      mouse_id -> {:reply, {:ok, mouse_id}, state}
    end
  end

  def handle_call({:set_active_mouse, mouse_id}, _from, state) do
    case Map.get(state.mice, mouse_id) do
      nil ->
        {:reply, {:error, :mouse_not_found}, state}

      _mouse ->
        new_state = %{state | active_mouse: mouse_id}
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:get_mouse_state, mouse_id}, _from, state) do
    case Map.get(state.mice, mouse_id) do
      nil -> {:reply, {:error, :mouse_not_found}, state}
      mouse_state -> {:reply, {:ok, mouse_state}, state}
    end
  end

  def handle_call({:update_mouse_config, mouse_id, config}, _from, state) do
    case Map.get(state.mice, mouse_id) do
      nil ->
        {:reply, {:error, :mouse_not_found}, state}

      mouse_state ->
        new_config = Map.merge(mouse_state.config, config)
        new_mouse_state = %{mouse_state | config: new_config}

        new_state = %{
          state
          | mice: Map.put(state.mice, mouse_id, new_mouse_state)
        }

        {:reply, :ok, new_state}
    end
  end

  def handle_call(
        {:process_mouse_event, mouse_id, event, button, position, modifiers},
        _from,
        state
      ) do
    case Map.get(state.mice, mouse_id) do
      nil ->
        {:reply, {:error, :mouse_not_found}, state}

      mouse_state ->
        new_mouse_state =
          process_event(mouse_state, event, button, position, modifiers)

        new_state = %{
          state
          | mice: Map.put(state.mice, mouse_id, new_mouse_state)
        }

        {:reply, :ok, new_state}
    end
  end

  def handle_call({:get_mouse_position, mouse_id}, _from, state) do
    case Map.get(state.mice, mouse_id) do
      nil -> {:reply, {:error, :mouse_not_found}, state}
      mouse_state -> {:reply, {:ok, mouse_state.position}, state}
    end
  end

  def handle_call({:get_mouse_button_state, mouse_id}, _from, state) do
    case Map.get(state.mice, mouse_id) do
      nil -> {:reply, {:error, :mouse_not_found}, state}
      mouse_state -> {:reply, {:ok, mouse_state.button_state}, state}
    end
  end

  def handle_call({:close_mouse, mouse_id}, _from, state) do
    case Map.get(state.mice, mouse_id) do
      nil ->
        {:reply, {:error, :mouse_not_found}, state}

      _mouse ->
        # Remove mouse context
        new_mice = Map.delete(state.mice, mouse_id)

        new_active_mouse =
          update_active_mouse(state.active_mouse, mouse_id, new_mice)

        new_state = %{state | mice: new_mice, active_mouse: new_active_mouse}

        {:reply, :ok, new_state}
    end
  end

  def handle_call({:update_config, config}, _from, state) do
    new_config = Map.merge(state.config, config)
    new_state = %{state | config: new_config}
    {:reply, :ok, new_state}
  end

  def handle_call(:cleanup, _from, state) do
    # Clean up all mouse contexts
    {:reply, :ok, %{state | mice: %{}, active_mouse: nil}}
  end

  # Private Functions
  defp update_active_mouse(active_mouse, closed_mouse_id, new_mice) do
    if active_mouse == closed_mouse_id do
      case Map.keys(new_mice) do
        [] -> nil
        [first_mouse | _] -> first_mouse
      end
    else
      active_mouse
    end
  end

  defp process_event(mouse_state, event, button, position, modifiers) do
    case event do
      :press -> handle_press_event(mouse_state, button, position, modifiers)
      :release -> handle_release_event(mouse_state, button, position, modifiers)
      :move -> handle_move_event(mouse_state, position, modifiers)
      :drag -> handle_drag_event(mouse_state, position, modifiers)
      _ -> handle_other_event(mouse_state, position, modifiers)
    end
  end

  defp handle_press_event(mouse_state, button, position, modifiers) do
    if Map.has_key?(mouse_state.button_state, button) do
      mouse_state
    else
      update_mouse_state(
        mouse_state,
        position,
        modifiers,
        Map.put(mouse_state.button_state, button, :pressed)
      )
    end
  end

  defp handle_release_event(mouse_state, button, position, modifiers) do
    if Map.has_key?(mouse_state.button_state, button) do
      update_mouse_state(
        mouse_state,
        position,
        modifiers,
        Map.delete(mouse_state.button_state, button)
      )
    else
      mouse_state
    end
  end

  defp handle_move_event(mouse_state, position, modifiers) do
    if position != mouse_state.position do
      update_mouse_state(
        mouse_state,
        position,
        modifiers,
        mouse_state.button_state
      )
    else
      mouse_state
    end
  end

  defp handle_drag_event(mouse_state, position, modifiers) do
    if position != mouse_state.position do
      update_mouse_state(
        mouse_state,
        position,
        modifiers,
        mouse_state.button_state
      )
    else
      mouse_state
    end
  end

  defp handle_other_event(mouse_state, position, modifiers) do
    update_mouse_state(
      mouse_state,
      position,
      modifiers,
      mouse_state.button_state
    )
  end

  defp update_mouse_state(mouse_state, position, modifiers, button_state) do
    %{
      mouse_state
      | position: position,
        button_state: button_state,
        modifiers: modifiers,
        last_update: System.system_time(:millisecond)
    }
  end

  defp default_config do
    %{
      max_mice: 1,
      default_tracking: true,
      default_reporting: true,
      default_sgr_mode: true,
      default_urxvt_mode: false,
      default_pixel_mode: false
    }
  end

  defp default_mouse_config do
    %{
      tracking: :all,
      reporting: true,
      sgr_mode: true,
      urxvt_mode: false,
      pixel_mode: false
    }
  end
end
