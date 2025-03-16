defmodule Raxol.Animation.Framework do
  @moduledoc """
  A general-purpose animation framework for Raxol terminal UI applications.
  
  This module provides a comprehensive animation system that:
  - Supports various animation types (easing, physics-based, keyframes)
  - Respects reduced motion accessibility settings
  - Provides smooth transitions between UI states
  - Offers standard animation patterns for common interactions
  - Manages animation timing and rendering
  
  The framework automatically adapts to user preferences for reduced motion
  and will provide alternative non-animated transitions when needed.
  
  ## Usage
  
  ```elixir
  # Initialize the animation framework
  AnimationFramework.init()
  
  # Create a simple animation
  animation = AnimationFramework.create_animation(:fade_in, %{
    duration: 300,
    easing: :ease_out_cubic
  })
  
  # Start the animation
  AnimationFramework.start_animation(animation, :element_id)
  
  # Update state with animation progress
  updated_state = AnimationFramework.apply_animation(state, now)
  ```
  """
  
  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Animation.Easing
  alias Raxol.Core.Accessibility
  
  @animation_fps 30
  @animation_frame_ms round(1000 / @animation_fps)
  
  @doc """
  Initialize the animation framework.
  
  This sets up the necessary state for tracking animations and
  integrates with accessibility settings.
  
  ## Options
  
  * `:reduced_motion` - Start with reduced motion (default: from accessibility settings)
  * `:default_duration` - Default animation duration in milliseconds (default: 300)
  
  ## Examples
  
      iex> AnimationFramework.init()
      :ok
      
      iex> AnimationFramework.init(reduced_motion: true)
      :ok
  """
  def init(opts \\ []) do
    # Get reduced motion setting from accessibility or options
    reduced_motion = case Process.get(:accessibility_options) do
      nil -> Keyword.get(opts, :reduced_motion, false)
      accessibility_options -> Keyword.get(opts, :reduced_motion, accessibility_options[:reduced_motion])
    end
    
    # Get default duration
    default_duration = Keyword.get(opts, :default_duration, 300)
    
    # Initialize animations registry
    Process.put(:animation_framework_animations, %{})
    
    # Initialize active animations
    Process.put(:animation_framework_active_animations, %{})
    
    # Initialize animation settings
    Process.put(:animation_framework_settings, %{
      reduced_motion: reduced_motion,
      default_duration: default_duration
    })
    
    # Register standard animations
    register_standard_animations()
    
    # Register event handlers for accessibility changes
    EventManager.register_handler(:accessibility_reduced_motion, __MODULE__, :handle_reduced_motion)
    
    # Start animation timer if not in reduced motion mode
    unless reduced_motion do
      schedule_animation_frame()
    end
    
    :ok
  end
  
  @doc """
  Create a new animation.
  
  ## Parameters
  
  * `name` - Identifier for the animation
  * `params` - Map of animation parameters
  
  ## Animation Parameters
  
  * `:type` - Animation type (`:fade`, `:slide`, `:scale`, `:color`)
  * `:duration` - Duration in milliseconds
  * `:easing` - Easing function (`:linear`, `:ease_in`, `:ease_out`, etc.)
  * `:from` - Starting value
  * `:to` - Ending value
  * `:direction` - For directional animations (`:in`, `:out`, `:left`, `:right`, etc.)
  * `:reduced_motion_alternative` - Alternative to use when reduced motion is enabled
  
  ## Examples
  
      iex> AnimationFramework.create_animation(:fade_in, %{
      ...>   type: :fade,
      ...>   duration: 300,
      ...>   easing: :ease_out_cubic,
      ...>   from: 0.0,
      ...>   to: 1.0,
      ...>   direction: :in
      ...> })
      %{
        name: :fade_in,
        type: :fade,
        duration: 300,
        easing: :ease_out_cubic,
        from: 0.0,
        to: 1.0,
        direction: :in
      }
  """
  def create_animation(name, params) do
    # Get default settings
    settings = Process.get(:animation_framework_settings, %{})
    default_duration = Map.get(settings, :default_duration, 300)
    
    # Create animation with defaults
    animation = Map.merge(%{
      name: name,
      duration: default_duration,
      easing: :linear,
      type: :generic
    }, params)
    
    # Store animation in registry
    animations = Process.get(:animation_framework_animations, %{})
    updated_animations = Map.put(animations, name, animation)
    Process.put(:animation_framework_animations, updated_animations)
    
    animation
  end
  
  @doc """
  Start an animation for a specific element.
  
  ## Parameters
  
  * `animation_name` - The name of the animation to start
  * `element_id` - Identifier for the element being animated
  * `opts` - Additional options
  
  ## Options
  
  * `:on_complete` - Function to call when animation completes
  * `:context` - Additional context for the animation
  
  ## Examples
  
      iex> AnimationFramework.start_animation(:fade_in, "search_button")
      :ok
      
      iex> AnimationFramework.start_animation(:slide_in, "panel", on_complete: &handle_complete/1)
      :ok
  """
  def start_animation(animation_name, element_id, opts \\ []) do
    # Get settings
    settings = Process.get(:animation_framework_settings, %{})
    reduced_motion = Map.get(settings, :reduced_motion, false)
    
    # Get the animation
    animations = Process.get(:animation_framework_animations, %{})
    animation = Map.get(animations, animation_name)
    
    if animation == nil do
      {:error, :animation_not_found}
    else
      # If reduced motion is enabled, check for alternative
      animation = if reduced_motion and Map.has_key?(animation, :reduced_motion_alternative) do
        # Use the alternative animation
        alt_name = Map.get(animation, :reduced_motion_alternative)
        Map.get(animations, alt_name, animation)
      else
        animation
      end
      
      # Create active animation instance
      now = :erlang.system_time(:millisecond)
      
      instance = %{
        animation: animation,
        element_id: element_id,
        start_time: now,
        end_time: now + animation.duration,
        progress: 0.0,
        value: animation.from,
        on_complete: Keyword.get(opts, :on_complete),
        context: Keyword.get(opts, :context, %{}),
        completed: false
      }
      
      # Add to active animations
      active_animations = Process.get(:animation_framework_active_animations, %{})
      element_animations = Map.get(active_animations, element_id, %{})
      updated_element_animations = Map.put(element_animations, animation_name, instance)
      updated_active_animations = Map.put(active_animations, element_id, updated_element_animations)
      Process.put(:animation_framework_active_animations, updated_active_animations)
      
      # If reduced motion is enabled, instantly complete the animation
      if reduced_motion do
        complete_animation(element_id, animation_name)
      end
      
      :ok
    end
  end
  
  @doc """
  Stop an active animation for a specific element.
  
  ## Parameters
  
  * `element_id` - Identifier for the element
  * `animation_name` - The name of the animation to stop
  
  ## Examples
  
      iex> AnimationFramework.stop_animation("search_button", :fade_in)
      :ok
  """
  def stop_animation(element_id, animation_name) do
    # Get active animations
    active_animations = Process.get(:animation_framework_active_animations, %{})
    
    # Update active animations by removing the specified animation
    if Map.has_key?(active_animations, element_id) do
      element_animations = Map.get(active_animations, element_id)
      
      if Map.has_key?(element_animations, animation_name) do
        # Remove this specific animation
        updated_element_animations = Map.delete(element_animations, animation_name)
        
        # If there are no more animations for this element, remove the element entry
        updated_active_animations = if map_size(updated_element_animations) == 0 do
          Map.delete(active_animations, element_id)
        else
          Map.put(active_animations, element_id, updated_element_animations)
        end
        
        Process.put(:animation_framework_active_animations, updated_active_animations)
      end
    end
    
    :ok
  end
  
  @doc """
  Update animation state based on the current time.
  
  This function should be called on each frame update to progress animations.
  
  ## Parameters
  
  * `state` - The current application state
  * `timestamp` - The current timestamp in milliseconds
  
  ## Returns
  
  * Updated state with progressed animations
  
  ## Examples
  
      iex> AnimationFramework.update_animations(state, :erlang.system_time(:millisecond))
      %{...updated state...}
  """
  def update_animations(state, timestamp) do
    # Get active animations
    active_animations = Process.get(:animation_framework_active_animations, %{})
    
    # Track completed animations for removal
    completed = []
    
    # Process each active animation
    {updated_active_animations, completed} = Enum.reduce(active_animations, {%{}, completed}, 
      fn {element_id, element_animations}, {acc_animations, acc_completed} ->
        {updated_element_animations, element_completed} = 
          process_element_animations(element_id, element_animations, timestamp)
        
        # Add to completed list if needed
        updated_completed = acc_completed ++ element_completed
        
        # Add updated animations for this element
        updated_animations = if map_size(updated_element_animations) > 0 do
          Map.put(acc_animations, element_id, updated_element_animations)
        else
          acc_animations
        end
        
        {updated_animations, updated_completed}
      end)
    
    # Store updated active animations
    Process.put(:animation_framework_active_animations, updated_active_animations)
    
    # Handle completed animations
    Enum.each(completed, fn {element_id, animation_name, instance} ->
      # Call completion callback if provided
      if instance.on_complete != nil do
        instance.on_complete.(%{
          element_id: element_id,
          animation: animation_name,
          context: instance.context
        })
      end
      
      # Broadcast animation completion event
      EventManager.broadcast({:animation_complete, element_id, animation_name})
    end)
    
    # Update state with current animation values
    apply_animations_to_state(state)
  end
  
  @doc """
  Get the current value of an animation for an element.
  
  ## Parameters
  
  * `element_id` - Identifier for the element
  * `animation_name` - The name of the animation
  
  ## Returns
  
  * The current animation value, or `nil` if not active
  
  ## Examples
  
      iex> AnimationFramework.get_animation_value("search_button", :fade_in)
      0.75
  """
  def get_animation_value(element_id, animation_name) do
    # Get active animations
    active_animations = Process.get(:animation_framework_active_animations, %{})
    
    # Get the specific animation instance
    case get_in(active_animations, [element_id, animation_name]) do
      nil -> nil
      instance -> instance.value
    end
  end
  
  @doc """
  Check if reduced motion is enabled.
  
  ## Examples
  
      iex> AnimationFramework.reduced_motion_enabled?()
      false
  """
  def reduced_motion_enabled? do
    settings = Process.get(:animation_framework_settings, %{})
    Map.get(settings, :reduced_motion, false)
  end
  
  @doc """
  Handle reduced motion setting changes from the accessibility module.
  """
  def handle_reduced_motion({:accessibility_reduced_motion, enabled}) do
    # Update reduced motion setting
    settings = Process.get(:animation_framework_settings, %{})
    updated_settings = Map.put(settings, :reduced_motion, enabled)
    Process.put(:animation_framework_settings, updated_settings)
    
    if enabled do
      # Complete all active animations immediately
      complete_all_animations()
    else
      # Start animation timer if it's not already running
      schedule_animation_frame()
    end
    
    :ok
  end
  
  # Private functions
  
  defp process_element_animations(element_id, element_animations, timestamp) do
    Enum.reduce(element_animations, {%{}, []}, fn {animation_name, instance}, {acc_animations, acc_completed} ->
      # If already completed, skip
      if instance.completed do
        {Map.put(acc_animations, animation_name, instance), acc_completed}
      else
        # Calculate progress
        progress = calculate_progress(instance, timestamp)
        
        # Calculate new value
        value = calculate_value(instance, progress)
        
        # Update instance
        updated_instance = %{instance | 
          progress: progress,
          value: value,
          completed: progress >= 1.0
        }
        
        # Add to completed list if done
        updated_completed = if progress >= 1.0 do
          acc_completed ++ [{element_id, animation_name, updated_instance}]
        else
          acc_completed
        end
        
        # Add to updated animations
        {Map.put(acc_animations, animation_name, updated_instance), updated_completed}
      end
    end)
  end
  
  defp calculate_progress(instance, timestamp) do
    # Calculate linear progress (0.0 to 1.0)
    duration = instance.end_time - instance.start_time
    
    elapsed = timestamp - instance.start_time
    
    progress = if duration <= 0 do
      1.0
    else
      elapsed / duration
    end
    
    # Clamp to range
    min(1.0, max(0.0, progress))
  end
  
  defp calculate_value(instance, progress) do
    # Apply easing function
    easing_fn = get_easing_function(instance.animation.easing)
    eased_progress = easing_fn.(progress)
    
    # Interpolate between from and to values
    from = instance.animation.from
    to = instance.animation.to
    
    from + (to - from) * eased_progress
  end
  
  defp get_easing_function(:linear), do: &Easing.linear/1
  defp get_easing_function(:ease_in), do: &Easing.ease_in/1
  defp get_easing_function(:ease_out), do: &Easing.ease_out/1
  defp get_easing_function(:ease_in_out), do: &Easing.ease_in_out/1
  defp get_easing_function(:ease_in_cubic), do: &Easing.ease_in_cubic/1
  defp get_easing_function(:ease_out_cubic), do: &Easing.ease_out_cubic/1
  defp get_easing_function(:ease_in_out_cubic), do: &Easing.ease_in_out_cubic/1
  defp get_easing_function(:ease_in_quad), do: &Easing.ease_in_quad/1
  defp get_easing_function(:ease_out_quad), do: &Easing.ease_out_quad/1
  defp get_easing_function(:ease_in_out_quad), do: &Easing.ease_in_out_quad/1
  defp get_easing_function(:ease_in_elastic), do: &Easing.ease_in_elastic/1
  defp get_easing_function(:ease_out_elastic), do: &Easing.ease_out_elastic/1
  defp get_easing_function(:ease_in_out_elastic), do: &Easing.ease_in_out_elastic/1
  defp get_easing_function(_), do: &Easing.linear/1
  
  defp apply_animations_to_state(state) do
    # Get active animations
    active_animations = Process.get(:animation_framework_active_animations, %{})
    
    # Apply each animation to the state (implementation depends on state structure)
    # This is just a placeholder - real implementation would update appropriate parts of state
    Enum.reduce(active_animations, state, fn {element_id, element_animations}, acc_state ->
      # For each animation affecting this element
      Enum.reduce(element_animations, acc_state, fn {animation_name, instance}, element_acc_state ->
        # Apply this specific animation to the state
        apply_animation_to_state(element_acc_state, element_id, animation_name, instance)
      end)
    end)
  end
  
  defp apply_animation_to_state(state, element_id, animation_name, instance) do
    # Implementation depends on state structure and animation type
    # This is a placeholder for demonstration
    case instance.animation.type do
      :fade ->
        # Update opacity for the element
        set_in_state(state, [:elements, element_id, :opacity], instance.value)
      
      :slide ->
        # Update position for the element
        set_in_state(state, [:elements, element_id, :position], instance.value)
      
      :scale ->
        # Update scale for the element
        set_in_state(state, [:elements, element_id, :scale], instance.value)
      
      :color ->
        # Update color for the element
        set_in_state(state, [:elements, element_id, :color], instance.value)
      
      _ ->
        # For generic animations, store the value in a animations map
        animations = Map.get(state, :animations, %{})
        element_animations = Map.get(animations, element_id, %{})
        updated_element_animations = Map.put(element_animations, animation_name, instance.value)
        updated_animations = Map.put(animations, element_id, updated_element_animations)
        Map.put(state, :animations, updated_animations)
    end
  end
  
  defp set_in_state(state, path, value) do
    # Helper function to set a value deep in the state
    # This is a simple implementation - a real one would handle missing paths
    put_in(state, path, value)
  rescue
    # Handle case where path doesn't exist
    _ -> state
  end
  
  defp complete_animation(element_id, animation_name) do
    # Get active animations
    active_animations = Process.get(:animation_framework_active_animations, %{})
    
    # Get the specific animation instance
    case get_in(active_animations, [element_id, animation_name]) do
      nil -> 
        :ok
      
      instance ->
        # Update instance to completed state
        updated_instance = %{instance |
          progress: 1.0,
          value: instance.animation.to,
          completed: true
        }
        
        # Update in active animations
        updated_active_animations = put_in(active_animations, [element_id, animation_name], updated_instance)
        Process.put(:animation_framework_active_animations, updated_active_animations)
        
        # Call completion callback if provided
        if instance.on_complete != nil do
          instance.on_complete.(%{
            element_id: element_id,
            animation: animation_name,
            context: instance.context
          })
        end
        
        # Broadcast animation completion event
        EventManager.broadcast({:animation_complete, element_id, animation_name})
    end
  end
  
  defp complete_all_animations do
    # Get active animations
    active_animations = Process.get(:animation_framework_active_animations, %{})
    
    # Complete each animation
    Enum.each(active_animations, fn {element_id, element_animations} ->
      Enum.each(element_animations, fn {animation_name, _} ->
        complete_animation(element_id, animation_name)
      end)
    end)
  end
  
  defp schedule_animation_frame do
    # Check if reduced motion is enabled
    settings = Process.get(:animation_framework_settings, %{})
    reduced_motion = Map.get(settings, :reduced_motion, false)
    
    unless reduced_motion do
      # Schedule next animation frame
      Process.send_after(self(), :animation_frame, @animation_frame_ms)
    end
  end
  
  def handle_info(:animation_frame, state) do
    now = :erlang.system_time(:millisecond)
    
    # Update animations
    updated_state = update_animations(state, now)
    
    # Schedule next frame
    schedule_animation_frame()
    
    {:noreply, updated_state}
  end
  
  defp register_standard_animations do
    # Register common animations
    
    # Fade animations
    create_animation(:fade_in, %{
      type: :fade,
      from: 0.0,
      to: 1.0,
      duration: 300,
      easing: :ease_out_cubic,
      direction: :in,
      reduced_motion_alternative: :instant_appear
    })
    
    create_animation(:fade_out, %{
      type: :fade,
      from: 1.0,
      to: 0.0,
      duration: 300,
      easing: :ease_in_cubic,
      direction: :out,
      reduced_motion_alternative: :instant_disappear
    })
    
    # Slide animations
    create_animation(:slide_in_right, %{
      type: :slide,
      from: -100,
      to: 0,
      duration: 300,
      easing: :ease_out_cubic,
      direction: :right,
      reduced_motion_alternative: :instant_appear
    })
    
    create_animation(:slide_in_left, %{
      type: :slide,
      from: 100,
      to: 0,
      duration: 300,
      easing: :ease_out_cubic,
      direction: :left,
      reduced_motion_alternative: :instant_appear
    })
    
    create_animation(:slide_in_up, %{
      type: :slide,
      from: 100,
      to: 0,
      duration: 300,
      easing: :ease_out_cubic,
      direction: :up,
      reduced_motion_alternative: :instant_appear
    })
    
    create_animation(:slide_in_down, %{
      type: :slide,
      from: -100,
      to: 0,
      duration: 300,
      easing: :ease_out_cubic,
      direction: :down,
      reduced_motion_alternative: :instant_appear
    })
    
    # Scale animations
    create_animation(:scale_in, %{
      type: :scale,
      from: 0.5,
      to: 1.0,
      duration: 300,
      easing: :ease_out_elastic,
      reduced_motion_alternative: :instant_appear
    })
    
    create_animation(:scale_out, %{
      type: :scale,
      from: 1.0,
      to: 0.5,
      duration: 300,
      easing: :ease_in_cubic,
      reduced_motion_alternative: :instant_disappear
    })
    
    # Instant alternatives for reduced motion
    create_animation(:instant_appear, %{
      type: :generic,
      from: 0.0,
      to: 1.0,
      duration: 0,
      easing: :linear
    })
    
    create_animation(:instant_disappear, %{
      type: :generic,
      from: 1.0,
      to: 0.0,
      duration: 0,
      easing: :linear
    })
    
    # Focus ring animations
    create_animation(:focus_ring_appear, %{
      type: :generic,
      from: 0.0,
      to: 1.0,
      duration: 200,
      easing: :ease_out_quad,
      reduced_motion_alternative: :instant_appear
    })
    
    create_animation(:focus_ring_pulse, %{
      type: :generic,
      from: 0.8,
      to: 1.0,
      duration: 1000,
      easing: :ease_in_out_cubic,
      reduced_motion_alternative: :instant_appear
    })
  end
end 