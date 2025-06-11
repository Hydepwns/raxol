defmodule Raxol.Terminal.Graphics.UnifiedGraphics do
  @moduledoc """
  Provides unified graphics functionality for the terminal emulator.
  This module handles graphics rendering, image display, and graphics state management.
  """

  use GenServer
  require Logger

  alias Raxol.Terminal.Integration.State

  # Types
  @type graphics_id :: non_neg_integer()
  @type graphics_state :: :active | :inactive | :hidden
  @type graphics_config :: %{
    optional(:width) => non_neg_integer(),
    optional(:height) => non_neg_integer(),
    optional(:format) => :rgb | :rgba | :grayscale,
    optional(:compression) => :none | :zlib | :lz4,
    optional(:quality) => 0..100
  }

  # Client API
  @doc """
  Starts the graphics manager with the given options.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a new graphics context with the given configuration.
  """
  @spec create_graphics(map()) :: {:ok, graphics_id()} | {:error, term()}
  def create_graphics(config \\ %{}) do
    GenServer.call(__MODULE__, {:create_graphics, config})
  end

  @doc """
  Gets the list of all graphics contexts.
  """
  @spec get_graphics() :: list(graphics_id())
  def get_graphics do
    GenServer.call(__MODULE__, :get_graphics)
  end

  @doc """
  Gets the active graphics context ID.
  """
  @spec get_active_graphics() :: {:ok, graphics_id()} | {:error, :no_active_graphics}
  def get_active_graphics do
    GenServer.call(__MODULE__, :get_active_graphics)
  end

  @doc """
  Sets the active graphics context.
  """
  @spec set_active_graphics(graphics_id()) :: :ok | {:error, term()}
  def set_active_graphics(graphics_id) do
    GenServer.call(__MODULE__, {:set_active_graphics, graphics_id})
  end

  @doc """
  Gets the state of a specific graphics context.
  """
  @spec get_graphics_state(graphics_id()) :: {:ok, map()} | {:error, term()}
  def get_graphics_state(graphics_id) do
    GenServer.call(__MODULE__, {:get_graphics_state, graphics_id})
  end

  @doc """
  Updates the configuration of a specific graphics context.
  """
  @spec update_graphics_config(graphics_id(), graphics_config()) :: :ok | {:error, term()}
  def update_graphics_config(graphics_id, config) do
    GenServer.call(__MODULE__, {:update_graphics_config, graphics_id, config})
  end

  @doc """
  Renders graphics data to the specified context.
  """
  @spec render_graphics(graphics_id(), binary()) :: :ok | {:error, term()}
  def render_graphics(graphics_id, data) do
    GenServer.call(__MODULE__, {:render_graphics, graphics_id, data})
  end

  @doc """
  Clears the graphics context.
  """
  @spec clear_graphics(graphics_id()) :: :ok | {:error, term()}
  def clear_graphics(graphics_id) do
    GenServer.call(__MODULE__, {:clear_graphics, graphics_id})
  end

  @doc """
  Closes a graphics context.
  """
  @spec close_graphics(graphics_id()) :: :ok | {:error, term()}
  def close_graphics(graphics_id) do
    GenServer.call(__MODULE__, {:close_graphics, graphics_id})
  end

  @doc """
  Updates the graphics manager configuration.
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
  @impl true
  def init(opts) do
    state = %{
      graphics: %{},
      active_graphics: nil,
      next_id: 1,
      config: Map.merge(default_config(), opts)
    }
    {:ok, state}
  end

  @impl true
  def handle_call({:create_graphics, config}, _from, state) do
    graphics_id = state.next_id
    graphics_state = %{
      id: graphics_id,
      config: Map.merge(default_graphics_config(), config),
      buffer: <<>>,
      created_at: System.system_time(:millisecond)
    }

    new_state = %{state |
      graphics: Map.put(state.graphics, graphics_id, graphics_state),
      next_id: graphics_id + 1
    }

    # If this is the first graphics context, make it active
    new_state = if state.active_graphics == nil do
      %{new_state | active_graphics: graphics_id}
    else
      new_state
    end

    {:reply, {:ok, graphics_id}, new_state}
  end

  @impl true
  def handle_call(:get_graphics, _from, state) do
    {:reply, Map.keys(state.graphics), state}
  end

  @impl true
  def handle_call(:get_active_graphics, _from, state) do
    case state.active_graphics do
      nil -> {:reply, {:error, :no_active_graphics}, state}
      graphics_id -> {:reply, {:ok, graphics_id}, state}
    end
  end

  @impl true
  def handle_call({:set_active_graphics, graphics_id}, _from, state) do
    case Map.get(state.graphics, graphics_id) do
      nil ->
        {:reply, {:error, :graphics_not_found}, state}
      _graphics ->
        new_state = %{state | active_graphics: graphics_id}
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:get_graphics_state, graphics_id}, _from, state) do
    case Map.get(state.graphics, graphics_id) do
      nil -> {:reply, {:error, :graphics_not_found}, state}
      graphics_state -> {:reply, {:ok, graphics_state}, state}
    end
  end

  @impl true
  def handle_call({:update_graphics_config, graphics_id, config}, _from, state) do
    case Map.get(state.graphics, graphics_id) do
      nil ->
        {:reply, {:error, :graphics_not_found}, state}
      graphics_state ->
        new_config = Map.merge(graphics_state.config, config)
        new_graphics_state = %{graphics_state | config: new_config}
        new_state = %{state | graphics: Map.put(state.graphics, graphics_id, new_graphics_state)}
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:render_graphics, graphics_id, data}, _from, state) do
    case Map.get(state.graphics, graphics_id) do
      nil ->
        {:reply, {:error, :graphics_not_found}, state}
      graphics_state ->
        # Only update if data has changed
        if data != graphics_state.buffer do
          # Use double buffering for smooth rendering
          new_buffer = if graphics_state.back_buffer == nil do
            data
          else
            graphics_state.back_buffer
          end

          new_graphics_state = %{graphics_state |
            buffer: data,
            back_buffer: new_buffer,
            last_render: System.system_time(:millisecond)
          }

          new_state = %{state |
            graphics: Map.put(state.graphics, graphics_id, new_graphics_state)
          }

          {:reply, :ok, new_state}
        else
          {:reply, :ok, state}
        end
    end
  end

  @impl true
  def handle_call({:swap_buffers, graphics_id}, _from, state) do
    case Map.get(state.graphics, graphics_id) do
      nil ->
        {:reply, {:error, :graphics_not_found}, state}
      graphics_state ->
        # Swap front and back buffers
        new_graphics_state = %{graphics_state |
          buffer: graphics_state.back_buffer,
          back_buffer: graphics_state.buffer
        }

        new_state = %{state |
          graphics: Map.put(state.graphics, graphics_id, new_graphics_state)
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:clear_graphics, graphics_id}, _from, state) do
    case Map.get(state.graphics, graphics_id) do
      nil ->
        {:reply, {:error, :graphics_not_found}, state}
      graphics_state ->
        new_graphics_state = %{graphics_state | buffer: <<>>}
        new_state = %{state | graphics: Map.put(state.graphics, graphics_id, new_graphics_state)}
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:close_graphics, graphics_id}, _from, state) do
    case Map.get(state.graphics, graphics_id) do
      nil ->
        {:reply, {:error, :graphics_not_found}, state}
      _graphics ->
        # Remove graphics context
        new_graphics = Map.delete(state.graphics, graphics_id)

        # Update active graphics if needed
        new_active_graphics = if state.active_graphics == graphics_id do
          case Map.keys(new_graphics) do
            [] -> nil
            [first_graphics | _] -> first_graphics
          end
        else
          state.active_graphics
        end

        new_state = %{state |
          graphics: new_graphics,
          active_graphics: new_active_graphics
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:update_config, config}, _from, state) do
    new_config = Map.merge(state.config, config)
    new_state = %{state | config: new_config}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:cleanup, _from, state) do
    # Clean up all graphics contexts
    {:reply, :ok, %{state | graphics: %{}, active_graphics: nil}}
  end

  # Private Functions
  defp default_config do
    %{
      max_graphics: 10,
      default_width: 800,
      default_height: 600,
      default_format: :rgba,
      default_compression: :none,
      default_quality: 90
    }
  end

  defp default_graphics_config do
    %{
      width: 800,
      height: 600,
      format: :rgba,
      compression: :none,
      quality: 90
    }
  end
end
