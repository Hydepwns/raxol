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
  alias Raxol.Core.Accessibility, as: Accessibility

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
  def start_drag(state, element_id, %{x: _x, y: _y} = position, drag_config) do
    if drag_config.draggable do
      # Announce to screen readers if accessibility is enabled
      if drag_config.accessibility.announce_drag_start do
        data_description = describe_drag_data(drag_config.drag_data)

        Accessibility.announce(
          "Started dragging #{element_id}. #{data_description}"
        )
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
    else
      {:error, :not_draggable}
    end
  end

  @doc """
  Handle drag movement during an active drag operation.
  """
  def handle_drag_move(state, %{x: _x, y: _y} = new_position) do
    if state.active do
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
        if valid_drop_target != state.valid_drop_target do
          handle_drop_target_change(
            state,
            state.valid_drop_target,
            valid_drop_target
          )
        else
          state
        end

      %{
        updated_state
        | current_position: constrained_position,
          drag_offset: drag_offset,
          valid_drop_target: valid_drop_target
      }
    else
      state
    end
  end

  @doc """
  Handle the end of a drag operation (drop or cancel).
  """
  def end_drag(state, %{x: _x, y: _y} = drop_position, cancelled \\ false) do
    if state.active do
      result =
        if cancelled do
          handle_drag_cancel(state)
        else
          handle_drop_attempt(state, drop_position)
        end

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
      animation_name =
        if cancelled, do: :drag_cancel_feedback, else: :drag_drop_feedback

      Framework.create_animation(animation_name, %{
        type: :scale,
        duration: 200,
        from: 1.05,
        to: 1.0,
        easing: :ease_in_back,
        target_path: [:visual, :scale]
      })

      if state.dragging_element do
        Framework.start_animation(animation_name, state.dragging_element)
      end

      {result, reset_state}
    else
      {:error, :no_active_drag}
    end
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

  defp describe_drag_data(drag_data) do
    type = Map.get(drag_data, :type, "item")
    id = Map.get(drag_data, :id, "unknown")
    "#{type} with ID #{id}"
  end

  defp apply_drag_constraints(position, start_position, constraints) do
    x =
      if Map.get(constraints, :horizontal, false) do
        start_position.x
      else
        position.x
      end

    y =
      if Map.get(constraints, :vertical, false) do
        start_position.y
      else
        position.y
      end

    constrained_pos = %{x: x, y: y}

    # Apply bounds constraints if specified
    case Map.get(constraints, :bounds) do
      nil -> constrained_pos
      bounds -> apply_bounds_constraint(constrained_pos, bounds)
    end
  end

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
    # Handle drag leave for old target
    if old_target do
      old_target.on_drag_leave.(state.drag_data)
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

    # Handle drag enter for new target
    if new_target do
      new_target.on_drag_enter.(state.drag_data)
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

    state
  end

  defp handle_drag_cancel(state) do
    if state.dragging_element do
      Accessibility.announce("Drag cancelled")

      # Animate return to original position
      Framework.create_animation(:drag_return, %{
        type: :slide,
        duration: 300,
        from: state.drag_offset,
        to: %{x: 0, y: 0},
        easing: :ease_out_back,
        target_path: [:visual, :position]
      })

      Framework.start_animation(:drag_return, state.dragging_element)
    end

    :cancelled
  end

  defp handle_drop_attempt(state, _drop_position) do
    if state.valid_drop_target do
      result = state.valid_drop_target.on_drop.(state.drag_data)

      if state.valid_drop_target do
        Accessibility.announce(
          "Dropped #{state.dragging_element} on #{state.valid_drop_target.id}"
        )

        # Success animation
        Framework.create_animation(:drop_success, %{
          type: :bounce,
          duration: 400,
          from: 1.0,
          to: 1.0,
          easing: :ease_out_bounce,
          target_path: [:visual, :scale]
        })

        if state.dragging_element do
          Framework.start_animation(:drop_success, state.dragging_element)
        end
      end

      {:dropped, result}
    else
      handle_drag_cancel(state)
    end
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

    {dx, dy} =
      case direction do
        :up -> {0, -step_size}
        :down -> {0, step_size}
        :left -> {-step_size, 0}
        :right -> {step_size, 0}
      end

    current_pos = state.current_position || %{x: 0, y: 0}
    new_position = %{x: current_pos.x + dx, y: current_pos.y + dy}

    updated_state = handle_drag_move(state, new_position)

    # Announce position for screen readers
    if updated_state.valid_drop_target do
      Accessibility.announce(
        "Over drop zone: #{updated_state.valid_drop_target.id}"
      )
    else
      Accessibility.announce("Position: #{new_position.x}, #{new_position.y}")
    end

    {:moved, updated_state}
  end
end
