defmodule Raxol.UI.Components.Input.MultiLineInput.EventHandler do
  @moduledoc """
  Event handler for MultiLineInput component.
  Handles keyboard input and navigation events.
  """

  alias Raxol.Core.Events.Event
  alias Raxol.UI.Components.Input.MultiLineInput

  @doc """
  Handles events for the MultiLineInput component.
  """
  @spec handle_event(Event.t(), MultiLineInput.t()) ::
          {:update, term(), MultiLineInput.t()}
          | {:noreply, MultiLineInput.t()}
          | term()
  def handle_event(
        %Event{type: :key, data: %{key: key, modifiers: modifiers}},
        state
      ) do
    dispatch_key(key, modifiers, state)
  end

  def handle_event(
        %Event{
          type: :mouse,
          data: %{button: :left, state: :pressed, position: {x, y}}
        },
        state
      ) do
    # Handle mouse click to move cursor (coordinates are swapped: y becomes row, x becomes col)
    {:update, {:move_cursor_to, {y, x}}, state}
  end

  def handle_event(%Event{type: :mouse}, state) do
    # Handle other mouse events (drag, release, etc.)
    {:noreply, state}
  end

  def handle_event(_event, state) do
    # Default case for other event types
    {:noreply, state, nil}
  end

  # Character input
  defp dispatch_key(char, [], state)
       when is_binary(char) and byte_size(char) == 1,
       do: {:update, {:input, char}, state}

  # Editing keys
  defp dispatch_key(:enter, [], state), do: {:update, {:enter}, state}
  defp dispatch_key(:backspace, [], state), do: {:update, {:backspace}, state}
  defp dispatch_key(:delete, [], state), do: {:update, {:delete}, state}
  defp dispatch_key(:tab, [], state), do: {:update, {:input, ?\t}, state}

  # Arrow keys (no modifier)
  defp dispatch_key(:up, [], state), do: {:update, {:move_cursor, :up}, state}

  defp dispatch_key(:down, [], state),
    do: {:update, {:move_cursor, :down}, state}

  defp dispatch_key(:left, [], state),
    do: {:update, {:move_cursor, :left}, state}

  defp dispatch_key(:right, [], state),
    do: {:update, {:move_cursor, :right}, state}

  # Arrow keys with shift (selection)
  defp dispatch_key(:up, [:shift], state),
    do: {:update, {:selection_move, :up}, state}

  defp dispatch_key(:down, [:shift], state),
    do: {:update, {:selection_move, :down}, state}

  defp dispatch_key(:left, [:shift], state),
    do: {:update, {:selection_move, :left}, state}

  defp dispatch_key(:right, [:shift], state),
    do: {:update, {:selection_move, :right}, state}

  # Home/End
  defp dispatch_key(:home, [], state),
    do: {:update, {:move_cursor_line_start}, state}

  defp dispatch_key(:end, [], state),
    do: {:update, {:move_cursor_line_end}, state}

  # Page up/down (both variants)
  defp dispatch_key(k, [], state) when k in [:page_up, :pageup],
    do: {:update, {:move_cursor_page, :up}, state}

  defp dispatch_key(k, [], state) when k in [:page_down, :pagedown],
    do: {:update, {:move_cursor_page, :down}, state}

  # Ctrl combinations
  defp dispatch_key("a", [:ctrl], state), do: {:update, {:select_all}, state}
  defp dispatch_key("c", [:ctrl], state), do: {:update, {:copy}, state}
  defp dispatch_key("v", [:ctrl], state), do: {:update, {:paste}, state}
  defp dispatch_key("x", [:ctrl], state), do: {:update, {:cut}, state}
  defp dispatch_key("z", [:ctrl], state), do: {:update, :undo, state}
  defp dispatch_key("y", [:ctrl], state), do: {:update, :redo, state}

  # Default case
  defp dispatch_key(_key, _modifiers, state), do: {:noreply, state, nil}
end
