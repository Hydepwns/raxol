defmodule Raxol.Examples.FocusRingShowcase do
  @moduledoc """
  Showcase for the enhanced FocusRing component with various styling options.

  This example demonstrates:
  - Different animation types (pulse, blink, fade, glow, bounce)
  - Component-specific styling (button, text_input, checkbox)
  - State-based styling (normal, active, disabled)
  - Accessibility integration (high contrast mode, reduced motion)
  """
  use Raxol.UI.Components.Base.Component
  require Raxol.Core.Runtime.Log
  require Raxol.View.Elements
  import Raxol.View.Elements

  @animation_types [:none, :pulse, :blink, :fade, :glow, :bounce]
  @component_types [:button, :text_input, :checkbox]
  @component_states [:normal, :active, :disabled]

  @impl Raxol.UI.Components.Base.Component
  def init(_props) do
    %{
      # Current selections
      current_animation: :pulse,
      current_component_type: :button,
      current_component_state: :normal,
      high_contrast: false,
      reduced_motion: false,

      # Focus ring state
      focus_ring: %{
        visible: true,
        # Initial position
        position: {5, 5, 30, 5},
        color: :yellow,
        animation: :pulse,
        component_type: :button,
        state: :normal,
        high_contrast: false
      },

      # Timer for auto-cycling demo
      demo_running: false,
      cycle_index: 0,

      # Input values for demo components
      button_text: "Button Example",
      input_value: "Text input example",
      checkbox_checked: true
    }
  end

  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    case msg do
      # Animation cycle for demo mode
      {:demo_cycle} ->
        next_index = rem(state.cycle_index + 1, length(@animation_types))
        next_animation = Enum.at(@animation_types, next_index)

        # Also cycle component type every full animation cycle
        next_component_type =
          case next_index == 0 do
            true ->
              cycle_next_in_list(state.current_component_type, @component_types)
            false ->
              state.current_component_type
          end

        # Update focus ring
        updated_focus_ring =
          Map.merge(state.focus_ring, %{
            animation: next_animation,
            component_type: next_component_type
          })

        # Schedule next cycle if demo is running
        commands =
          case state.demo_running do
            true ->
              [schedule({:demo_cycle}, 2000)]
            false ->
              []
          end

        {%{
           state
           | current_animation: next_animation,
             current_component_type: next_component_type,
             cycle_index: next_index,
             focus_ring: updated_focus_ring
         }, commands}

      _ ->
        {state, []}
    end
  end

  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, _props, state) do
    case event do
      # Animation type selection
      {:select_animation, animation} when animation in @animation_types ->
        updated_focus_ring = Map.put(state.focus_ring, :animation, animation)

        {%{
           state
           | current_animation: animation,
             focus_ring: updated_focus_ring
         }, []}

      # Component type selection
      {:select_component_type, component_type}
      when component_type in @component_types ->
        updated_focus_ring =
          Map.put(state.focus_ring, :component_type, component_type)

        {%{
           state
           | current_component_type: component_type,
             focus_ring: updated_focus_ring
         }, []}

      # Component state selection
      {:select_component_state, component_state}
      when component_state in @component_states ->
        updated_focus_ring = Map.put(state.focus_ring, :state, component_state)

        {%{
           state
           | current_component_state: component_state,
             focus_ring: updated_focus_ring
         }, []}

      # Toggle high contrast mode
      {:toggle_high_contrast} ->
        high_contrast = !state.high_contrast

        updated_focus_ring =
          Map.put(state.focus_ring, :high_contrast, high_contrast)

        {%{
           state
           | high_contrast: high_contrast,
             focus_ring: updated_focus_ring
         }, []}

      # Toggle reduced motion
      {:toggle_reduced_motion} ->
        reduced_motion = !state.reduced_motion
        # When reduced motion is enabled, set animation to :none
        animation = if reduced_motion, do: :none, else: state.current_animation
        updated_focus_ring = Map.put(state.focus_ring, :animation, animation)

        {%{
           state
           | reduced_motion: reduced_motion,
             focus_ring: updated_focus_ring
         }, []}

      # Toggle auto-cycling demo
      {:toggle_demo} ->
        demo_running = !state.demo_running

        # Start or stop the cycle timer
        commands =
          case demo_running do
            true ->
              [schedule({:demo_cycle}, 2000)]
            false ->
              []
          end

        {%{state | demo_running: demo_running}, commands}

      # Position focus ring on a component
      {:focus_component, component_type, position} ->
        updated_focus_ring =
          Map.merge(state.focus_ring, %{
            component_type: component_type,
            position: position
          })

        {%{
           state
           | current_component_type: component_type,
             focus_ring: updated_focus_ring
         }, []}

      _ ->
        {state, []}
    end
  end

  @impl Raxol.UI.Components.Base.Component
  def render(state, _context) do
    panel title: "FocusRing Component Showcase", border: :single, width: 80 do
      column padding: 1, gap: 1 do
        # Description
        label(
          text:
            "This showcase demonstrates the enhanced FocusRing component with various styling options."
        )

        # Controls section
        panel title: "Controls", border: :single do
          column padding: 1, gap: 1 do
            row gap: 2 do
              # Animation type selector
              column do
                label(text: "Animation Type:")

                for animation <- @animation_types do
                  button(
                    label: to_string(animation),
                    on_click: {:select_animation, animation},
                    style:
                      if(state.current_animation == animation,
                        do: [bg: :blue, fg: :white],
                        else: []
                      )
                  )
                end
              end

              # Component type selector
              column do
                label(text: "Component Type:")

                for component_type <- @component_types do
                  button(
                    label: to_string(component_type),
                    on_click: {:select_component_type, component_type},
                    style:
                      if(state.current_component_type == component_type,
                        do: [bg: :blue, fg: :white],
                        else: []
                      )
                  )
                end
              end

              # Component state selector
              column do
                label(text: "Component State:")

                for component_state <- @component_states do
                  button(
                    label: to_string(component_state),
                    on_click: {:select_component_state, component_state},
                    style:
                      if(state.current_component_state == component_state,
                        do: [bg: :blue, fg: :white],
                        else: []
                      )
                  )
                end
              end

              # Accessibility options
              column do
                label(text: "Accessibility:")

                button(
                  label: "High Contrast: #{state.high_contrast}",
                  on_click: {:toggle_high_contrast}
                )

                button(
                  label: "Reduced Motion: #{state.reduced_motion}",
                  on_click: {:toggle_reduced_motion}
                )
              end
            end

            # Auto-cycle demo
            row do
              button(
                label:
                  if(state.demo_running,
                    do: "Stop Demo",
                    else: "Start Auto-Cycle Demo"
                  ),
                on_click: {:toggle_demo},
                style:
                  if(state.demo_running,
                    do: [bg: :red, fg: :white],
                    else: [bg: :green, fg: :white]
                  )
              )
            end
          end
        end

        # Component display section
        panel title: "Preview", border: :single do
          column padding: 1, gap: 2 do
            # Current configuration
            label(text: "Current Configuration:")

            label(
              text:
                "Animation: #{state.current_animation}, Component: #{state.current_component_type}, State: #{state.current_component_state}"
            )

            label(
              text:
                "High Contrast: #{state.high_contrast}, Reduced Motion: #{state.reduced_motion}"
            )

            # Example components
            row gap: 4 do
              # Button example
              button(
                label: state.button_text,
                on_click: {:focus_component, :button, {5, 20, 20, 3}}
              )

              # Text input example
              text_input(
                value: state.input_value,
                on_click: {:focus_component, :text_input, {30, 20, 25, 3}}
              )

              # Checkbox example
              checkbox(
                checked: state.checkbox_checked,
                label: "Check me",
                on_click: {:focus_component, :checkbox, {60, 20, 15, 3}}
              )
            end
          end
        end

        # Focus ring component
        %{
          type: Raxol.UI.Components.FocusRing,
          id: :focus_ring,
          assigns: state.focus_ring
        }
      end
    end
  end

  # Helper function to cycle to the next item in a list
  defp cycle_next_in_list(current, list) do
    current_index = Enum.find_index(list, fn x -> x == current end) || 0
    next_index = rem(current_index + 1, length(list))
    Enum.at(list, next_index)
  end
end
