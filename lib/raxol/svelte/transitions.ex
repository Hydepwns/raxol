defmodule Raxol.Svelte.Transitions do
  @moduledoc """
  Svelte-style transitions and animations for Raxol components.

  Provides smooth enter/exit transitions and custom animations
  similar to Svelte's transition system.

  ## Example

      defmodule Modal do
        use Raxol.Svelte.Component
        use Raxol.Svelte.Transitions
        
        state :visible, false
        
        def render(assigns) do
          ~H'''
          {#if @visible}
            <Box 
              in:fade={{duration: 300}} 
              out:scale={{duration: 200, start: 0.8}}
              class="modal"
            >
              <Text>Modal content</Text>
            </Box>
          {/if}
          '''
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import Raxol.Svelte.Transitions

      @transitions %{}
      @animations %{}
      @before_compile Raxol.Svelte.Transitions
    end
  end

  @doc """
  Define a custom transition function.
  """
  defmacro transition(name, implementation) do
    quote do
      @transitions Map.put(@transitions, unquote(name), unquote(implementation))

      def unquote(name)(element, params \\ %{}) do
        transition_fn = @transitions[unquote(name)]
        transition_fn.(element, params)
      end
    end
  end

  @doc """
  Define a custom animation function.
  """
  defmacro animation(name, implementation) do
    quote do
      @animations Map.put(@animations, unquote(name), unquote(implementation))

      def unquote(name)(element, params \\ %{}) do
        animation_fn = @animations[unquote(name)]
        animation_fn.(element, params)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # Apply transitions during element lifecycle
      defp apply_transition(element, :enter, transition_name, params) do
        transition_fn = @transitions[transition_name]
        handle_enter_transition(transition_fn, element, transition_name, params)
      end

      defp handle_enter_transition(nil, element, transition_name, params) do
        Raxol.Svelte.Transitions.Builtin.apply_builtin_transition(
          element,
          transition_name,
          Map.put(params, :direction, :enter)
        )
      end

      defp handle_enter_transition(transition_fn, element, _transition_name, params) do
        transition_fn.(element, Map.put(params, :direction, :enter))
      end

      defp apply_transition(element, :exit, transition_name, params) do
        transition_fn = @transitions[transition_name]
        handle_exit_transition(transition_fn, element, transition_name, params)
      end

      defp handle_exit_transition(nil, element, transition_name, params) do
        Raxol.Svelte.Transitions.Builtin.apply_builtin_transition(
          element,
          transition_name,
          Map.put(params, :direction, :exit)
        )
      end

      defp handle_exit_transition(transition_fn, element, _transition_name, params) do
        transition_fn.(element, Map.put(params, :direction, :exit))
      end
    end
  end
end

defmodule Raxol.Svelte.Transitions.Builtin do
  @moduledoc """
  Built-in transition functions similar to Svelte's.
  """

  @doc """
  Fade transition - animates opacity.
  """
  def fade(element, params \\ %{}) do
    duration = Map.get(params, :duration, 300)
    easing = Map.get(params, :easing, :ease_in_out)
    delay = Map.get(params, :delay, 0)

    case Map.get(params, :direction, :enter) do
      :enter -> fade_in(element, duration, easing, delay)
      :exit -> fade_out(element, duration, easing, delay)
    end
  end

  @doc """
  Scale transition - animates size.
  """
  def scale(element, params \\ %{}) do
    duration = Map.get(params, :duration, 300)
    start = Map.get(params, :start, 0)
    easing = Map.get(params, :easing, :ease_out)

    case Map.get(params, :direction, :enter) do
      :enter -> scale_in(element, start, duration, easing)
      :exit -> scale_out(element, start, duration, easing)
    end
  end

  @doc """
  Slide transition - animates position.
  """
  def slide(element, params \\ %{}) do
    duration = Map.get(params, :duration, 300)
    axis = Map.get(params, :axis, :y)
    easing = Map.get(params, :easing, :ease_out)

    case Map.get(params, :direction, :enter) do
      :enter -> slide_in(element, axis, duration, easing)
      :exit -> slide_out(element, axis, duration, easing)
    end
  end

  @doc """
  Fly transition - animates from/to a direction.
  """
  def fly(element, params \\ %{}) do
    duration = Map.get(params, :duration, 300)
    x = Map.get(params, :x, 0)
    y = Map.get(params, :y, 0)
    opacity = Map.get(params, :opacity, 0)
    easing = Map.get(params, :easing, :ease_out)

    case Map.get(params, :direction, :enter) do
      :enter -> fly_in(element, x, y, opacity, duration, easing)
      :exit -> fly_out(element, x, y, opacity, duration, easing)
    end
  end

  @doc """
  Draw transition - draws element progressively.
  """
  def draw(element, params \\ %{}) do
    duration = Map.get(params, :duration, 800)
    easing = Map.get(params, :easing, :ease_in_out)

    case Map.get(params, :direction, :enter) do
      :enter -> draw_in(element, duration, easing)
      :exit -> draw_out(element, duration, easing)
    end
  end

  # Animation Implementations

  defp fade_in(element, duration, easing, delay) do
    animate(element, [
      {:opacity, 0, 1, duration, easing, delay}
    ])
  end

  defp fade_out(element, duration, easing, delay) do
    animate(element, [
      {:opacity, 1, 0, duration, easing, delay}
    ])
  end

  defp scale_in(element, start_scale, duration, easing) do
    animate(element, [
      {:scale_x, start_scale, 1, duration, easing, 0},
      {:scale_y, start_scale, 1, duration, easing, 0}
    ])
  end

  defp scale_out(element, end_scale, duration, easing) do
    animate(element, [
      {:scale_x, 1, end_scale, duration, easing, 0},
      {:scale_y, 1, end_scale, duration, easing, 0}
    ])
  end

  defp slide_in(element, axis, duration, easing) do
    case axis do
      :x ->
        start_x = element.x - element.width
        animate(element, [{:x, start_x, element.x, duration, easing, 0}])

      :y ->
        start_y = element.y - element.height
        animate(element, [{:y, start_y, element.y, duration, easing, 0}])
    end
  end

  defp slide_out(element, axis, duration, easing) do
    case axis do
      :x ->
        end_x = element.x + element.width
        animate(element, [{:x, element.x, end_x, duration, easing, 0}])

      :y ->
        end_y = element.y + element.height
        animate(element, [{:y, element.y, end_y, duration, easing, 0}])
    end
  end

  defp fly_in(element, from_x, from_y, from_opacity, duration, easing) do
    animate(element, [
      {:x, element.x + from_x, element.x, duration, easing, 0},
      {:y, element.y + from_y, element.y, duration, easing, 0},
      {:opacity, from_opacity, 1, duration, easing, 0}
    ])
  end

  defp fly_out(element, to_x, to_y, to_opacity, duration, easing) do
    animate(element, [
      {:x, element.x, element.x + to_x, duration, easing, 0},
      {:y, element.y, element.y + to_y, duration, easing, 0},
      {:opacity, 1, to_opacity, duration, easing, 0}
    ])
  end

  defp draw_in(element, duration, easing) do
    # Progressive drawing - useful for borders, lines, etc.
    animate(element, [
      {:draw_progress, 0, 1, duration, easing, 0}
    ])
  end

  defp draw_out(element, duration, easing) do
    animate(element, [
      {:draw_progress, 1, 0, duration, easing, 0}
    ])
  end

  # Core Animation System

  defp animate(element, keyframes) do
    animation_id = make_ref()

    # Start animation process
    {:ok, animator} =
      Raxol.Svelte.Animator.start_link(%{
        element: element,
        keyframes: keyframes,
        id: animation_id
      })

    # Update element with animation reference
    element
    |> Map.put(:animation_id, animation_id)
    |> Map.put(:animator, animator)
  end

  @doc """
  Apply built-in transition by name.
  """
  def apply_builtin_transition(element, name, params) do
    case name do
      :fade -> fade(element, params)
      :scale -> scale(element, params)
      :slide -> slide(element, params)
      :fly -> fly(element, params)
      :draw -> draw(element, params)
      _ -> element
    end
  end
end

defmodule Raxol.Svelte.Animator do
  @moduledoc """
  Animation execution engine.

  Handles the actual animation loop and property interpolation.
  """

  use GenServer

  def start_link(animation_spec) do
    GenServer.start_link(__MODULE__, animation_spec)
  end

  @impl GenServer
  def init(%{element: element, keyframes: keyframes, id: id}) do
    state = %{
      element: element,
      keyframes: keyframes,
      id: id,
      start_time: System.monotonic_time(:millisecond),
      active: true
    }

    # Start animation loop
    schedule_frame()

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:animate_frame, %{active: true} = state) do
    current_time = System.monotonic_time(:millisecond)
    elapsed = current_time - state.start_time

    # Calculate current values for all keyframes
    current_props = calculate_current_properties(state.keyframes, elapsed)

    # Apply to element (update terminal buffer)
    apply_animation_frame(state.element, current_props)

    # Check if animation is complete
    handle_animation_progress(animation_complete?(state.keyframes, elapsed), state)
  end

  @impl GenServer
  def handle_info(:animate_frame, state) do
    {:noreply, state}
  end

  defp handle_animation_progress(true, state) do
    # Animation finished
    {:stop, :normal, %{state | active: false}}
  end

  defp handle_animation_progress(false, state) do
    # Schedule next frame
    schedule_frame()
    {:noreply, state}
  end

  defp schedule_frame do
    # 60 FPS = ~16.67ms per frame
    Process.send_after(self(), :animate_frame, 16)
  end

  defp calculate_current_properties(keyframes, elapsed) do
    Enum.map(keyframes, fn {property, from, to, duration, easing, delay} ->
      calculate_keyframe_property(elapsed >= delay, property, from, to, duration, easing, delay, elapsed)
    end)
  end

  defp calculate_keyframe_property(false, property, from, _to, _duration, _easing, _delay, _elapsed) do
    {property, from}
  end

  defp calculate_keyframe_property(true, property, from, to, duration, easing, delay, elapsed) do
    progress = min((elapsed - delay) / duration, 1.0)
    eased_progress = apply_easing(progress, easing)
    current_value = interpolate(from, to, eased_progress)
    {property, current_value}
  end

  defp apply_easing(t, :linear), do: t
  defp apply_easing(t, :ease_in), do: t * t
  defp apply_easing(t, :ease_out), do: 1 - (1 - t) * (1 - t)

  defp apply_easing(t, :ease_in_out) do
    apply_ease_in_out(t < 0.5, t)
  end

  defp apply_easing(t, :bounce) do
    n1 = 7.5625
    d1 = 2.75
    calculate_bounce(t, n1, d1)
  end

  # Helper functions for ease_in_out
  defp apply_ease_in_out(true, t) do
    2 * t * t
  end

  defp apply_ease_in_out(false, t) do
    1 - :math.pow(-2 * t + 2, 2) / 2
  end

  defp calculate_bounce(t, n1, d1) when t < 1 / d1, do: n1 * t * t

  defp calculate_bounce(t, n1, d1) when t < 2 / d1,
    do: n1 * (t - 1.5 / d1) * (t - 1.5 / d1) + 0.75

  defp calculate_bounce(t, n1, d1) when t < 2.5 / d1,
    do: n1 * (t - 2.25 / d1) * (t - 2.25 / d1) + 0.9375

  defp calculate_bounce(t, n1, d1),
    do: n1 * (t - 2.625 / d1) * (t - 2.625 / d1) + 0.984375

  defp interpolate(from, to, progress) when is_number(from) and is_number(to) do
    from + (to - from) * progress
  end

  defp interpolate(from, to, progress) when is_tuple(from) and is_tuple(to) do
    # Interpolate tuples (e.g., colors)
    from_list = Tuple.to_list(from)
    to_list = Tuple.to_list(to)

    interpolated =
      Enum.zip_with(from_list, to_list, fn f, t ->
        interpolate(f, t, progress)
      end)

    List.to_tuple(interpolated)
  end

  defp apply_animation_frame(element, properties) do
    # Update the terminal buffer with new property values
    Enum.each(properties, fn {property, value} ->
      apply_property_update(element, property, value)
    end)
  end

  defp apply_property_update(element, :x, value) do
    # TODO: Implement when Terminal.Buffer.move_element is available
    # Raxol.Terminal.Buffer.move_element(element, round(value), element.y)
    Map.put(element, :x, round(value))
  end

  defp apply_property_update(element, :y, value) do
    # TODO: Implement when Terminal.Buffer.move_element is available
    # Raxol.Terminal.Buffer.move_element(element, element.x, round(value))
    Map.put(element, :y, round(value))
  end

  defp apply_property_update(element, :opacity, value) do
    # TODO: Implement when Terminal.Buffer.set_element_opacity is available
    # Raxol.Terminal.Buffer.set_element_opacity(element, value)
    Map.put(element, :opacity, value)
  end

  defp apply_property_update(element, :scale_x, value) do
    new_width = round(Map.get(element, :original_width, element.width) * value)
    # TODO: Implement when Terminal.Buffer.resize_element is available
    # Raxol.Terminal.Buffer.resize_element(element, new_width, element.height)
    Map.put(element, :width, new_width)
  end

  defp apply_property_update(element, :scale_y, value) do
    new_height =
      round(Map.get(element, :original_height, element.height) * value)

    # TODO: Implement when Terminal.Buffer.resize_element is available  
    # Raxol.Terminal.Buffer.resize_element(element, element.width, new_height)
    Map.put(element, :height, new_height)
  end

  defp apply_property_update(_element, _property, _value) do
    # Ignore unknown properties
    :ok
  end

  defp animation_complete?(keyframes, elapsed) do
    Enum.all?(keyframes, fn {_, _, _, duration, _, delay} ->
      elapsed >= delay + duration
    end)
  end

  # Default GenServer callbacks to satisfy behaviour requirements
  @impl GenServer
  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, _state) do
    :ok
  end

  @impl GenServer
  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end
end
