defmodule Raxol.Components.FocusRing do
  use Raxol.Component
  alias Raxol.Core.Events.Manager, as: EventManager
  require Raxol.View
  import Raxol.View
  alias Raxol.View

  @moduledoc """
  A component that provides visual indication of the currently focused element.

  The focus ring appears around the element that currently has focus, providing
  visual feedback to the user about which element they are interacting with.

  This component integrates with `Raxol.Core.FocusManager` to track focused elements.

  ## Features

  * Multiple visual styles (solid, dotted, dashed, double)
  * Customizable colors and thickness
  * Animation effects (pulse, glow, rotate, blink)
  * High contrast mode for accessibility
  * Custom offsets for fine-tuning appearance
  * Direct integration with focus management system

  ## Usage

  ```elixir
  # In your app configuration
  alias Raxol.Components.FocusRing

  # Configure the focus ring appearance
  FocusRing.configure(style: :dotted, color: :blue)

  # The focus ring will be automatically applied to the focused element
  ```
  """

  # Define module attributes for colors
  @focus_color :cyan
  @idle_color :gray

  @doc """
  Configure the appearance of the focus ring.

  ## Options

  * `:style` - Border style of the focus ring (`:solid`, `:dotted`, `:dashed`, `:double`) (default: `:solid`)
  * `:color` - Color of the focus ring (default: `:blue`)
  * `:thickness` - Thickness of the focus ring (default: `1`)
  * `:offset` - Offset from the focused element (default: `0`)
  * `:animation` - Animation effect (`:none`, `:pulse`, `:glow`, `:rotate`, `:blink`) (default: `:none`)
  * `:high_contrast` - Use high contrast mode for better visibility (default: `false`)
  * `:animation_duration` - Duration of animation in milliseconds (default: `1000`)
  * `:transition_effect` - Effect when moving between elements (`:none`, `:fade`, `:slide`) (default: `:none`)

  ## Examples

      iex> FocusRing.configure(style: :dotted, color: :blue)
      :ok

      iex> FocusRing.configure(animation: :pulse, high_contrast: true)
      :ok
  """
  def configure(opts \\ []) do
    current_config = get_config()
    updated_config = Keyword.merge(current_config, opts)
    Process.put(:focus_ring_config, updated_config)
    :ok
  end

  @doc """
  Initialize the focus ring component.

  This function is called when the component is first created.
  """
  def init(opts \\ []) do
    # Register for focus events
    EventManager.register_handler(
      :focus_change,
      __MODULE__,
      :handle_focus_change
    )

    %{
      visible: Keyword.get(opts, :visible, true),
      style: Keyword.get(opts, :style, :solid),
      color: Keyword.get(opts, :color, :blue),
      thickness: Keyword.get(opts, :thickness, 1),
      offset: Keyword.get(opts, :offset, 0),
      animation: Keyword.get(opts, :animation, :none),
      high_contrast: Keyword.get(opts, :high_contrast, false),
      animation_duration: Keyword.get(opts, :animation_duration, 1000),
      transition_effect: Keyword.get(opts, :transition_effect, :none),
      animation_phase: 0,
      focused_element: nil,
      position: nil,
      prev_position: nil
    }
  end

  @doc """
  Update focus ring state based on events.
  """
  def update(model, msg) do
    case msg do
      {:focus_change, _old_focus, new_focus} ->
        # Get the position of the newly focused element
        position = get_element_position(new_focus)

        # Store previous position for transition animations
        prev_position = model.position

        # Reset animation phase when focus changes
        %{
          model
          | focused_element: new_focus,
            position: position,
            prev_position: prev_position,
            animation_phase: 0
        }

      {:toggle_visibility} ->
        %{model | visible: !model.visible}

      {:set_style, style} ->
        %{model | style: style}

      {:set_color, color} ->
        %{model | color: color}

      {:set_animation, animation} ->
        %{model | animation: animation}

      {:set_high_contrast, high_contrast} ->
        %{model | high_contrast: high_contrast}

      {:set_animation_duration, duration}
      when is_integer(duration) and duration > 0 ->
        %{model | animation_duration: duration}

      {:set_transition_effect, effect} when effect in [:none, :fade, :slide] ->
        %{model | transition_effect: effect}

      {:animation_tick} ->
        # Update animation phase for continuous animations
        new_phase = rem(model.animation_phase + 1, 100)
        %{model | animation_phase: new_phase}

      _ ->
        model
    end
  end

  @doc """
  Render the focus ring around the currently focused element.

  ## Examples

      iex> FocusRing.render(model)
      # Renders a focus ring around the currently focused element
  """
  def render(model, _opts \\ []) do
    if model.visible && model.focused_element && model.position do
      # Render transition effect if applicable
      if model.transition_effect != :none && model.prev_position != nil &&
           model.prev_position != model.position do
        [
          render_transition_effect(model),
          render_focus_ring(model)
        ]
      else
        render_focus_ring(model)
      end
    else
      # Return empty element when no focus or not visible
      []
    end
  end

  @doc """
  Subscribe to relevant events for the focus ring.
  """
  def subscriptions(model) do
    events = [{:focus_change, :global}]

    # Subscribe to animation ticks if using animation
    if model.animation != :none do
      [{:animation_tick, 16} | events]
    else
      events
    end
  end

  @doc """
  Handle focus change events.
  """
  def handle_focus_change(_state, {old_focus, new_focus}) do
    # TODO: Implement focus change handling
    {old_focus, new_focus}
  end

  @doc """
  Set the focus ring style for a specific component type.

  This allows customizing the focus ring appearance based on component type.

  ## Examples

      iex> FocusRing.set_component_style(:button, style: :solid, color: :green)
      :ok
  """
  def set_component_style(component_type, style_opts)
      when is_atom(component_type) do
    component_styles = Process.get(:focus_ring_component_styles) || %{}
    updated_styles = Map.put(component_styles, component_type, style_opts)
    Process.put(:focus_ring_component_styles, updated_styles)
    :ok
  end

  @doc """
  Get the focus ring style for a specific component type.

  ## Examples

      iex> FocusRing.get_component_style(:button)
      [style: :solid, color: :green]
  """
  def get_component_style(component_type) when is_atom(component_type) do
    component_styles = Process.get(:focus_ring_component_styles) || %{}
    Map.get(component_styles, component_type, [])
  end

  @doc """
  Cleans up resources used by the FocusRing.
  """
  def cleanup() do
    # Unsubscribe from focus events
    EventManager.unregister_handler(
      :focus_change,
      __MODULE__,
      :handle_focus_change
    )

    Process.delete(:focus_ring_config)
    Process.delete(:focus_ring_component_styles)
    :ok
  end

  # Private functions

  defp get_config do
    Process.get(:focus_ring_config) || default_config()
  end

  defp default_config do
    [
      style: :solid,
      color: :blue,
      thickness: 1,
      offset: 0,
      animation: :none,
      high_contrast: false,
      animation_duration: 1000,
      transition_effect: :none
    ]
  end

  @dialyzer {:nowarn_function, render_focus_ring: 1}
  def render_focus_ring(state) do
    # TODO: Add documentation for render_focus_ring/1
    # Define the visual representation of the focus ring
    shape = Map.get(state, :shape)
    text = if shape, do: "Focus Ring (#{shape})", else: nil

    box [
      width: state.width,
      height: state.height,
      style: %{border: state.border_style}
    ] do
      if text do
        View.text(text)
      end
    end
  end

  # Renders the transition effect based on the animation state
  defp render_transition_effect(%{progress: progress, style: style} = _state) do
    if progress > 0.0 and progress < 1.0 do
      # Calculate interpolated color based on progress
      # In a real animation system, progress would be managed
      _start_color = @idle_color
      _end_color = Map.get(style, :end_color, @focus_color) # Use attribute

      color =
        if progress == 1.0 do
          @focus_color # Use attribute
        else
          # start_color = @idle_color
          # end_color = @focus_color
          # Raxol.Animation.interpolate_color(start_color, end_color, progress)
          # TODO: Re-enable when Animation module exists
          @focus_color # Temporary: Use focus color immediately
        end

      box [
        id: "focus_transition",
        style: %{color: color},
        border_color: color
      ] do
        # No children needed here
      end
    end
  end

  defp get_element_position(element_id) do
    # Check if we have a custom position for this specific element
    custom_positions = Process.get(:focus_ring_custom_positions) || %{}

    if Map.has_key?(custom_positions, element_id) do
      Map.get(custom_positions, element_id)
    else
      # Otherwise, use the global element position registry
      element_registry = Process.get(:element_position_registry) || %{}

      case Map.get(element_registry, element_id) do
        # Default position if element not found
        nil -> {0, 0, 0, 0}
        position -> position
      end
    end
  end

  @doc """
  Register a custom position for a specific element.

  ## Examples

      iex> FocusRing.register_custom_position("special_button", {10, 20, 100, 30})
      :ok
  """
  def register_custom_position(element_id, position = {_x, _y, _width, _height}) do
    custom_positions = Process.get(:focus_ring_custom_positions) || %{}
    updated_positions = Map.put(custom_positions, element_id, position)
    Process.put(:focus_ring_custom_positions, updated_positions)
    :ok
  end

  @doc """
  Enable or disable high contrast mode for accessibility.

  ## Examples

      iex> FocusRing.set_high_contrast(true)
      :ok
  """
  def set_high_contrast(enabled) when is_boolean(enabled) do
    configure(high_contrast: enabled)
  end
end
