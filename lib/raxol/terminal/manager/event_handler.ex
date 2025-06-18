defmodule Raxol.Terminal.Manager.EventHandler do
  @moduledoc '''
  Handles terminal events and dispatches them to appropriate handlers.
  '''

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator

  @doc '''
  Handles a terminal event.
  '''
  def handle_event(emulator, event) do
    case event do
      {:key_press, key, modifiers} ->
        handle_key_press(emulator, key, modifiers)
      {:key_release, key, modifiers} ->
        handle_key_release(emulator, key, modifiers)
      {:mouse_click, button, x, y} ->
        handle_mouse_click(emulator, button, x, y)
      {:mouse_drag, button, x, y} ->
        handle_mouse_drag(emulator, button, x, y)
      {:mouse_release, button, x, y} ->
        handle_mouse_release(emulator, button, x, y)
      {:focus_gain} ->
        handle_focus_gain(emulator)
      {:focus_loss} ->
        handle_focus_loss(emulator)
      _ ->
        {:error, :unknown_event}
    end
  end

  # Private helper functions

  defp handle_key_press(emulator, key, modifiers) do
    {:ok, updated_emulator, _commands} = Emulator.Input.process_key_press(emulator, key, modifiers)
    {:ok, updated_emulator}
  end

  defp handle_key_release(emulator, key, modifiers) do
    {:ok, updated_emulator, _commands} = Emulator.Input.process_key_release(emulator, key, modifiers)
    {:ok, updated_emulator}
  end

  defp handle_mouse_click(emulator, button, x, y) do
    {:ok, updated_emulator, _commands} = Emulator.Input.process_mouse_event(emulator, %{
      type: :mouse_click,
      button: button,
      x: x,
      y: y
    })
    {:ok, updated_emulator}
  end

  defp handle_mouse_drag(emulator, button, x, y) do
    {:ok, updated_emulator, _commands} = Emulator.Input.process_mouse_event(emulator, %{
      type: :mouse_drag,
      button: button,
      x: x,
      y: y
    })
    {:ok, updated_emulator}
  end

  defp handle_mouse_release(emulator, button, x, y) do
    {:ok, updated_emulator, _commands} = Emulator.Input.process_mouse_event(emulator, %{
      type: :mouse_release,
      button: button,
      x: x,
      y: y
    })
    {:ok, updated_emulator}
  end

  defp handle_focus_gain(emulator) do
    {:ok, emulator}
  end

  defp handle_focus_loss(emulator) do
    {:ok, emulator}
  end

  def process_event(event, state), do: {state, event}
end
