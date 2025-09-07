defmodule Raxol.Animation.StateServer do
  @moduledoc """
  GenServer implementation for animation state management in Raxol.

  This server provides a pure functional approach to animation state management,
  eliminating Process dictionary usage and implementing proper OTP patterns.

  ## Features
  - Centralized animation settings management
  - Animation definition storage and retrieval
  - Active animation instance tracking
  - Supervised state management with fault tolerance
  - Concurrent-safe operations

  ## State Structure
  The server maintains state with the following structure:
  ```elixir
  %{
    settings: map(),
    animations: %{animation_name => animation_definition},
    active_animations: %{element_id => %{animation_name => instance}}
  }
  ```

  ## Performance Considerations
  This implementation uses ETS for read-heavy operations when performance
  is critical, while maintaining GenServer for write operations and
  state consistency.
  """

  use GenServer
  require Logger

  @default_state %{
    settings: %{},
    animations: %{},
    active_animations: %{}
  }

  # Client API

  @doc """
  Starts the Animation StateServer with optional initial settings.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    settings = Keyword.get(opts, :settings, %{})
    GenServer.start_link(__MODULE__, settings, name: name)
  end

  @doc """
  Initializes the animation state storage with the given settings.
  """
  def init_state(server \\ __MODULE__, settings) do
    GenServer.call(server, {:init_state, settings})
  end

  @doc """
  Retrieves the animation framework settings.
  """
  def get_settings(server \\ __MODULE__) do
    GenServer.call(server, :get_settings)
  end

  @doc """
  Updates the animation framework settings.
  """
  def update_settings(server \\ __MODULE__, settings) do
    GenServer.call(server, {:update_settings, settings})
  end

  @doc """
  Stores an animation definition.
  """
  def put_animation(server \\ __MODULE__, animation) do
    GenServer.call(server, {:put_animation, animation})
  end

  @doc """
  Retrieves an animation definition by name.
  """
  def get_animation(server \\ __MODULE__, animation_name) do
    GenServer.call(server, {:get_animation, animation_name})
  end

  @doc """
  Retrieves all animation definitions.
  """
  def get_all_animations(server \\ __MODULE__) do
    GenServer.call(server, :get_all_animations)
  end

  @doc """
  Stores an active animation instance for a given element.
  """
  def put_active_animation(
        server \\ __MODULE__,
        element_id,
        animation_name,
        instance
      ) do
    GenServer.call(
      server,
      {:put_active_animation, element_id, animation_name, instance}
    )
  end

  @doc """
  Retrieves all active animations.
  Returns a map of `{element_id, %{animation_name => instance}}`.
  """
  def get_active_animations(server \\ __MODULE__) do
    GenServer.call(server, :get_active_animations)
  end

  @doc """
  Retrieves a specific active animation instance for a given element and animation name.
  """
  def get_active_animation(server \\ __MODULE__, element_id, animation_name) do
    GenServer.call(server, {:get_active_animation, element_id, animation_name})
  end

  @doc """
  Removes a completed or stopped animation instance for a specific element.
  """
  def remove_active_animation(server \\ __MODULE__, element_id, animation_name) do
    GenServer.call(
      server,
      {:remove_active_animation, element_id, animation_name}
    )
  end

  @doc """
  Removes all active animations for a specific element.
  """
  def remove_element_animations(server \\ __MODULE__, element_id) do
    GenServer.call(server, {:remove_element_animations, element_id})
  end

  @doc """
  Clears all animation state (used primarily for testing or reset).
  """
  def clear_all(server \\ __MODULE__) do
    GenServer.call(server, :clear_all)
  end

  @doc """
  Gets the current state (for debugging/testing).
  """
  def get_state(server \\ __MODULE__) do
    GenServer.call(server, :get_state)
  end

  @doc """
  Batch updates multiple active animations at once for performance.
  """
  def batch_update_active_animations(server \\ __MODULE__, updates) do
    GenServer.call(server, {:batch_update_active_animations, updates})
  end

  # GenServer Callbacks

  @impl GenServer
  def init(settings) do
    initial_state = %{
      settings: settings,
      animations: %{},
      active_animations: %{}
    }

    {:ok, initial_state}
  end

  @impl GenServer
  def handle_call({:init_state, settings}, _from, state) do
    new_state = %{
      state
      | settings: settings,
        animations: %{},
        active_animations: %{}
    }

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_settings, _from, state) do
    {:reply, state.settings, state}
  end

  @impl GenServer
  def handle_call({:update_settings, settings}, _from, state) do
    new_state = %{state | settings: settings}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:put_animation, animation}, _from, state) do
    updated_animations = Map.put(state.animations, animation.name, animation)
    new_state = %{state | animations: updated_animations}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:get_animation, animation_name}, _from, state) do
    animation = Map.get(state.animations, animation_name)
    {:reply, animation, state}
  end

  @impl GenServer
  def handle_call(:get_all_animations, _from, state) do
    {:reply, state.animations, state}
  end

  @impl GenServer
  def handle_call(
        {:put_active_animation, element_id, animation_name, instance},
        _from,
        state
      ) do
    element_animations = Map.get(state.active_animations, element_id, %{})

    updated_element_animations =
      Map.put(element_animations, animation_name, instance)

    updated_active_animations =
      Map.put(state.active_animations, element_id, updated_element_animations)

    new_state = %{state | active_animations: updated_active_animations}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_active_animations, _from, state) do
    {:reply, state.active_animations, state}
  end

  @impl GenServer
  def handle_call(
        {:get_active_animation, element_id, animation_name},
        _from,
        state
      ) do
    animation =
      state.active_animations
      |> Map.get(element_id, %{})
      |> Map.get(animation_name)

    {:reply, animation, state}
  end

  @impl GenServer
  def handle_call(
        {:remove_active_animation, element_id, animation_name},
        _from,
        state
      ) do
    new_state = do_remove_active_animation(state, element_id, animation_name)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:remove_element_animations, element_id}, _from, state) do
    updated_active_animations = Map.delete(state.active_animations, element_id)
    new_state = %{state | active_animations: updated_active_animations}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:clear_all, _from, _state) do
    new_state = @default_state
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_call({:batch_update_active_animations, updates}, _from, state) do
    new_state = apply_batch_updates(state, updates)
    {:reply, :ok, new_state}
  end

  # Private Helper Functions

  defp do_remove_active_animation(state, element_id, animation_name) do
    element_animations = Map.get(state.active_animations, element_id, %{})
    updated_element_animations = Map.delete(element_animations, animation_name)

    updated_active_animations =
      case map_size(updated_element_animations) do
        0 ->
          Map.delete(state.active_animations, element_id)

        _ ->
          Map.put(
            state.active_animations,
            element_id,
            updated_element_animations
          )
      end

    %{state | active_animations: updated_active_animations}
  end

  defp apply_batch_updates(state, updates) do
    updated_active_animations =
      Enum.reduce(updates, state.active_animations, fn update, acc ->
        case update do
          {:put, element_id, animation_name, instance} ->
            element_animations = Map.get(acc, element_id, %{})

            updated_element_animations =
              Map.put(element_animations, animation_name, instance)

            Map.put(acc, element_id, updated_element_animations)

          {:remove, element_id, animation_name} ->
            element_animations = Map.get(acc, element_id, %{})

            updated_element_animations =
              Map.delete(element_animations, animation_name)

            case map_size(updated_element_animations) do
              0 -> Map.delete(acc, element_id)
              _ -> Map.put(acc, element_id, updated_element_animations)
            end

          _ ->
            Logger.warning("Unknown batch update operation: #{inspect(update)}")
            acc
        end
      end)

    %{state | active_animations: updated_active_animations}
  end
end
