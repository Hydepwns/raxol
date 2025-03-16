defmodule Raxol.Examples.Button do
  @moduledoc """
  A sample button component that demonstrates various testable features.

  This component includes:
  - Click handling
  - Disabled state
  - Visual styling
  - Responsive layout
  - Theme support
  """

  use Raxol.Component

  alias Raxol.Core.Renderer.Element

  @default_theme %{
    normal: %{fg: :blue, bg: :white, style: :bold},
    disabled: %{fg: :gray, bg: :white, style: :dim},
    pressed: %{fg: :blue, bg: :white, style: :reverse}
  }

  def init(props) do
    state = %{
      label: Map.get(props, :label, "Button"),
      disabled: Map.get(props, :disabled, false),
      pressed: false,
      on_click: Map.get(props, :on_click, fn -> :ok end),
      theme: Map.get(props, :theme, @default_theme)
    }

    {:ok, state}
  end

  def handle_event({:click, _pos} = event, state) do
    if state.disabled do
      {state, []}
    else
      {
        %{state | pressed: true},
        [:clicked, state.on_click.()]
      }
    end
  end

  def handle_event({:resize, _} = event, state) do
    # Handle resize events gracefully
    {state, []}
  end

  def handle_event(:focus, state) do
    {state, []}
  end

  def handle_event(:blur, state) do
    {state, []}
  end

  def handle_event(:trigger_error, _state) do
    raise "Simulated error for testing"
  end

  def render(state) do
    style = get_style(state)
    content = render_content(state)

    %Element{
      tag: :button,
      content: content,
      style: style,
      attributes: %{
        disabled: state.disabled,
        pressed: state.pressed
      }
    }
  end

  # Private Helpers

  defp get_style(%{disabled: true} = state) do
    state.theme.disabled
  end

  defp get_style(%{pressed: true} = state) do
    state.theme.pressed
  end

  defp get_style(state) do
    state.theme.normal
  end

  defp render_content(state) do
    # Add box drawing characters for borders
    top = "┌" <> String.duplicate("─", String.length(state.label) + 2) <> "┐"
    middle = "│ " <> state.label <> " │"
    bottom = "└" <> String.duplicate("─", String.length(state.label) + 2) <> "┘"

    [top, middle, bottom]
    |> Enum.join("\n")
  end
end 