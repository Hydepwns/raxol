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

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log
  @type coordinates :: %{x: non_neg_integer(), y: non_neg_integer()}
  @type bounds :: %{
          x: non_neg_integer(),
          y: non_neg_integer(),
          width: non_neg_integer(),
          height: non_neg_integer()
        }
  @type mouse_button :: :left | :right | :middle | :wheel_up | :wheel_down
  @type mouse_event :: %{
          type:
            :click | :press | :release | :move | :hover | :drag | :context_menu,
          x: non_neg_integer(),
          y: non_neg_integer(),
          button: mouse_button() | nil,
          modifiers: map(),
          timestamp: non_neg_integer()
        }

  @type interaction_callbacks :: %{
          optional(:on_click) => function(),
          optional(:on_hover) => function(),
          optional(:on_drag_start) => function(),
          optional(:on_drag) => function(),
          optional(:on_drag_end) => function(),
          optional(:on_double_click) => function(),
          optional(:on_triple_click) => function(),
          optional(:on_context_menu) => function(),
          optional(:on_selection_start) => function(),
          optional(:on_selection_change) => function(),
          optional(:on_selection_end) => function()
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
    :selection_state,
    :click_history,
    :context_menu_state,
    :config
  ]

  @default_config %{
    # milliseconds
    double_click_timeout: 300,
    # milliseconds
    triple_click_timeout: 500,
    # milliseconds
    hover_delay: 100,
    # pixels
    drag_threshold: 3,
    # pixels
    selection_threshold: 1,
    max_click_history: 50,
    # Context menu configuration
    context_menu_button: :right,
    context_menu_delay: 0,
    # Selection configuration
    enable_text_selection: true,
    # :character, :word, :line
    selection_granularity: :character
  }

  # Public API

  # start_link is provided by BaseManager

  @doc """
  Registers a graphics element for mouse interaction.

  ## Parameters

  - `graphics_id` - ID of the graphics element
  - `element_config` - Configuration including bounds, callbacks, etc.

  ## Examples

      MouseInteraction.register_interactive_element(123, %{
        bounds: %{x: 10, y: 5, width: 100, height: 50},
        callbacks: %{
          on_click: fn event -> Log.info("Clicked!") end,
          on_hover: fn event -> Log.info("Hovered!") end
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

  @doc """
  Gets the current selection state.
  """
  @spec get_selection_state() :: map() | nil
  def get_selection_state do
    GenServer.call(__MODULE__, :get_selection_state)
  end

  @doc """
  Clears the current selection.
  """
  @spec clear_selection() :: :ok
  def clear_selection do
    GenServer.call(__MODULE__, :clear_selection)
  end

  @doc """
  Gets the current drag state.
  """
  @spec get_drag_state() :: map() | nil
  def get_drag_state do
    GenServer.call(__MODULE__, :get_drag_state)
  end

  @doc """
  Sets text selection mode for an element.
  """
  @spec set_text_selection_mode(non_neg_integer(), boolean()) ::
          :ok | {:error, term()}
  def set_text_selection_mode(graphics_id, enabled) do
    GenServer.call(__MODULE__, {:set_text_selection, graphics_id, enabled})
  end

  @doc """
  Updates configuration options for the mouse interaction manager.
  """
  @spec update_config(map()) :: :ok
  def update_config(config_updates) do
    GenServer.call(__MODULE__, {:update_config, config_updates})
  end

  # GenServer Implementation

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    config = Map.merge(@default_config, Map.new(opts))

    initial_state = %__MODULE__{
      interactive_elements: %{},
      hover_state: nil,
      drag_state: nil,
      selection_state: nil,
      click_history: [],
      context_menu_state: nil,
      config: config
    }

    {:ok, initial_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
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

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:unregister_element, graphics_id}, _from, state) do
    elements = Map.delete(state.interactive_elements, graphics_id)
    {:reply, :ok, %{state | interactive_elements: elements}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:handle_mouse_event, mouse_event}, _from, state) do
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

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:update_bounds, graphics_id, new_bounds},
        _from,
        state
      ) do
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

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:set_enabled, graphics_id, enabled}, _from, state) do
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

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_elements, _from, state) do
    elements = Map.values(state.interactive_elements)
    {:reply, elements, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_selection_state, _from, state) do
    {:reply, state.selection_state, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:clear_selection, _from, state) do
    {:reply, :ok, %{state | selection_state: nil}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_drag_state, _from, state) do
    {:reply, state.drag_state, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:set_text_selection, graphics_id, enabled},
        _from,
        state
      ) do
    case Map.get(state.interactive_elements, graphics_id) do
      nil ->
        {:reply, {:error, :element_not_found}, state}

      element ->
        metadata = Map.put(element.metadata, :text_selection_enabled, enabled)
        updated_element = %{element | metadata: metadata}

        elements =
          Map.put(state.interactive_elements, graphics_id, updated_element)

        {:reply, :ok, %{state | interactive_elements: elements}}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:update_config, config_updates}, _from, state) do
    new_config = Map.merge(state.config, config_updates)
    {:reply, :ok, %{state | config: new_config}}
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

      {:press, [element | _]} when event.button == :left ->
        new_state = handle_press_event(event, element, state)
        {{:handled, element.graphics_id}, new_state}

      {:press, [element | _]} when event.button == :right ->
        new_state = handle_context_menu_event(event, element, state)
        {{:handled, element.graphics_id}, new_state}

      {:release, _} ->
        new_state = handle_release_event(event, state)
        {:not_handled, new_state}

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

      {:drag, hit_elements} ->
        new_state = handle_drag_event(event, hit_elements, state)

        result =
          case hit_elements do
            [element | _] -> {:handled, element.graphics_id}
            [] -> :not_handled
          end

        {result, new_state}

      _ ->
        {:not_handled, state}
    end
  end

  defp handle_click_event(event, element, state) do
    # Check for multi-click
    {click_type, updated_history} =
      check_multi_click(event, state.click_history, state.config)

    # Execute callback
    case Map.get(element.callbacks, :on_click) do
      callback when is_function(callback, 1) ->
        try do
          callback.(Map.put(event, :element, element))
        rescue
          error -> Log.warning("Click callback error: #{inspect(error)}")
        end

      _ ->
        :ok
    end

    # Handle multi-click callbacks
    case {click_type, element.callbacks} do
      {:double, callbacks} when is_map_key(callbacks, :on_double_click) ->
        callback = callbacks.on_double_click

        try do
          callback.(Map.put(event, :element, element))
        rescue
          error ->
            Log.warning("Double-click callback error: #{inspect(error)}")
        end

      {:triple, callbacks} when is_map_key(callbacks, :on_triple_click) ->
        callback = callbacks.on_triple_click

        try do
          callback.(Map.put(event, :element, element))
        rescue
          error ->
            Log.warning("Triple-click callback error: #{inspect(error)}")
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
              error ->
                Log.warning("Hover callback error: #{inspect(error)}")
            end

          _ ->
            :ok
        end

        %{state | hover_state: element}
    end
  end

  defp handle_drag_event(event, hit_elements, state) do
    case state.drag_state do
      nil ->
        # Start drag operation
        element = List.first(hit_elements)

        new_drag_state = %{
          start_x: event.x,
          start_y: event.y,
          current_x: event.x,
          current_y: event.y,
          started_at: event.timestamp,
          element: element
        }

        # Trigger drag start callback
        if element && Map.has_key?(element.callbacks, :on_drag_start) do
          try do
            element.callbacks.on_drag_start.(Map.put(event, :element, element))
          rescue
            error ->
              Log.warning("Drag start callback error: #{inspect(error)}")
          end
        end

        %{state | drag_state: new_drag_state}

      drag_state ->
        # Continue drag operation
        updated_drag = %{drag_state | current_x: event.x, current_y: event.y}

        # Trigger drag callback
        if drag_state.element &&
             Map.has_key?(drag_state.element.callbacks, :on_drag) do
          try do
            drag_info = %{
              start: {drag_state.start_x, drag_state.start_y},
              current: {event.x, event.y},
              distance:
                calculate_distance(
                  drag_state.start_x,
                  drag_state.start_y,
                  event.x,
                  event.y
                )
            }

            drag_state.element.callbacks.on_drag.(
              Map.merge(event, %{element: drag_state.element, drag: drag_info})
            )
          rescue
            error ->
              Log.warning("Drag callback error: #{inspect(error)}")
          end
        end

        %{state | drag_state: updated_drag}
    end
  end

  defp handle_press_event(event, element, state) do
    # Start potential drag or selection
    if element.metadata[:text_selection_enabled] &&
         state.config.enable_text_selection do
      new_selection_state = %{
        start_x: event.x,
        start_y: event.y,
        current_x: event.x,
        current_y: event.y,
        element: element,
        type: determine_selection_type(event, state.config)
      }

      # Trigger selection start callback
      if Map.has_key?(element.callbacks, :on_selection_start) do
        try do
          element.callbacks.on_selection_start.(
            Map.put(event, :element, element)
          )
        rescue
          error ->
            Log.warning("Selection start callback error: #{inspect(error)}")
        end
      end

      %{state | selection_state: new_selection_state}
    else
      state
    end
  end

  defp handle_release_event(event, state) do
    new_state = state

    # Handle drag end
    new_state =
      case new_state.drag_state do
        nil ->
          new_state

        drag_state ->
          if drag_state.element &&
               Map.has_key?(drag_state.element.callbacks, :on_drag_end) do
            try do
              drag_info = %{
                start: {drag_state.start_x, drag_state.start_y},
                end: {event.x, event.y},
                distance:
                  calculate_distance(
                    drag_state.start_x,
                    drag_state.start_y,
                    event.x,
                    event.y
                  )
              }

              drag_state.element.callbacks.on_drag_end.(
                Map.merge(event, %{element: drag_state.element, drag: drag_info})
              )
            rescue
              error ->
                Log.warning("Drag end callback error: #{inspect(error)}")
            end
          end

          %{new_state | drag_state: nil}
      end

    # Handle selection end
    new_state =
      case new_state.selection_state do
        nil ->
          new_state

        selection_state ->
          if Map.has_key?(selection_state.element.callbacks, :on_selection_end) do
            try do
              selection_info = %{
                start: {selection_state.start_x, selection_state.start_y},
                end: {event.x, event.y},
                type: selection_state.type
              }

              selection_state.element.callbacks.on_selection_end.(
                Map.merge(event, %{
                  element: selection_state.element,
                  selection: selection_info
                })
              )
            rescue
              error ->
                Log.warning("Selection end callback error: #{inspect(error)}")
            end
          end

          %{new_state | selection_state: nil}
      end

    new_state
  end

  defp handle_context_menu_event(event, element, state) do
    # Show context menu
    context_menu_state = %{
      x: event.x,
      y: event.y,
      element: element,
      timestamp: event.timestamp
    }

    # Trigger context menu callback
    if Map.has_key?(element.callbacks, :on_context_menu) do
      try do
        element.callbacks.on_context_menu.(Map.put(event, :element, element))
      rescue
        error ->
          Log.warning("Context menu callback error: #{inspect(error)}")
      end
    end

    %{state | context_menu_state: context_menu_state}
  end

  # Updated handle_move_event to handle selection changes
  defp handle_move_event(event, hit_elements, state) do
    current_element = List.first(hit_elements)

    # Handle hover state
    new_hover_state =
      case current_element do
        nil -> nil
        element -> element
      end

    # Handle selection changes
    new_state =
      case state.selection_state do
        nil ->
          state

        selection_state ->
          updated_selection = %{
            selection_state
            | current_x: event.x,
              current_y: event.y
          }

          # Trigger selection change callback
          if Map.has_key?(
               selection_state.element.callbacks,
               :on_selection_change
             ) do
            try do
              selection_info = %{
                start: {selection_state.start_x, selection_state.start_y},
                current: {event.x, event.y},
                type: selection_state.type
              }

              selection_state.element.callbacks.on_selection_change.(
                Map.merge(event, %{
                  element: selection_state.element,
                  selection: selection_info
                })
              )
            rescue
              error ->
                Log.warning(
                  "Selection change callback error: #{inspect(error)}"
                )
            end
          end

          %{state | selection_state: updated_selection}
      end

    %{new_state | hover_state: new_hover_state}
  end

  defp determine_selection_type(_event, config) do
    case config.selection_granularity do
      :character -> :character
      :word -> :word
      :line -> :line
      _ -> :character
    end
  end

  defp calculate_distance(x1, y1, x2, y2) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2))
  end

  defp check_multi_click(event, history, config) do
    # Add current click to history
    new_history = [event | Enum.take(history, config.max_click_history - 1)]

    # Check for multi-click patterns
    click_type =
      case new_history do
        [current, second, third | _] ->
          # Check for triple click
          triple_time_diff = current.timestamp - third.timestamp

          second_pos_diff =
            abs(current.x - second.x) + abs(current.y - second.y)

          third_pos_diff = abs(current.x - third.x) + abs(current.y - third.y)

          if triple_time_diff <= config.triple_click_timeout and
               second_pos_diff <= config.drag_threshold and
               third_pos_diff <= config.drag_threshold do
            :triple
          else
            check_double_click_in_history(current, second, config)
          end

        [current, second | _] ->
          check_double_click_in_history(current, second, config)

        _ ->
          :single
      end

    {click_type, new_history}
  end

  defp check_double_click_in_history(current, previous, config) do
    time_diff = current.timestamp - previous.timestamp
    pos_diff = abs(current.x - previous.x) + abs(current.y - previous.y)

    if time_diff <= config.double_click_timeout and
         pos_diff <= config.drag_threshold do
      :double
    else
      :single
    end
  end
end
