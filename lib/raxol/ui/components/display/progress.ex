defmodule Raxol.UI.Components.Display.Progress do
  @moduledoc """
  A progress bar component for displaying completion status.

  Features:
  * Customizable colors (harmonized style/theme prop merging)
  * Percentage display option
  * Custom width
  * Animated progress
  * Optional label
  * Accessibility/extra props (aria_label, tooltip, etc)
  * Robust lifecycle hooks (mount/unmount)
  """

  alias Raxol.UI.Components.Base.Component
  # alias Raxol.UI.Element # Unused
  # alias Raxol.UI.Layout.Constraints # Unused
  # alias Raxol.UI.Theming.Theme # Unused
  # alias Raxol.View
  # alias Raxol.UI.Theming.Colors
  # alias Raxol.View.Style
  # alias Raxol.View.Fragment

  import Raxol.Guards

  @behaviour Component

  @type props :: %{
          optional(:id) => String.t(),
          # 0.0 to 1.0
          optional(:progress) => float(),
          optional(:width) => integer(),
          optional(:show_percentage) => boolean(),
          optional(:label) => String.t(),
          optional(:theme) => map(),
          optional(:style) => map(),
          optional(:animated) => boolean(),
          optional(:aria_label) => String.t(),
          optional(:tooltip) => String.t()
        }

  @type state :: %{
          # props are merged into state
          :id => String.t() | nil,
          :progress => float(),
          :width => integer(),
          :show_percentage => boolean(),
          :label => String.t() | nil,
          :theme => map() | nil,
          :style => map() | nil,
          :animated => boolean(),
          # Internal state
          :animation_frame => integer(),
          # timestamp for animation
          :last_update => integer(),
          :aria_label => String.t() | nil,
          :tooltip => String.t() | nil
        }

  @animation_chars [" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"]
  # ms between frames
  @animation_speed 100

  @doc """
  Initializes the progress bar state from props.
  """
  @impl Component
  def init(props) do
    # Initialize state by merging normalized props with default internal state
    normalized_props = normalize_props(props)

    state =
      Map.merge(normalized_props, %{
        animation_frame: 0,
        last_update: System.monotonic_time(:millisecond)
      })

    {:ok, state}
  end

  @doc """
  Mounts the progress bar (for future extensibility: timers, subscriptions, etc).
  """
  @impl Component
  def mount(state), do: {state, []}

  @doc """
  Unmounts the progress bar (cleanup for future extensibility).
  """
  @impl Component
  def unmount(state), do: state

  @impl Component
  def update({:update_props, new_props}, state) do
    # Merge normalized new props into the current state
    norm_new = normalize_props(new_props)
    # Merge style and theme maps deeply
    updated_state =
      state
      |> Map.merge(norm_new, fn
        :style, old, new -> Map.merge(old || %{}, new || %{})
        :theme, old, new -> deep_merge(old || %{}, new || %{})
        _k, _old, new -> new
      end)

    # Handle animation tick based on the potentially updated state
    final_state = maybe_update_animation(updated_state)

    {:noreply, final_state, []}
  end

  # Handle the :tick message for animation
  def update(:tick, state) do
    updated_state = maybe_update_animation(state)
    {:noreply, updated_state, []}
  end

  # Ignore other messages
  def update(_message, state) do
    {:noreply, state, []}
  end

  # Helper to update animation frame if needed
  defp maybe_update_animation(state) do
    now = System.monotonic_time(:millisecond)
    time_diff = now - state.last_update

    if state.animated and time_diff >= @animation_speed do
      new_frame = rem(state.animation_frame + 1, length(@animation_chars))
      %{state | animation_frame: new_frame, last_update: now}
    else
      # No animation update needed
      state
    end
  end

  @impl Component
  def handle_event(_event, state, _context) do
    # Progress bar doesn't respond to events directly
    # Return the state and empty command list
    {state, []}
  end

  @impl Component
  def render(state, context) do
    # Harmonize theme merging: context.theme < state.theme < state.style
    context_theme = Map.get(context, :theme, %{})
    theme = Map.merge(context_theme, state.theme || %{})
    theme_style = Map.get(theme, :progress, %{})
    base_style = Map.merge(theme_style, state.style || %{})

    # Colors for bar, border, text
    fg = Map.get(base_style, :fg, :green)
    bg = Map.get(base_style, :bg, :black)
    border = Map.get(base_style, :border, :white)
    text_color = Map.get(base_style, :text, :white)

    progress = max(0.0, min(1.0, state.progress))
    width = max(3, state.width)
    filled_width = floor(progress * (width - 2))

    bar_content =
      generate_bar_content(
        filled_width,
        width - 2,
        base_style,
        state.animated,
        state.animation_frame
      )

    percentage_text =
      if state.show_percentage do
        percent_str = "#{floor(progress * 100)}%"
        padding = div(width - String.length(percent_str), 2)
        String.duplicate(" ", max(0, padding)) <> percent_str
      else
        ""
      end

    # Accessibility/extra attributes
    extra_attrs =
      %{
        aria_label: state.aria_label,
        tooltip: state.tooltip
      }
      |> Enum.reject(fn {_k, v} -> nil?(v) end)
      |> Enum.into(%{})

    # Elements list
    progress_elements = [
      # Border box
      %{
        type: :box,
        width: width,
        height: 1,
        attrs:
          Map.merge(
            %{
              fg: border,
              bg: bg,
              border: %{
                top_left: "[",
                top_right: "]",
                bottom_left: "[",
                bottom_right: "]",
                horizontal: " ",
                vertical: "|"
              }
            },
            extra_attrs
          )
      },
      # Progress fill
      %{
        type: :text,
        # Inside the border
        x: 1,
        y: 0,
        text: bar_content,
        attrs: %{
          fg: fg,
          bg: bg
        }
      }
    ]

    # Add percentage text if needed
    # Use state.show_percentage
    progress_elements =
      if state.show_percentage do
        text_element = %{
          type: :text,
          x: 1,
          y: 0,
          text: percentage_text,
          attrs: %{
            fg: text_color,
            # To show the bar underneath
            bg: :transparent
          }
        }

        # Prepend text element
        [text_element | progress_elements]
      else
        progress_elements
      end

    # Add label if provided
    # Use state.label
    progress_elements =
      if label = state.label do
        label_element = %{
          type: :text,
          x: 0,
          # Above the progress bar
          y: -1,
          text: label,
          attrs: %{
            fg: text_color,
            # Use main background color
            bg: bg
          }
        }

        # Prepend label element
        [label_element | progress_elements]
      else
        progress_elements
      end

    # Return the list of elements
    progress_elements
  end

  # Private helpers

  defp normalize_props(props) do
    # Ensure it's a map
    props = Map.new(props)

    # Ensure proper value ranges and defaults
    props
    # Allow nil ID
    |> Map.put_new_lazy(:id, fn -> nil end)
    |> Map.put_new(:progress, 0.0)
    |> Map.put_new(:width, 20)
    |> Map.put_new(:show_percentage, false)
    |> Map.put_new(:animated, false)
    |> Map.put_new(:label, nil)
    # Default theme to %{} instead of nil
    |> Map.put_new(:theme, %{})
    |> Map.put_new(:style, %{})
    |> Map.put_new(:aria_label, nil)
    |> Map.put_new(:tooltip, nil)
    # Clamp progress between 0.0 and 1.0
    |> Map.update!(:progress, &max(0.0, min(1.0, &1)))
    # Ensure minimum width for borders
    |> Map.update!(:width, &max(3, &1))
  end

  defp generate_bar_content(
         filled_width,
         total_width,
         # colors not used here? Check original code. Ok, not used.
         _base_style,
         animated,
         animation_frame
       ) do
    # Ensure widths are non-negative integers
    filled_width = max(0, floor(filled_width))
    total_width = max(0, floor(total_width))
    empty_width = max(0, total_width - filled_width)

    # For full blocks
    filled_part = String.duplicate("█", filled_width)

    # For empty space
    empty_part = String.duplicate(" ", empty_width)

    # If animated and not complete, add animation character at the edge
    if animated && filled_width < total_width do
      # Calculate animation character
      animation_char = Enum.at(@animation_chars, animation_frame)

      # Insert animation character at the transition point
      # Instead of String.slice(empty_part, 1..-1//-1), use String.slice(empty_part, 1, String.length(empty_part) - 1)
      trail =
        if empty_width > 0,
          do: String.slice(empty_part, 1, String.length(empty_part) - 1),
          else: ""

      filled_part <> animation_char <> trail
    else
      # No animation
      filled_part <> empty_part
    end
  end

  # Deep merge helper for nested maps (used for theme)
  defp deep_merge(map1, map2) when map?(map1) and map?(map2) do
    Map.merge(map1, map2, fn _k, v1, v2 ->
      if map?(v1) and map?(v2), do: deep_merge(v1, v2), else: v2
    end)
  end

  defp deep_merge(_map1, map2), do: map2

  # Optional callbacks provided by `use Component` if not defined:
  # def mount(state), do: {state, []}
  # def unmount(state), do: state
end
