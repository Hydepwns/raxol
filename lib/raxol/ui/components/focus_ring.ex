defmodule Raxol.UI.Components.FocusRing do
  @moduledoc """
  Handles drawing the focus ring around focused components.

  This component dynamically styles the focus ring based on:
  - Component state (focused, active, disabled)
  - User preferences (high contrast, reduced motion)
  - Theming settings
  - Animation effects
  """
  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component
  require Raxol.Core.Runtime.Log

  # Require View Elements macros
  require Raxol.View.Elements

  # Define state struct with enhanced styling options
  defstruct visible: true,
            # {x, y, width, height} of focused element
            position: nil,
            prev_position: nil,
            focused_element: nil,
            color: :yellow,
            thickness: 1,
            high_contrast: false,
            # :pulse, :blink, :fade, :glow, :bounce, :none
            animation: :pulse,
            # ms
            animation_duration: 500,
            animation_phase: 0,
            # total animation frames
            animation_frames: 100,
            # :fade, :slide, :grow, :none
            transition_effect: :fade,
            # {offset_x, offset_y}
            offset: {0, 0},
            style: %{},
            # button, text_input, checkbox, etc. - affects styling
            component_type: nil,
            # :normal, :active, :disabled
            state: :normal,
            # timestamp for animation timing
            last_tick: nil

  # --- Component Behaviour Callbacks ---

  @spec init(map()) :: %__MODULE__{}
  @impl true
  def init(opts) when is_map(opts) do
    # Initialize state from props, merging with defaults
    defaults = %{
      visible: true,
      color: :yellow,
      thickness: 1,
      high_contrast: false,
      animation: :pulse,
      animation_duration: 500,
      animation_frames: 100,
      transition_effect: :fade,
      offset: {0, 0},
      state: :normal,
      animation_phase: 0,
      last_tick: System.monotonic_time(:millisecond)
    }

    struct!(__MODULE__, Map.merge(defaults, opts))
  end

  @spec update(term(), %__MODULE__{}) :: {%__MODULE__{}, list()}
  @impl true
  def update(msg, state) do
    # Handle internal messages (animation ticks, focus changes)
    Raxol.Core.Runtime.Log.debug("FocusRing received message: #{inspect(msg)}")

    case msg do
      # Focus change with component type and state information
      {:focus_changed, _old_elem_id, new_elem_id, new_position, component_info} ->
        component_type = Map.get(component_info, :type, nil)
        component_state = Map.get(component_info, :state, :normal)

        {%{
           state
           | focused_element: new_elem_id,
             prev_position: state.position,
             position: new_position,
             animation_phase: 0,
             component_type: component_type,
             state: component_state,
             last_tick: System.monotonic_time(:millisecond)
         }, []}

      # Basic focus change without component info
      {:focus_changed, _old_elem_id, new_elem_id, new_position} ->
        {%{
           state
           | focused_element: new_elem_id,
             prev_position: state.position,
             position: new_position,
             animation_phase: 0,
             last_tick: System.monotonic_time(:millisecond)
         }, []}

      # Animation tick handling with timing
      {:animation_tick} ->
        current_time = System.monotonic_time(:millisecond)
        time_passed = current_time - (state.last_tick || current_time)

        # Calculate how many phases to advance based on time and duration
        phase_delta =
          trunc(
            time_passed / (state.animation_duration / state.animation_frames)
          )

        new_phase =
          rem(
            state.animation_phase + max(1, phase_delta),
            state.animation_frames
          )

        # Schedule next animation tick
        commands =
          if state.animation != :none and state.visible do
            # ~60fps
            [schedule({:animation_tick}, 16)]
          else
            []
          end

        {%{state | animation_phase: new_phase, last_tick: current_time},
         commands}

      # Allow external configuration updates
      {:configure, opts} when is_map(opts) ->
        new_state = Map.merge(state, opts)

        # Start animation if needed
        commands =
          if new_state.animation != :none and new_state.visible and
               (new_state.animation != state.animation or not state.visible) do
            [schedule({:animation_tick}, 16)]
          else
            []
          end

        {new_state, commands}

      _ ->
        {state, []}
    end
  end

  @spec handle_event(term(), map(), %__MODULE__{}) :: {%__MODULE__{}, list()}
  @impl true
  def handle_event(event, %{} = _props, state) do
    # FocusRing might listen to focus changes or accessibility events
    Raxol.Core.Runtime.Log.debug("FocusRing received event: #{inspect(event)}")

    case event do
      {:accessibility_high_contrast, enabled} ->
        {%{state | high_contrast: enabled}, []}

      {:accessibility_reduced_motion, enabled} ->
        animation = if enabled, do: :none, else: :pulse
        {%{state | animation: animation}, []}

      _ ->
        {state, []}
    end
  end

  # --- Render Logic ---

  @spec render(%__MODULE__{}, map()) :: any()
  @impl true
  def render(state, %{} = props) do
    dsl_result = render_focus_ring(state, props)
    # Result can be nil or a box element map
    if dsl_result do
      # Return element map directly
      dsl_result
    else
      # Render nothing if not visible or no position
      nil
    end
  end

  # --- Internal Render Helper ---

  defp render_focus_ring(state, props) do
    if state.visible and is_tuple(state.position) do
      # Extract position and apply offset
      {x, y, width, height} = state.position
      {offset_x, offset_y} = state.offset

      # Apply styling based on state, component type, and animation
      style_attrs = calculate_style_attributes(state, props)

      # Use View Elements box macro
      Raxol.View.Elements.box x: x + offset_x,
                              y: y + offset_y,
                              width: width,
                              height: height,
                              style: style_attrs do
        # Empty block needed as the macro expects it
      end
    else
      # Return nil if not visible or no position
      nil
    end
  end

  # Helper to calculate style attributes based on state
  defp calculate_style_attributes(state, props) do
    # Get theme configuration if available
    theme = Map.get(props, :theme, %{})

    # Base styling from component type
    base_style = get_component_specific_style(state.component_type, state.state)

    # Determine color based on high contrast, component type, and state
    color = determine_color(state, theme)

    # Apply animation effects
    animation_style = apply_animation_effects(state, color)

    # Merge all style attributes
    style_attrs = Map.merge(base_style, animation_style)

    # Apply theme overrides if present
    theme_overrides = Map.get(theme, :focus_ring, %{})
    Map.merge(style_attrs, theme_overrides)
  end

  # Determine appropriate color based on context
  defp determine_color(state, theme) do
    cond do
      # High contrast mode always uses high visibility colors
      state.high_contrast ->
        :white

      # Component state-based colors
      state.state == :disabled ->
        Map.get(theme, :disabled_color, :dark_gray)

      state.state == :active ->
        Map.get(theme, :active_color, :cyan)

      # Component type-specific colors
      state.component_type == :button ->
        Map.get(theme, :button_focus_color, :blue)

      state.component_type == :text_input ->
        Map.get(theme, :input_focus_color, :green)

      state.component_type == :checkbox ->
        Map.get(theme, :checkbox_focus_color, :magenta)

      # Default color from state or theme
      true ->
        state.color
    end
  end

  # Get component-specific styling
  defp get_component_specific_style(component_type, component_state) do
    base_style = %{border: :single}

    case {component_type, component_state} do
      {:button, :normal} ->
        %{border: :double, bold: true}

      {:text_input, :normal} ->
        %{border: :single, italic: false}

      {:checkbox, :normal} ->
        %{border: :single, bold: false}

      {_, :disabled} ->
        %{border: :dotted, bold: false}

      {_, :active} ->
        %{border: :double, bold: true}

      _ ->
        base_style
    end
  end

  # Apply animation effects based on animation type and phase
  defp apply_animation_effects(state, color) do
    case state.animation do
      :none ->
        %{border_color: color}

      :pulse ->
        # Pulse effect: varying opacity/intensity
        phase_percent = state.animation_phase / state.animation_frames
        # Simple sine wave for pulsing (0.7-1.0 intensity range)
        intensity = 0.7 + 0.3 * :math.sin(phase_percent * 2 * :math.pi())

        # Apply intensity through color - actual implementation would
        # handle this differently - this is a placeholder
        %{border_color: color, intensity: intensity}

      :blink ->
        # Blink effect: visible/invisible
        phase_percent = state.animation_phase / state.animation_frames
        visible = phase_percent < 0.5

        if visible do
          %{border_color: color}
        else
          # "Invisible" - would use transparency in real impl
          %{border_color: :black}
        end

      :glow ->
        # Glow effect: expanded border with gradient
        phase_percent = state.animation_phase / state.animation_frames
        glow_size = 1 + :math.sin(phase_percent * 2 * :math.pi()) * 0.5

        %{
          border_color: color,
          glow: true,
          glow_size: glow_size,
          glow_color: color
        }

      :bounce ->
        # Bounce effect: slight size changes
        phase_percent = state.animation_phase / state.animation_frames
        bounce_offset = :math.sin(phase_percent * 2 * :math.pi()) * 0.5

        %{
          border_color: color,
          offset_x: bounce_offset,
          offset_y: bounce_offset
        }

      :fade ->
        # Fade effect: color interpolation
        phase_percent = state.animation_phase / state.animation_frames
        # In a real implementation, would interpolate between colors
        %{border_color: color, opacity: 0.5 + phase_percent * 0.5}

      _ ->
        %{border_color: color}
    end
  end
end
