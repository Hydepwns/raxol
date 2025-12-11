defmodule Raxol.UI.Components.Progress.Component do
  @moduledoc """
  Core progress component implementation.

  Provides the base functionality for progress indicators including
  initialization, rendering, and event handling.
  """

  @type state :: %{
          value: number(),
          max: number(),
          type: atom(),
          indeterminate: boolean(),
          frame: integer()
        }

  @type props :: map()

  @doc """
  Initializes the progress component state.
  """
  @spec init(props()) :: state()
  def init(props) do
    %{
      value: Map.get(props, :value, 0),
      max: Map.get(props, :max, 100),
      type: Map.get(props, :type, :bar),
      indeterminate: Map.get(props, :indeterminate, false),
      frame: 0
    }
  end

  @doc """
  Updates the component state.
  """
  @spec update(term(), state()) :: state()
  def update({:set_value, value}, state) do
    %{state | value: min(value, state.max)}
  end

  def update({:set_max, max}, state) do
    %{state | max: max, value: min(state.value, max)}
  end

  def update(:tick, %{indeterminate: true} = state) do
    %{state | frame: state.frame + 1}
  end

  def update(_, state), do: state

  @doc """
  Handles component events.
  """
  @spec handle_event(term(), props(), state()) :: {:ok, state()}
  def handle_event({:click, _}, _props, state) do
    {:ok, state}
  end

  def handle_event({:key, _key}, _props, state) do
    {:ok, state}
  end

  def handle_event(_, _, state), do: {:ok, state}

  @doc """
  Renders the progress component.
  """
  @spec render(state(), props()) :: binary()
  def render(%{type: :bar} = state, props) do
    render_bar(state, props)
  end

  def render(%{type: :circular} = state, props) do
    render_circular(state, props)
  end

  def render(%{type: :spinner} = state, props) do
    render_spinner(state, props)
  end

  def render(state, props) do
    render_bar(state, props)
  end

  @doc """
  Returns available spinner types.
  """
  @spec spinner_types() :: list(atom())
  def spinner_types do
    [:dots, :line, :circle, :square, :arrow, :bounce, :pulse]
  end

  # Private rendering functions

  defp render_bar(%{value: value, max: max, indeterminate: false}, props) do
    width = Map.get(props, :width, 20)
    percentage = value / max * 100
    filled = round(width * value / max)
    empty = width - filled

    bar_char = Map.get(props, :bar_char, "=")
    empty_char = Map.get(props, :empty_char, " ")

    "[#{String.duplicate(bar_char, filled)}#{String.duplicate(empty_char, empty)}] #{round(percentage)}%"
  end

  defp render_bar(%{frame: frame, indeterminate: true}, props) do
    width = Map.get(props, :width, 20)
    position = rem(frame, width * 2)
    position = if position > width, do: width * 2 - position, else: position

    bar =
      for i <- 0..(width - 1) do
        if abs(i - position) <= 2, do: "=", else: " "
      end

    "[#{Enum.join(bar)}]"
  end

  defp render_circular(%{value: value, max: max}, _props) do
    percentage = round(value / max * 100)
    segments = 8
    filled = round(segments * value / max)

    circle_chars = [" ", ".", "o", "O"]
    char_index = min(3, div(filled * 4, segments))

    "(#{Enum.at(circle_chars, char_index)}) #{percentage}%"
  end

  defp render_spinner(%{frame: frame}, props) do
    type = Map.get(props, :spinner_type, :dots)
    frames = get_spinner_frames(type)
    frame_index = rem(frame, length(frames))

    Enum.at(frames, frame_index)
  end

  defp get_spinner_frames(:dots), do: [".", "..", "..."]
  defp get_spinner_frames(:line), do: ["-", "\\", "|", "/"]
  defp get_spinner_frames(:circle), do: ["o", "O", "0", "O"]
  defp get_spinner_frames(:square), do: ["[", "=", "]", "="]
  defp get_spinner_frames(:arrow), do: ["<", "^", ">", "v"]
  defp get_spinner_frames(:bounce), do: ["( )", "(.)", "( )"]
  defp get_spinner_frames(:pulse), do: ["_", "-", "=", "-"]
  defp get_spinner_frames(_), do: [".", "o", "O", "o"]
end
