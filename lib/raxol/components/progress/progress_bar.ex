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
  alias Raxol.Core.Style.Color

  @default_width 20
  @default_style :basic
  @default_color :blue
  @default_characters %{filled: "=", empty: "-"}
  @block_characters %{filled: "█", empty: "░"}

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

  def update({:set_style, style}, state) when style in [:basic, :block, :custom] do
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

  def update(_msg, state), do: state

  @impl true
  def render(state) do
    filled_width = trunc(state.width * state.value / 100)
    empty_width = state.width - filled_width

    {filled_char, empty_char} = get_characters(state)
    
    filled = if state.gradient do
      build_gradient_bar(filled_char, filled_width, state.gradient)
    else
      text(content: String.duplicate(filled_char, filled_width), color: state.color)
    end

    empty = text(content: String.duplicate(empty_char, empty_width))
    
    percentage = if state.show_percentage do
      text(content: " #{state.value}%")
    else
      nil
    end

    label = if state.label do
      text(content: "#{state.label} ")
    else
      nil
    end

    box do
      row do
        label
        text(content: "[")
        filled
        empty
        text(content: "]")
        percentage
      end
    end
  end

  defp get_characters(state) do
    case state.style do
      :basic -> {@default_characters.filled, @default_characters.empty}
      :block -> {@block_characters.filled, @block_characters.empty}
      :custom -> 
        chars = state.characters || @default_characters
        {chars.filled, chars.empty}
    end
  end

  defp build_gradient_bar(char, width, colors) do
    segments = length(colors) - 1
    chars_per_segment = width / segments

    colors
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index()
    |> Enum.map(fn {[c1, c2], i} ->
      segment_width = trunc(chars_per_segment)
      segment_start = trunc(i * chars_per_segment)
      segment = String.duplicate(char, segment_width)
      text(content: segment, color: c1)
    end)
  end

  @impl true
  def handle_event(%Event{type: :progress_update, value: value}, state) when is_number(value) do
    {update({:set_progress, value}, state), []}
  end

  def handle_event(_event, state), do: {state, []}

  # Public API for controlling the progress bar
  def set_progress(value) when is_number(value) and value >= 0 and value <= 100 do
    {:progress_update, value}
  end

  def set_style(style) when style in [:basic, :block, :custom] do
    {:set_style, style}
  end

  def set_color(color) do
    {:set_color, color}
  end

  def set_gradient(colors) when is_list(colors) do
    {:set_gradient, colors}
  end

  def set_characters(filled, empty) do
    {:set_characters, %{filled: filled, empty: empty}}
  end
end 