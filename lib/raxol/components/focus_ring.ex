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
  @impl true
  # Expect map
  def init(opts) when is_map(opts) do
    # Extract options using Map.get
    visible = Map.get(opts, :visible, true)
    color = Map.get(opts, :color, :yellow)
    thickness = Map.get(opts, :thickness, 1)
    style = Map.get(opts, :style, [:dashed])
    high_contrast = Map.get(opts, :high_contrast, false)
    # :pulse, :blink, :none
    animation = Map.get(opts, :animation, :pulse)
    # milliseconds
    animation_duration = Map.get(opts, :animation_duration, 500)
    # :fade, :slide, :none
    transition_effect = Map.get(opts, :transition_effect, :fade)

    %{
      visible: visible,
      position: nil,
      prev_position: nil,
      focused_element: nil,
      color: color,
      thickness: thickness,
      style: style,
      high_contrast: high_contrast,
      animation: animation,
      animation_duration: animation_duration,
      animation_phase: 0,
      transition_effect: transition_effect,
      # Offset for rendering
      offset: {0, 0}
    }
  end

  @doc """
  Update focus ring state based on events.
  """
  @impl true
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
  @impl true
  def render(state) do
    dsl_result = render_focus_ring(state)
    # Result can be nil or a list containing nil/box, flatten and convert
    dsl_result
    |> List.wrap()
    |> List.flatten()
    |> Enum.reject(&is_nil(&1))
    |> Enum.map(&Raxol.View.to_element/1)
    |> case do
      # Return nil if nothing to render
      [] -> nil
      # Return single element if one exists
      [element] -> element
      # Wrap multiple in fragment
      elements -> Raxol.View.to_element(%{type: :fragment, children: elements})
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
  defp render_focus_ring(state) do
    # TODO: Add documentation for render_focus_ring/1
    # Define the visual representation of the focus ring
    shape = Map.get(state, :shape)
    text = if shape, do: "Focus Ring (#{shape})", else: nil

    box width: state.width,
        height: state.height,
        style: %{border: state.border_style} do
      if text do
        View.text(text)
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
