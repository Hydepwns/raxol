defmodule Raxol.Components.FocusRing do
  @moduledoc """
  Handles drawing the focus ring around focused components.
  """
  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component
  require Logger

  # Require View Elements macros
  require Raxol.View.Elements

  # Define state struct
  defstruct visible: true,
            position: nil, # {x, y, width, height} of focused element
            prev_position: nil,
            focused_element: nil,
            color: :yellow,
            thickness: 1,
            high_contrast: false,
            animation: :pulse, # :pulse, :blink, :none
            animation_duration: 500, # ms
            animation_phase: 0,
            transition_effect: :fade, # :fade, :slide, :none
            offset: {0, 0}, # {offset_x, offset_y}
            style: %{}

  # --- Component Behaviour Callbacks ---

  # Use @impl true for component callbacks
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
      transition_effect: :fade,
      offset: {0, 0}
    }
    struct!(__MODULE__, Map.merge(defaults, opts))
  end

  @impl true
  def update(msg, state) do
    # Handle internal messages (animation ticks, focus changes maybe)
    Logger.debug("FocusRing received message: #{inspect msg}")
    case msg do
      # Example: Focus change info could be passed via message
      {:focus_changed, _old_elem_id, new_elem_id, new_position} ->
        %{state | focused_element: new_elem_id, prev_position: state.position, position: new_position, animation_phase: 0}
      {:animation_tick} ->
        new_phase = rem(state.animation_phase + 1, 100)
        {%{state | animation_phase: new_phase}, []}
      # Allow external configuration updates
      {:configure, opts} when is_list(opts) ->
        new_state = Keyword.merge(state, opts)
        {new_state, []}
      _ -> {state, []}
    end
  end

  @impl true
  def handle_event(event, %{} = _props, state) do
    # FocusRing might not directly handle primary events, but could listen to focus changes
    # Or it could receive :focus_change messages via update/2
    Logger.debug("FocusRing received event: #{inspect event}")
    {state, []}
  end

  # --- Render Logic ---

  @impl true
  def render(state, %{} = _props) do # Correct arity
    dsl_result = render_focus_ring(state)
    # Result can be nil or a box element map
    if dsl_result do
      dsl_result # Return element map directly
    else
      nil # Render nothing if not visible or no position
    end
  end

  # --- Internal Render Helper ---

  defp render_focus_ring(state) do
    if state.visible and is_tuple(state.position) do
      # Extract position and apply offset
      {x, y, width, height} = state.position
      {offset_x, offset_y} = state.offset

      # TODO: Determine effective style based on high_contrast, animation, component type
      effective_color = if state.high_contrast, do: :white, else: state.color
      # Convert style list to atom if needed by box macro
      effective_border_style = hd(List.wrap(state.style)) # Example: take first style

      # Use View Elements box macro (requires Raxol.View.Elements)
      Raxol.View.Elements.box x: x + offset_x,
                             y: y + offset_y,
                             width: width,
                             height: height,
                             style: [
                               border: effective_border_style,
                               border_color: effective_color
                               # TODO: Apply thickness, animation effects (might need more complex rendering)
                             ] do
        # Empty block needed as the macro expects it
      end
    else
      nil # Return nil if not visible or no position map
    end
  end

  # --- Other Functions (Potentially move or make part of update/init) ---

  # Removed old render/1 function
  # Removed old subscriptions/1 (subscriptions handled by runtime/application)
  # Removed old handle_focus_change/2
  # Removed old set/get_component_style (config via init/update)
  # Removed old cleanup (lifecycle handled by runtime)
  # Removed configure/1 (use update({:configure, opts}, state))
  # Removed set_high_contrast (use update({:configure, [high_contrast: true]}, state))
  # Removed register_custom_position
  # Removed get_element_position (position passed via :focus_changed message)

  # Removed default_config (integrated into init)
  # Removed get_config (state holds config)

end
