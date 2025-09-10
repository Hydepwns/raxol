defmodule Raxol.UI.Interactions.DragDrop do
  @moduledoc """
  Universal drag and drop system for all Raxol UI components.

  This module provides:
  - Universal drag and drop for any component
  - Visual drag feedback and ghost images
  - Drop zones with validation and highlighting
  - Drag constraints (horizontal, vertical, bounds)
  - Multi-item drag support
  - Drag and drop with custom data transfer
  - Accessibility support for keyboard-based drag/drop
  """

  alias Raxol.Animation.Framework
  alias Raxol.Core.Accessibility

  @type drag_state :: %{
          active: boolean(),
          dragging_element: term() | nil,
          drag_data: map(),
          start_position: %{x: number(), y: number()} | nil,
          current_position: %{x: number(), y: number()} | nil,
          drag_offset: %{x: number(), y: number()},
          constraints: map(),
          visual_feedback: map(),
          drop_zones: list(),
          valid_drop_target: term() | nil
        }

  @type drag_options :: %{
          optional(:draggable) => boolean(),
          optional(:drag_data) => map(),
          optional(:constraints) => %{
            optional(:horizontal) => boolean(),
            optional(:vertical) => boolean(),
            optional(:bounds) => %{
              x: number(),
              y: number(),
              width: number(),
              height: number()
            }
          },
          optional(:visual_feedback) => %{
            optional(:ghost_opacity) => float(),
            optional(:drag_preview) => term(),
            optional(:cursor_style) => atom()
          },
          optional(:drop_validation) => (term(), map() -> boolean()),
          optional(:accessibility) => %{
            optional(:announce_drag_start) => boolean(),
            optional(:announce_drop) => boolean(),
            optional(:keyboard_enabled) => boolean()
          }
        }

  @doc """
  Initialize the drag and drop system state.

  ## Examples

      iex> DragDrop.init()
      %{active: false, dragging_element: nil, ...}
  """
  def init do
    %{
      active: false,
      dragging_element: nil,
      drag_data: %{},
      start_position: nil,
      current_position: nil,
      drag_offset: %{x: 0, y: 0},
      constraints: %{},
      visual_feedback: %{
        ghost_opacity: 0.6,
        cursor_style: :grabbing
      },
      drop_zones: [],
      valid_drop_target: nil
    }
  end

  @doc """
  Make a component draggable with the specified options.

  ## Examples

      iex> DragDrop.make_draggable("my_button", %{
      ...>   drag_data: %{type: :button, id: "my_button"},
      ...>   constraints: %{horizontal: true},
      ...>   visual_feedback: %{ghost_opacity: 0.8}
      ...> })
  """
  def make_draggable(element_id, options \\ %{}) do
    drag_config = %{
      element_id: element_id,
      draggable: Map.get(options, :draggable, true),
      drag_data: Map.get(options, :drag_data, %{id: element_id}),
      constraints: Map.get(options, :constraints, %{}),
      visual_feedback:
        Map.merge(
          %{ghost_opacity: 0.6, cursor_style: :grab},
          Map.get(options, :visual_feedback, %{})
        ),
      drop_validation:
        Map.get(options, :drop_validation, fn _target, _data -> true end),
      accessibility:
        Map.merge(
          %{
            announce_drag_start: true,
            announce_drop: true,
            keyboard_enabled: true
          },
          Map.get(options, :accessibility, %{})
        )
    }

    # Store drag configuration (this would be stored in component state)
    {:ok, drag_config}
  end

  @doc """
  Register a drop zone that can accept dragged elements.

  ## Examples

      iex> DragDrop.register_drop_zone("sidebar", %{
      ...>   accepts: [:button, :widget],
      ...>   bounds: %{x: 0, y: 0, width: 200, height: 600},
      ...>   validation: &validate_sidebar_drop/2,
      ...>   visual_feedback: %{highlight_color: :blue}
      ...> })
  """
  def register_drop_zone(zone_id, options) do
    drop_zone = %{
      id: zone_id,
      accepts: Map.get(options, :accepts, []),
      bounds: Map.get(options, :bounds, %{}),
      validation: Map.get(options, :validation, fn _target, _data -> true end),
      visual_feedback:
        Map.get(options, :visual_feedback, %{highlight_color: :accent}),
      on_drop: Map.get(options, :on_drop, fn _data -> :ok end),
      on_drag_enter: Map.get(options, :on_drag_enter, fn _data -> :ok end),
      on_drag_leave: Map.get(options, :on_drag_leave, fn _data -> :ok end)
    }

    {:ok, drop_zone}
  end

  @doc """
  Handle the start of a drag operation.

  ## Parameters

  - `state` - Current drag/drop state
  - `element_id` - ID of element being dragged
  - `position` - Mouse position where drag started
  - `drag_config` - Configuration for the draggable element

  ## Returns

  Updated drag/drop state with drag operation active.
  """
  def start_drag(
        state,
        element_id,
        %{x: _x, y: _y} = position,
        %{draggable: true} = drag_config
      ) do
    # Announce to screen readers if accessibility is enabled
    case drag_config.accessibility.announce_drag_start do
      true ->
        data_description = describe_drag_data(drag_config.drag_data)

        Accessibility.announce(
          "Started dragging #{element_id}. #{data_description}"
        )

      false ->
        :ok
    end

    # Start drag visual feedback animation
    Framework.create_animation(:drag_start_feedback, %{
      type: :scale,
      duration: 150,
      from: 1.0,
      to: 1.05,
      easing: :ease_out_back,
      target_path: [:visual, :scale]
    })

    Framework.start_animation(:drag_start_feedback, element_id)

    updated_state = %{
      state
      | active: true,
        dragging_element: element_id,
        drag_data: drag_config.drag_data,
        start_position: position,
        current_position: position,
        constraints: drag_config.constraints,
        visual_feedback: drag_config.visual_feedback
    }

    {:ok, updated_state}
  end

  def start_drag(_state, _element_id, _position, _drag_config) do
    {:error, :not_draggable}
  end

  @doc """
  Handle drag movement during an active drag operation.
  """
  def handle_drag_move(%{active: false} = state, _new_position), do: state

  def handle_drag_move(%{active: true} = state, %{x: _x, y: _y} = new_position) do
    # Apply constraints to movement
    constrained_position =
      apply_drag_constraints(
        new_position,
        state.start_position,
        state.constraints
      )

    # Update drag offset
    drag_offset = %{
      x: constrained_position.x - state.start_position.x,
      y: constrained_position.y - state.start_position.y
    }

    # Check for valid drop targets
    valid_drop_target =
      find_valid_drop_target(
        constrained_position,
        state.drop_zones,
        state.drag_data
      )

    # Update visual feedback if drop target changed
    updated_state =
      update_drop_target_feedback(
        state,
        state.valid_drop_target,
        valid_drop_target
      )

    %{
      updated_state
      | current_position: constrained_position,
        drag_offset: drag_offset,
        valid_drop_target: valid_drop_target
    }
  end

  @doc """
  Handle the end of a drag operation (drop or cancel).
  """
  def end_drag(state, drop_position, cancelled \\ false)

  def end_drag(%{active: false}, _drop_position, _cancelled) do
    {:error, :no_active_drag}
  end

  def end_drag(
        %{active: true} = state,
        %{x: _x, y: _y} = drop_position,
        cancelled
      ) do
    result = handle_drag_result(cancelled, state, drop_position)

    # Cleanup drag state
    reset_state = %{
      state
      | active: false,
        dragging_element: nil,
        drag_data: %{},
        start_position: nil,
        current_position: nil,
        drag_offset: %{x: 0, y: 0},
        valid_drop_target: nil
    }

    # Animation feedback for drop/cancel
    animation_name = get_animation_name(cancelled)

    Framework.create_animation(animation_name, %{
      type: :scale,
      duration: 200,
      from: 1.05,
      to: 1.0,
      easing: :ease_in_back,
      target_path: [:visual, :scale]
    })

    animate_drag_element(state.dragging_element, animation_name)

    {result, reset_state}
  end

  @doc """
  Handle keyboard-based drag and drop for accessibility.
  """
  def handle_keyboard_drag(state, element_id, key, drag_config) do
    case key do
      :space when not state.active ->
        # Start keyboard drag mode
        keyboard_start_drag(state, element_id, drag_config)

      :escape when state.active ->
        # Cancel drag
        {_, new_state} = end_drag(state, %{x: 0, y: 0}, true)
        {:cancelled, new_state}

      arrow_key
      when state.active and arrow_key in [:up, :down, :left, :right] ->
        # Move in keyboard mode
        handle_keyboard_move(state, arrow_key)

      :enter when state.active ->
        # Attempt drop
        {result, new_state} =
          end_drag(state, state.current_position || %{x: 0, y: 0})

        {result, new_state}

      _ ->
        {:no_action, state}
    end
  end

  # Private helper functions

  defp update_drop_target_feedback(state, old_target, new_target)
       when old_target == new_target,
       do: state

  defp update_drop_target_feedback(state, old_target, new_target) do
    handle_drop_target_change(state, old_target, new_target)
  end

  defp handle_drag_result(true, state, _drop_position),
    do: handle_drag_cancel(state)

  defp handle_drag_result(false, state, drop_position),
    do: handle_drop_attempt(state, drop_position)

  defp get_animation_name(true), do: :drag_cancel_feedback
  defp get_animation_name(false), do: :drag_drop_feedback

  defp animate_drag_element(nil, _animation_name), do: :ok

  defp animate_drag_element(element, animation_name) do
    Framework.start_animation(animation_name, element)
  end

  defp describe_drag_data(drag_data) do
    type = Map.get(drag_data, :type, "item")
    id = Map.get(drag_data, :id, "unknown")
    "#{type} with ID #{id}"
  end

  defp apply_drag_constraints(position, start_position, constraints) do
    x = get_constrained_x(position, start_position, constraints)
    y = get_constrained_y(position, start_position, constraints)
    constrained_pos = %{x: x, y: y}

    # Apply bounds constraints if specified
    case Map.get(constraints, :bounds) do
      nil -> constrained_pos
      bounds -> apply_bounds_constraint(constrained_pos, bounds)
    end
  end

  defp get_constrained_x(_position, start_position, %{horizontal: true}),
    do: start_position.x

  defp get_constrained_x(position, _start_position, _constraints),
    do: position.x

  defp get_constrained_y(_position, start_position, %{vertical: true}),
    do: start_position.y

  defp get_constrained_y(position, _start_position, _constraints),
    do: position.y

  defp apply_bounds_constraint(%{x: x, y: y}, bounds) do
    constrained_x = max(bounds.x, min(x, bounds.x + bounds.width))
    constrained_y = max(bounds.y, min(y, bounds.y + bounds.height))
    %{x: constrained_x, y: constrained_y}
  end

  defp find_valid_drop_target(position, drop_zones, drag_data) do
    Enum.find(drop_zones, fn zone ->
      position_in_bounds?(position, zone.bounds) and
        zone_accepts_data?(zone, drag_data) and
        zone.validation.(zone, drag_data)
    end)
  end

  defp position_in_bounds?(%{x: x, y: y}, bounds) do
    x >= bounds.x and x <= bounds.x + bounds.width and
      y >= bounds.y and y <= bounds.y + bounds.height
  end

  defp zone_accepts_data?(zone, drag_data) do
    drag_type = Map.get(drag_data, :type)
    Enum.empty?(zone.accepts) or drag_type in zone.accepts
  end

  defp handle_drop_target_change(state, old_target, new_target) do
    handle_drag_leave(old_target, state.drag_data)
    handle_drag_enter(new_target, state.drag_data)
    state
  end

  defp handle_drag_leave(nil, _drag_data), do: :ok

  defp handle_drag_leave(old_target, drag_data) do
    old_target.on_drag_leave.(drag_data)
    # Stop highlighting old target
    Framework.create_animation(:drop_zone_unhighlight, %{
      type: :fade,
      duration: 200,
      from: 1.0,
      to: 0.8,
      target_path: [:visual, :highlight_opacity]
    })

    Framework.start_animation(:drop_zone_unhighlight, old_target.id)
  end

  defp handle_drag_enter(nil, _drag_data), do: :ok

  defp handle_drag_enter(new_target, drag_data) do
    new_target.on_drag_enter.(drag_data)
    # Start highlighting new target
    Framework.create_animation(:drop_zone_highlight, %{
      type: :fade,
      duration: 200,
      from: 0.8,
      to: 1.0,
      target_path: [:visual, :highlight_opacity]
    })

    Framework.start_animation(:drop_zone_highlight, new_target.id)
  end

  defp handle_drag_cancel(state) do
    animate_drag_cancel(state.dragging_element, state.drag_offset)
    :cancelled
  end

  defp animate_drag_cancel(nil, _drag_offset), do: :ok

  defp animate_drag_cancel(element, drag_offset) do
    Accessibility.announce("Drag cancelled")

    # Animate return to original position
    Framework.create_animation(:drag_return, %{
      type: :slide,
      duration: 300,
      from: drag_offset,
      to: %{x: 0, y: 0},
      easing: :ease_out_back,
      target_path: [:visual, :position]
    })

    Framework.start_animation(:drag_return, element)
  end

  defp handle_drop_attempt(%{valid_drop_target: nil} = state, _drop_position) do
    handle_drag_cancel(state)
  end

  defp handle_drop_attempt(
         %{valid_drop_target: drop_target} = state,
         _drop_position
       ) do
    result = drop_target.on_drop.(state.drag_data)

    announce_drop_success(state.dragging_element, drop_target.id)
    animate_drop_success(state.dragging_element)

    {:dropped, result}
  end

  defp announce_drop_success(element, target_id) do
    Accessibility.announce("Dropped #{element} on #{target_id}")
  end

  defp animate_drop_success(nil), do: :ok

  defp animate_drop_success(element) do
    # Success animation
    Framework.create_animation(:drop_success, %{
      type: :bounce,
      duration: 400,
      from: 1.0,
      to: 1.0,
      easing: :ease_out_bounce,
      target_path: [:visual, :scale]
    })

    Framework.start_animation(:drop_success, element)
  end

  defp keyboard_start_drag(state, element_id, drag_config) do
    Accessibility.announce(
      "Started keyboard drag mode for #{element_id}. Use arrow keys to move, Enter to drop, Escape to cancel."
    )

    # Use current element position as start position
    # This should be retrieved from element's actual position
    start_position = %{x: 0, y: 0}

    start_drag(state, element_id, start_position, drag_config)
  end

  defp handle_keyboard_move(state, direction) do
    # Configurable step size for keyboard movement
    step_size = 10

    {dx, dy} = get_movement_delta(direction, step_size)

    current_pos = state.current_position || %{x: 0, y: 0}
    new_position = %{x: current_pos.x + dx, y: current_pos.y + dy}

    updated_state = handle_drag_move(state, new_position)

    # Announce position for screen readers
    announce_position(updated_state.valid_drop_target, new_position)

    {:moved, updated_state}
  end

  defp get_movement_delta(:up, step_size), do: {0, -step_size}
  defp get_movement_delta(:down, step_size), do: {0, step_size}
  defp get_movement_delta(:left, step_size), do: {-step_size, 0}
  defp get_movement_delta(:right, step_size), do: {step_size, 0}

  defp announce_position(nil, position) do
    Accessibility.announce("Position: #{position.x}, #{position.y}")
  end

  defp announce_position(drop_target, _position) do
    Accessibility.announce("Over drop zone: #{drop_target.id}")
  end
end
