defmodule Raxol.UI.Components.Progress.Indeterminate do
  @moduledoc """
  Handles indeterminate progress components.
  """

  require Raxol.View.Elements

  @spec render_indeterminate(map()) :: any()
  def render_indeterminate(state) do
    indeterminate(
      state.frame_index,
      id: Map.get(state, :id),
      width: Map.get(state, :width, 20),
      style: state.style,
      bar_style: Map.get(state, :bar_style, %{bg: :blue}),
      background_style: Map.get(state, :background_style, %{bg: :black}),
      segment_size: Map.get(state, :segment_size, 5)
    )
  end

  @spec indeterminate(integer(), keyword()) :: any()
  @doc """
  Renders an indeterminate progress bar (animated).

  ## Parameters

  * `frame` - Current animation frame (integer, typically incremented on each render)
  * `opts` - Options for customizing the indeterminate progress bar

  ## Options

  * `:id` - Unique identifier for the progress bar (default: "indeterminate_progress")
  * `:width` - Width of the progress bar in characters (default: 20)
  * `:style` - Style for the progress bar container
  * `:bar_style` - Style for the animated bar (default: %{bg: :blue})
  * `:background_style` - Style for the background (default: %{bg: :black})
  * `:segment_size` - Size of the animated segment (default: 5)

  ## Returns

  A view element representing the indeterminate progress bar.

  ## Example

  ```elixir
  Progress.Indeterminate.indeterminate(
    model.animation_frame,
    width: 30,
    bar_style: %{bg: :purple},
    segment_size: 8
  )
  ```
  """
  def indeterminate(frame, opts \\ []) do
    # Extract options with defaults
    id = Keyword.get(opts, :id, "indeterminate_progress")
    width = Keyword.get(opts, :width, 20)
    style = Keyword.get(opts, :style, %{})
    bar_style = Keyword.get(opts, :bar_style, %{bg: :blue})
    background_style = Keyword.get(opts, :background_style, %{bg: :black})
    segment_size = Keyword.get(opts, :segment_size, 5)

    # Ensure segment size is not larger than total width
    segment_size = min(segment_size, width)

    # Calculate position of the animated segment
    current_position = calculate_position(frame, width, segment_size)

    # Create the indeterminate progress bar
    Raxol.View.Elements.row([id: id, style: style],
      do: fn ->
        create_indeterminate_elements(
          current_position,
          segment_size,
          width,
          bar_style,
          background_style
        )
      end
    )
  end

  # Helper functions
  defp calculate_position(frame, width, segment_size) do
    total_frames = width * 2 - segment_size * 2
    pos = rem(frame, total_frames)
    calculate_final_position(pos, width, segment_size, total_frames)
  end

  defp create_indeterminate_elements(
         current_position,
         segment_size,
         width,
         bar_style,
         background_style
       ) do
    left_width = current_position
    bar_width = segment_size
    right_width = width - bar_width - left_width

    elements = []

    elements =
      add_left_element_if_needed(left_width, elements, background_style)

    elements = [
      Raxol.View.Elements.label(
        content: String.duplicate(" ", bar_width),
        style: bar_style
      )
      | elements
    ]

    elements =
      add_right_element_if_needed(right_width, elements, background_style)

    Enum.reverse(elements)
  end

  # Helper functions for pattern matching instead of if statements

  defp calculate_final_position(pos, width, segment_size, total_frames) do
    case pos < width - segment_size do
      true -> pos
      false -> total_frames - pos
    end
  end

  defp add_left_element_if_needed(0, elements, _background_style), do: elements

  defp add_left_element_if_needed(left_width, elements, background_style)
       when left_width > 0 do
    [
      Raxol.View.Elements.label(
        content: String.duplicate(" ", left_width),
        style: background_style
      )
      | elements
    ]
  end

  defp add_right_element_if_needed(0, elements, _background_style), do: elements

  defp add_right_element_if_needed(right_width, elements, background_style)
       when right_width > 0 do
    [
      Raxol.View.Elements.label(
        content: String.duplicate(" ", right_width),
        style: background_style
      )
      | elements
    ]
  end
end
