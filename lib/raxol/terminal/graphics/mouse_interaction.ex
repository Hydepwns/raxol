defmodule Raxol.Terminal.Graphics.MouseInteraction do
  @moduledoc """
  Provides mouse interaction capabilities for terminal graphics elements.

  This module enables:
  - Click detection on graphics elements
  - Hover events for graphics
  - Drag and drop support for graphics
  - Mouse gesture recognition
  - Hit testing for complex graphics layouts

  ## Usage

      # Register a graphics element for mouse interaction
      MouseInteraction.register_interactive_element(graphics_id, %{
        bounds: %{x: 10, y: 5, width: 100, height: 50},
        callbacks: %{
          on_click: &handle_click/1,
          on_hover: &handle_hover/1
        }
      })

      # Process mouse events
      MouseInteraction.handle_mouse_event(%{
        type: :click,
        x: 50, y: 20,
        button: :left
      })
  """

  use GenServer
  require Logger

  @type coordinates :: %{x: non_neg_integer(), y: non_neg_integer()}
  @type bounds :: %{
          x: non_neg_integer(),
          y: non_neg_integer(),
          width: non_neg_integer(),
          height: non_neg_integer()
        }
  @type mouse_button :: :left | :right | :middle | :wheel_up | :wheel_down
  @type mouse_event :: %{
          type: :click | :press | :release | :move | :hover | :drag,
          x: non_neg_integer(),
          y: non_neg_integer(),
          button: mouse_button() | nil,
          timestamp: non_neg_integer()
        }

  @type interaction_callbacks :: %{
          optional(:on_click) => function(),
          optional(:on_hover) => function(),
          optional(:on_drag_start) => function(),
          optional(:on_drag) => function(),
          optional(:on_drag_end) => function(),
          optional(:on_double_click) => function()
        }

  @type interactive_element :: %{
          graphics_id: non_neg_integer(),
          bounds: bounds(),
          callbacks: interaction_callbacks(),
          z_index: integer(),
          enabled: boolean(),
          metadata: map()
        }

  defstruct [
    :interactive_elements,
    :hover_state,
    :drag_state,
    :click_history,
    :config
  ]

  @default_config %{
    # milliseconds
    double_click_timeout: 300,
    # milliseconds
    hover_delay: 100,
    # pixels
    drag_threshold: 3,
    max_click_history: 50
  }

  # Public API

  @doc """
  Starts the mouse interaction manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a graphics element for mouse interaction.

  ## Parameters

  - `graphics_id` - ID of the graphics element
  - `element_config` - Configuration including bounds, callbacks, etc.

  ## Examples

      MouseInteraction.register_interactive_element(123, %{
        bounds: %{x: 10, y: 5, width: 100, height: 50},
        callbacks: %{
          on_click: fn event -> IO.puts("Clicked!") end,
          on_hover: fn event -> IO.puts("Hovered!") end
        },
        z_index: 1,
        metadata: %{type: :button, id: "submit_btn"}
      })
  """
  @spec register_interactive_element(non_neg_integer(), map()) ::
          :ok | {:error, term()}
  def register_interactive_element(graphics_id, element_config) do
    GenServer.call(__MODULE__, {:register_element, graphics_id, element_config})
  end

  @doc """
  Unregisters a graphics element from mouse interaction.
  """
  @spec unregister_interactive_element(non_neg_integer()) :: :ok
  def unregister_interactive_element(graphics_id) do
    GenServer.call(__MODULE__, {:unregister_element, graphics_id})
  end

  @doc """
  Processes a mouse event and triggers appropriate callbacks.

  ## Parameters

  - `mouse_event` - Mouse event data including type, coordinates, button

  ## Returns

  - `{:handled, element_id}` - Event was handled by an interactive element
  - `:not_handled` - No interactive element handled the event
  """
  @spec handle_mouse_event(mouse_event()) ::
          {:handled, non_neg_integer()} | :not_handled
  def handle_mouse_event(mouse_event) do
    GenServer.call(__MODULE__, {:handle_mouse_event, mouse_event})
  end

  @doc """
  Updates the bounds of an interactive element.
  """
  @spec update_element_bounds(non_neg_integer(), bounds()) ::
          :ok | {:error, term()}
  def update_element_bounds(graphics_id, new_bounds) do
    GenServer.call(__MODULE__, {:update_bounds, graphics_id, new_bounds})
  end

  @doc """
  Enables or disables mouse interaction for an element.
  """
  @spec set_element_enabled(non_neg_integer(), boolean()) ::
          :ok | {:error, term()}
  def set_element_enabled(graphics_id, enabled) do
    GenServer.call(__MODULE__, {:set_enabled, graphics_id, enabled})
  end

  @doc """
  Gets all currently interactive elements.
  """
  @spec get_interactive_elements() :: [interactive_element()]
  def get_interactive_elements do
    GenServer.call(__MODULE__, :get_elements)
  end

  # GenServer Implementation

  @impl true
  def init(opts) do
    config = Map.merge(@default_config, Map.new(opts))

    initial_state = %__MODULE__{
      interactive_elements: %{},
      hover_state: nil,
      drag_state: nil,
      click_history: [],
      config: config
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_call(
        {:register_element, graphics_id, element_config},
        _from,
        state
      ) do
    case validate_element_config(element_config) do
      :ok ->
        element = build_interactive_element(graphics_id, element_config)
        elements = Map.put(state.interactive_elements, graphics_id, element)
        {:reply, :ok, %{state | interactive_elements: elements}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:unregister_element, graphics_id}, _from, state) do
    elements = Map.delete(state.interactive_elements, graphics_id)
    {:reply, :ok, %{state | interactive_elements: elements}}
  end

  @impl true
  def handle_call({:handle_mouse_event, mouse_event}, _from, state) do
    # Add timestamp if not present
    event =
      Map.put_new(mouse_event, :timestamp, System.system_time(:millisecond))

    # Find elements under the mouse cursor
    hit_elements =
      find_elements_at_position(state.interactive_elements, {event.x, event.y})

    # Process the event
    {result, new_state} = process_mouse_event(event, hit_elements, state)

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:update_bounds, graphics_id, new_bounds}, _from, state) do
    case Map.get(state.interactive_elements, graphics_id) do
      nil ->
        {:reply, {:error, :element_not_found}, state}

      element ->
        updated_element = %{element | bounds: new_bounds}

        elements =
          Map.put(state.interactive_elements, graphics_id, updated_element)

        {:reply, :ok, %{state | interactive_elements: elements}}
    end
  end

  @impl true
  def handle_call({:set_enabled, graphics_id, enabled}, _from, state) do
    case Map.get(state.interactive_elements, graphics_id) do
      nil ->
        {:reply, {:error, :element_not_found}, state}

      element ->
        updated_element = %{element | enabled: enabled}

        elements =
          Map.put(state.interactive_elements, graphics_id, updated_element)

        {:reply, :ok, %{state | interactive_elements: elements}}
    end
  end

  @impl true
  def handle_call(:get_elements, _from, state) do
    elements = Map.values(state.interactive_elements)
    {:reply, elements, state}
  end

  # Private Functions

  defp validate_element_config(config) do
    case Map.get(config, :bounds) do
      %{x: _, y: _, width: _, height: _} -> :ok
      _ -> {:error, :invalid_bounds}
    end
  end

  defp build_interactive_element(graphics_id, config) do
    %{
      graphics_id: graphics_id,
      bounds: Map.get(config, :bounds),
      callbacks: Map.get(config, :callbacks, %{}),
      z_index: Map.get(config, :z_index, 0),
      enabled: Map.get(config, :enabled, true),
      metadata: Map.get(config, :metadata, %{})
    }
  end

  defp find_elements_at_position(elements, {x, y}) do
    elements
    |> Map.values()
    |> Enum.filter(fn element ->
      element.enabled and point_in_bounds?({x, y}, element.bounds)
    end)
    # Higher z-index first
    |> Enum.sort_by(& &1.z_index, :desc)
  end

  defp point_in_bounds?({x, y}, bounds) do
    x >= bounds.x and x < bounds.x + bounds.width and
      y >= bounds.y and y < bounds.y + bounds.height
  end

  defp process_mouse_event(event, hit_elements, state) do
    case {event.type, hit_elements} do
      {:click, [element | _]} ->
        new_state = handle_click_event(event, element, state)
        {{:handled, element.graphics_id}, new_state}

      {:hover, [element | _]} ->
        new_state = handle_hover_event(event, element, state)
        {{:handled, element.graphics_id}, new_state}

      {:move, hit_elements} ->
        new_state = handle_move_event(event, hit_elements, state)

        result =
          case hit_elements do
            [element | _] -> {:handled, element.graphics_id}
            [] -> :not_handled
          end

        {result, new_state}

      {:drag, _} ->
        new_state = handle_drag_event(event, state)
        {:not_handled, new_state}

      _ ->
        {:not_handled, state}
    end
  end

  defp handle_click_event(event, element, state) do
    # Check for double-click
    {is_double_click, updated_history} =
      check_double_click(event, state.click_history, state.config)

    # Execute callback
    case Map.get(element.callbacks, :on_click) do
      callback when is_function(callback, 1) ->
        try do
          callback.(Map.put(event, :element, element))
        rescue
          error -> Logger.warning("Click callback error: #{inspect(error)}")
        end

      _ ->
        :ok
    end

    # Handle double-click callback
    case {is_double_click, Map.get(element.callbacks, :on_double_click)} do
      {true, callback} when is_function(callback, 1) ->
        try do
          callback.(Map.put(event, :element, element))
        rescue
          error ->
            Logger.warning("Double-click callback error: #{inspect(error)}")
        end

      _ ->
        :ok
    end

    %{state | click_history: updated_history}
  end

  defp handle_hover_event(event, element, state) do
    # Only trigger if not already hovering this element
    case state.hover_state do
      ^element ->
        state

      _ ->
        # Execute hover callback
        case Map.get(element.callbacks, :on_hover) do
          callback when is_function(callback, 1) ->
            try do
              callback.(Map.put(event, :element, element))
            rescue
              error -> Logger.warning("Hover callback error: #{inspect(error)}")
            end

          _ ->
            :ok
        end

        %{state | hover_state: element}
    end
  end

  defp handle_move_event(_event, hit_elements, state) do
    current_element = List.first(hit_elements)

    # Clear hover state if no longer hovering any element
    new_hover_state =
      case current_element do
        nil -> nil
        element -> element
      end

    %{state | hover_state: new_hover_state}
  end

  defp handle_drag_event(event, state) do
    case state.drag_state do
      nil ->
        # Start drag operation
        %{
          state
          | drag_state: %{
              start_x: event.x,
              start_y: event.y,
              current_x: event.x,
              current_y: event.y,
              started_at: event.timestamp
            }
        }

      drag_state ->
        # Continue drag operation
        updated_drag = %{drag_state | current_x: event.x, current_y: event.y}
        %{state | drag_state: updated_drag}
    end
  end

  defp check_double_click(event, history, config) do
    # Add current click to history
    new_history = [event | Enum.take(history, config.max_click_history - 1)]

    # Check if this is a double-click
    is_double =
      case new_history do
        [current, previous | _] ->
          time_diff = current.timestamp - previous.timestamp
          pos_diff = abs(current.x - previous.x) + abs(current.y - previous.y)

          time_diff <= config.double_click_timeout and
            pos_diff <= config.drag_threshold

        _ ->
          false
      end

    {is_double, new_history}
  end
end
