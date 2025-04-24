defmodule Raxol.Components.Progress.ProgressBar do
  @moduledoc """
  A progress bar component that displays progress as a horizontal bar.

  ## Props
    * `:value` - Current progress value (0-100)
    * `:width` - Width of the progress bar in characters (default: 20)
    * `:style` - Style of the progress bar (default: :basic)
      * `:basic` - Uses simple ASCII characters
      * `:block` - Uses block characters for smoother appearance
      * `:custom` - Uses custom characters provided in `:characters`
    * `:color` - Color of the progress bar (default: :blue)
    * `:gradient` - List of colors to create a gradient effect (overrides :color)
    * `:characters` - Map with :filled and :empty characters for custom style
    * `:show_percentage` - Whether to show percentage value (default: true)
    * `:label` - Optional label to show before the progress bar
  """

  use Raxol.Component
  require Raxol.View
  alias Raxol.View.Layout
  alias Raxol.View.Components

  @default_width 40
  @default_style :basic
  @default_color :blue

  @impl true
  def init(props) do
    %{
      value: props[:value] || 0,
      width: props[:width] || @default_width,
      style: props[:style] || @default_style,
      color: props[:color] || @default_color,
      gradient: props[:gradient],
      characters: props[:characters],
      show_percentage: Map.get(props, :show_percentage, true),
      label: props[:label]
    }
  end

  @impl true
  def update({:set_progress, value}, state) when value >= 0 and value <= 100 do
    %{state | value: value}
  end

  def update({:set_style, style}, state)
      when style in [:basic, :block, :custom] do
    %{state | style: style}
  end

  def update({:set_color, color}, state) do
    %{state | color: color, gradient: nil}
  end

  def update({:set_gradient, colors}, state) when is_list(colors) do
    %{state | gradient: colors, color: nil}
  end

  def update({:set_characters, chars}, state) when is_map(chars) do
    %{state | characters: chars}
  end

  # Catch-all clause to match Component behavior
  def update(_msg, state), do: state

  @impl true
  @dialyzer {:nowarn_function, render: 1}
  def render(state) do
    # Determine bar characters based on style
    {filled_char, empty_char} =
      case state.style.type do
        :block ->
          {"█", "░"}

        :ascii ->
          {"#", "-"}

        :custom ->
          {state.style.custom_chars.filled, state.style.custom_chars.empty}

        # Default to block
        _ ->
          {"█", "░"}
      end

    # Calculate filled/empty segments
    percentage = state.value / state.total
    filled_width = round(percentage * state.width)
    empty_width = state.width - filled_width

    # Build the bar text
    bar_text =
      String.duplicate(filled_char, filled_width) <>
        String.duplicate(empty_char, empty_width)

    # Determine colors
    # Example default
    bar_fg = Map.get(state.style, :fg, :green)
    bar_bg = Map.get(state.style, :bg, nil)

    # Generate the DSL map AND convert to element in one step
    # Layout: [Label] [Progress Bar] [Percentage Text]
    dsl_result =
      Layout.column do
        label_element =
          if state.label do
            Components.text(state.label, style: state.style.label_style)
          else
            nil
          end

        bar_row =
          Layout.row style: %{width: :auto} do
            percentage_element =
              if state.show_percentage do
                percentage_text = format_percentage(state.value, state.total)

                Components.text(" #{percentage_text}",
                  style: state.style.percentage_style
                )
              else
                nil
              end

            # Explicitly return list for row's children, filtering nil
            [
              # Progress Bar Segment
              Layout.box style: %{width: state.width, bg: bar_bg} do
                # Explicitly return list for box's children
                [Components.text(bar_text, style: %{fg: bar_fg})]
              end,
              # Percentage Text Segment (if enabled)
              percentage_element
            ]
            |> Enum.reject(&is_nil(&1))
          end

        # Explicitly return list for column's children, filtering nil
        [label_element, bar_row] |> Enum.reject(&is_nil(&1))
      end

    # Convert DSL map to Element struct
    Raxol.View.to_element(dsl_result)
  end

  @impl true
  def handle_event(
        %{type: :progress_update, data: %{value: value}} = _event,
        state
      )
      when is_number(value) do
    {update(:set_value, state, value), []}
  end

  # Default clause for other events
  def handle_event(_event, state), do: {state, []}

  # Update function (internal)
  defp update(:set_value, state, value) do
    new_value = clamp(value, state.total)
    %{state | value: new_value}
  end

  # Helper functions (clamp, format_percentage, etc.)
  defp clamp(value, max, min \\ 0) do
    value |> Kernel.max(min) |> Kernel.min(max)
  end

  defp format_percentage(value, total) do
    percentage = round(value / total * 100)
    "#{percentage}%"
  end
end
