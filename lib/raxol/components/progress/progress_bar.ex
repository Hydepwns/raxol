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
  alias Raxol.View.Components
  alias Raxol.View.Layout

  @default_width 20
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

  def update(_msg, state), do: state

  @impl true
  def render(state) do
    Layout.column do
      _label =
        Components.text(content: state.label, color: state.style.text_color)

      bar =
        Layout.box style: %{border_color: state.style.border_color} do
          _filled =
            Components.text(
              content: String.duplicate("█", state.filled_width),
              color: state.style.fill_color
            )

          Components.text(
            content: String.duplicate("░", state.empty_width),
            color: state.style.empty_color
          )
        end

      [bar]
    end
  end

  @impl true
  def handle_event(
        %{type: :progress_update, data: %{value: value}} = _event,
        state
      )
      when is_number(value) do
    {update(:set_value, state, value), []}
  end

  def handle_event(_event, state), do: {state, []}

  # Public API for controlling the progress bar
  def set_progress(value)
      when is_number(value) and value >= 0 and value <= 100 do
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

  defp update(:set_value, state, value) when is_number(value) do
    %{state | value: value}
  end
end
