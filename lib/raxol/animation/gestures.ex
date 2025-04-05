defmodule Raxol.Animation.Gestures do
  @moduledoc """
  Gesture-driven interactions for Raxol animations.
  
  This module provides a system for detecting and handling gestures in terminal UI,
  which can be used to trigger physics-based animations.
  
  Supported gestures include:
  * Swipe (rapid movement in a direction)
  * Tap (quick press and release)
  * Long press (press and hold)
  * Drag (press, move, release)
  * Pinch/zoom (simulated in terminal context)
  * Multi-tap (multiple quick taps)
  """
  
  alias Raxol.Animation.Physics.{PhysicsEngine, Vector}
  
  # Gesture state
  defmodule State do
    @moduledoc false
    defstruct [
      :touch_start,
      :touch_current,
      :touch_history,
      :start_time,
      :current_time,
      :is_active,
      :gesture_type,
      :velocity,
      :handlers,
      :active_animations
    ]
    
    def new do
      %__MODULE__{
        touch_start: nil,
        touch_current: nil,
        touch_history: [],
        start_time: nil,
        current_time: nil,
        is_active: false,
        gesture_type: nil,
        velocity: %Vector{},
        handlers: %{},
        active_animations: []
      }
    end
  end
  
  # Process dictionary key for gesture state
  @state_key :raxol_gesture_state
  
  @type position :: {integer(), integer()}
  @type gesture_type :: :swipe | :tap | :long_press | :drag | :pinch | :multi_tap
  @type direction :: :up | :down | :left | :right
  @type handler :: (map() -> any())
  
  @doc """
  Initializes the gesture system.
  """
  def init do
    state = State.new()
    Process.put(@state_key, state)
    :ok
  end
  
  @doc """
  Registers a handler for a specific gesture type.
  
  ## Examples
  
      iex> register_handler(:swipe, fn %{direction: :left} -> handle_left_swipe() end)
      :ok
  """
  def register_handler(gesture_type, handler) when is_function(handler, 1) do
    with_state(fn state ->
      handlers = Map.update(
        state.handlers, 
        gesture_type, 
        [handler],
        &[handler | &1]
      )
      
      %{state | handlers: handlers}
    end)
    
    :ok
  end
  
  @doc """
  Handles a touch/mouse down event.
  """
  def touch_down(position, time \\ System.monotonic_time(:millisecond)) do
    with_state(fn state ->
      %{state |
        touch_start: position,
        touch_current: position,
        touch_history: [position],
        start_time: time,
        current_time: time,
        is_active: true,
        gesture_type: nil
      }
    end)
    
    :ok
  end
  
  @doc """
  Handles a touch/mouse move event.
  """
  def touch_move(position, time \\ System.monotonic_time(:millisecond)) do
    with_state(fn state ->
      if state.is_active do
        # Calculate velocity based on time difference
        time_diff = max(1, time - state.current_time)
        {prev_x, prev_y} = state.touch_current
        {curr_x, curr_y} = position
        
        velocity = %Vector{
          x: (curr_x - prev_x) / time_diff * 1000, # px/s
          y: (curr_y - prev_y) / time_diff * 1000  # px/s
        }
        
        # Update state
        %{state |
          touch_current: position,
          touch_history: [position | state.touch_history] |> Enum.take(10),
          current_time: time,
          velocity: velocity,
          gesture_type: detect_gesture_type(state, :move)
        }
      else
        state
      end
    end)
    
    :ok
  end
  
  @doc """
  Handles a touch/mouse up event.
  """
  def touch_up(position, time \\ System.monotonic_time(:millisecond)) do
    with_state(fn state ->
      if state.is_active do
        # Final position and gesture type
        gesture_type = detect_gesture_type(state, :up)
        
        # Prepare gesture data
        {start_x, start_y} = state.touch_start
        {end_x, end_y} = position
        dx = end_x - start_x
        dy = end_y - start_y
        distance = :math.sqrt(dx * dx + dy * dy)
        duration = time - state.start_time
        
        # Determine direction for swipes
        direction = cond do
          abs(dx) > abs(dy) and dx > 0 -> :right
          abs(dx) > abs(dy) and dx < 0 -> :left
          abs(dy) >= abs(dx) and dy > 0 -> :down
          abs(dy) >= abs(dx) and dy < 0 -> :up
          true -> :none
        end
        
        # Create gesture data
        gesture_data = %{
          type: gesture_type,
          start_position: state.touch_start,
          end_position: position,
          distance: distance,
          direction: direction,
          duration: duration,
          velocity: state.velocity
        }
        
        # Call appropriate handlers
        call_handlers(gesture_type, gesture_data)
        
        # Start physics animation if applicable
        active_animations = case gesture_type do
          :swipe -> start_swipe_animation(gesture_data, state.active_animations)
          :drag -> start_drag_animation(gesture_data, state.active_animations)
          _ -> state.active_animations
        end
        
        # Reset state but keep handlers and animations
        %{state |
          touch_start: nil,
          touch_current: nil,
          touch_history: [],
          start_time: nil,
          current_time: nil,
          is_active: false,
          gesture_type: nil,
          velocity: %Vector{},
          active_animations: active_animations
        }
      else
        state
      end
    end)
    
    :ok
  end
  
  @doc """
  Updates all active physics-based animations.
  Should be called on each frame.
  """
  def update_animations(delta_time \\ nil) do
    with_state(fn state ->
      # Update all physics worlds
      updated_animations = Enum.map(state.active_animations, fn anim ->
        world = PhysicsEngine.update(anim.world, delta_time)
        %{anim | world: world}
      end)
      
      # Filter out completed animations
      active_animations = Enum.filter(updated_animations, fn anim ->
        not animation_completed?(anim)
      end)
      
      %{state | active_animations: active_animations}
    end)
    
    :ok
  end
  
  @doc """
  Gets the current state of all objects in active animations.
  This is used for rendering.
  """
  def get_animation_objects do
    with_state(fn state ->
      objects = Enum.flat_map(state.active_animations, fn anim ->
        Enum.map(anim.world.objects, fn {_id, object} ->
          Map.put(object, :animation_id, anim.id)
        end)
      end)
      
      {state, objects}
    end)
  end
  
  # Private helpers
  
  defp with_state(fun) do
    state = Process.get(@state_key) || State.new()
    
    case fun.(state) do
      {new_state, result} ->
        Process.put(@state_key, new_state)
        result
      new_state ->
        Process.put(@state_key, new_state)
        nil
    end
  end
  
  defp detect_gesture_type(state, phase) do
    duration = state.current_time - state.start_time
    
    {start_x, start_y} = state.touch_start
    {current_x, current_y} = state.touch_current
    dx = current_x - start_x
    dy = current_y - start_y
    distance = :math.sqrt(dx * dx + dy * dy)
    
    velocity_magnitude = Vector.magnitude(state.velocity)
    
    cond do
      # On move phase, detect drag or potential swipe
      phase == :move ->
        cond do
          distance > 5 and velocity_magnitude > 200 -> :swipe
          distance > 5 -> :drag
          duration > 500 -> :long_press
          true -> nil
        end
        
      # On up phase, finalize gesture type
      phase == :up ->
        cond do
          duration < 200 and distance < 5 -> :tap
          duration > 500 and distance < 5 -> :long_press
          velocity_magnitude > 200 -> :swipe
          distance > 5 -> :drag
          true -> :tap
        end
        
      true -> nil
    end
  end
  
  defp call_handlers(gesture_type, gesture_data) do
    with_state(fn state ->
      handlers = Map.get(state.handlers, gesture_type, [])
      
      # Call each handler with the gesture data
      Enum.each(handlers, fn handler ->
        try do
          handler.(gesture_data)
        catch
          kind, reason ->
            IO.puts("Error in gesture handler: #{inspect(kind)}, #{inspect(reason)}")
        end
      end)
      
      {state, nil}
    end)
  end
  
  defp start_swipe_animation(gesture_data, animations) do
    # Create a physics world for the swipe
    world = PhysicsEngine.new_world(
      gravity: %Vector{x: 0, y: 0, z: 0},
      time_scale: 1.0,
      boundaries: %{
        min_x: 0,
        max_x: 100,
        min_y: 0,
        max_y: 100
      }
    )
    
    # Create main object with initial velocity based on swipe
    velocity = %Vector{
      x: gesture_data.velocity.x * 0.5,
      y: gesture_data.velocity.y * 0.5,
      z: 0
    }
    
    {x, y} = gesture_data.end_position
    
    obj = PhysicsEngine.new_object("main", 
      position: %Vector{x: x, y: y, z: 0},
      velocity: velocity,
      mass: 1.0,
      properties: %{
        damping: 0.95, # Add damping to slow down over time
        type: :swipe_object
      }
    )
    
    world = PhysicsEngine.add_object(world, obj)
    
    # Add the animation to the list
    [%{
      id: "swipe_#{:erlang.unique_integer([:positive, :monotonic])}",
      type: :swipe,
      world: world,
      start_time: System.monotonic_time(:millisecond),
      duration: 1000, # Limit to 1 second
      data: gesture_data
    } | animations]
  end
  
  defp start_drag_animation(gesture_data, animations) do
    # Create a physics world for the drag with spring behavior
    world = PhysicsEngine.new_world(
      gravity: %Vector{x: 0, y: 0, z: 0},
      time_scale: 1.0
    )
    
    # Create two objects: one fixed at the release point and one that will spring back
    {end_x, end_y} = gesture_data.end_position
    {target_x, target_y} = gesture_data.start_position
    
    # The dragged object
    dragged = PhysicsEngine.new_object("dragged", 
      position: %Vector{x: end_x, y: end_y, z: 0},
      velocity: %Vector{x: 0, y: 0, z: 0},
      mass: 1.0,
      properties: %{
        damping: 0.8,
        type: :drag_object
      }
    )
    
    # The target (fixed)
    target = PhysicsEngine.new_object("target", 
      position: %Vector{x: target_x, y: target_y, z: 0},
      velocity: %Vector{x: 0, y: 0, z: 0},
      mass: 1000.0, # Very heavy = almost immovable
      properties: %{
        type: :target
      }
    )
    
    # Add objects to world
    world = world
    |> PhysicsEngine.add_object(dragged)
    |> PhysicsEngine.add_object(target)
    
    # Create a spring force between them
    world = PhysicsEngine.spring_force(world, "dragged", "target", 0.3, 0)
    
    # Add the animation to the list
    [%{
      id: "drag_#{:erlang.unique_integer([:positive, :monotonic])}",
      type: :drag,
      world: world,
      start_time: System.monotonic_time(:millisecond),
      duration: 800, # Shorter duration
      data: gesture_data
    } | animations]
  end
  
  defp animation_completed?(animation) do
    current_time = System.monotonic_time(:millisecond)
    elapsed = current_time - animation.start_time
    
    # Animation completes if duration is reached or all objects have very low velocity
    if elapsed > animation.duration do
      true
    else
      # Check if all objects have essentially stopped moving
      Enum.all?(animation.world.objects, fn {_, obj} ->
        Vector.magnitude(obj.velocity) < 0.5
      end)
    end
  end
end 