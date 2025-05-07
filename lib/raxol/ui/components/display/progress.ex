defmodule Raxol.UI.Components.Display.Progress do
  @moduledoc """
  A progress bar component for displaying completion status.

  Features:
  * Customizable colors
  * Percentage display option
  * Custom width
  * Animated progress
  * Optional label
  """

  alias Raxol.UI.Components.Base.Component
  # alias Raxol.UI.Element # Unused
  # alias Raxol.UI.Layout.Constraints # Unused
  # alias Raxol.UI.Theming.Theme # Unused
  # alias Raxol.View
  # alias Raxol.UI.Theming.Colors
  # alias Raxol.View.Style
  # alias Raxol.View.Fragment

  @behaviour Component

  @type props :: %{
          optional(:id) => String.t(),
          # 0.0 to 1.0
          optional(:progress) => float(),
          optional(:width) => integer(),
          optional(:show_percentage) => boolean(),
          optional(:label) => String.t(),
          optional(:theme) => map(),
          optional(:animated) => boolean()
        }

  @type state :: %{
          # props are merged into state
          :id => String.t() | nil,
          :progress => float(),
          :width => integer(),
          :show_percentage => boolean(),
          :label => String.t() | nil,
          :theme => map() | nil,
          :animated => boolean(),
          # Internal state
          :animation_frame => integer(),
          # timestamp for animation
          :last_update => integer()
        }

  @animation_chars [" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"]
  # ms between frames
  @animation_speed 100

  @impl Component
  def init(props) do
    # Initialize state by merging normalized props with default internal state
    normalized_props = normalize_props(props)

    state = Map.merge(normalized_props, %{
      animation_frame: 0,
      last_update: System.monotonic_time(:millisecond)
    })
    {:ok, state}
  end

  @impl Component
  def update({:update_props, new_props}, state) do
    # Merge normalized new props into the current state
    updated_state = Map.merge(state, normalize_props(new_props))

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
  def render(state, _context) do
    # Access props directly from state map
    progress = state.progress
    width = state.width
    # Use the component's theme if set, otherwise the global theme
    theme = state.theme || Raxol.UI.Theming.Theme.default_theme()

    colors =
      Map.get(theme, :progress, %{
        fg: :green,
        bg: :black,
        border: :white,
        text: :white
      })

    # Calculate the filled width
    filled_width = floor(progress * (width - 2))

    # Generate progress bar content
    bar_content =
      generate_bar_content(
        filled_width,
        width - 2,
        colors,
        # Use state.animated
        state.animated,
        # Use state.animation_frame
        state.animation_frame
      )

    # Create percentage text if needed
    # Use state.show_percentage
    percentage_text =
      if state.show_percentage do
        percent_str = "#{floor(progress * 100)}%"
        # Center the percentage text in the bar
        padding = div(width - String.length(percent_str), 2)
        String.duplicate(" ", max(0, padding)) <> percent_str
      else
        ""
      end

    # Elements list
    progress_elements = [
      # Border box
      %{
        type: :box,
        width: width,
        height: 1,
        attrs: %{
          fg: colors.border,
          bg: colors.bg,
          border: %{
            top_left: "[",
            top_right: "]",
            bottom_left: "[",
            bottom_right: "]",
            horizontal: " ",
            vertical: "|"
          }
        }
      },
      # Progress fill
      %{
        type: :text,
        # Inside the border
        x: 1,
        y: 0,
        text: bar_content,
        attrs: %{
          fg: colors.fg,
          bg: colors.bg
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
            fg: colors.text,
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
            fg: colors.text,
            # Use main background color
            bg: colors.bg
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
    # Allow nil theme initially
    |> Map.put_new_lazy(:theme, fn -> nil end)
    # Clamp progress between 0.0 and 1.0
    |> Map.update!(:progress, &max(0.0, min(1.0, &1)))
    # Ensure minimum width for borders
    |> Map.update!(:width, &max(3, &1))
  end

  defp generate_bar_content(
         filled_width,
         total_width,
         # colors not used here? Check original code. Ok, not used.
         _colors,
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
      # Need slicing adjustment if empty_part is ""
      trail =
        if empty_width > 0, do: String.slice(empty_part, 1..-1//-1), else: ""

      filled_part <> animation_char <> trail
    else
      # No animation
      filled_part <> empty_part
    end
  end

  # Optional callbacks provided by `use Component` if not defined:
  # def mount(state), do: {state, []}
  # def unmount(state), do: state
end
