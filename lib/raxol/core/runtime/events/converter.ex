defmodule Raxol.Core.Runtime.Events.Converter do
  @moduledoc """
  Handles conversion between different event formats in the Raxol system.

  This module is responsible for:
  * Converting Termbox events to the Raxol event format
  * Converting VS Code events to the Raxol event format
  * Normalizing events into a consistent format
  """

  alias Raxol.Core.Events.Event
  import Bitwise

  @doc """
  Converts a Termbox event to the standardized Raxol event format.

  ## Parameters
  - `type`: The Termbox event type (e.g., :key, :resize)
  - `mod`: Key modifiers (if applicable)
  - `key`: The key code (for key events)
  - `ch`: The character (for character events)
  - `w`, `h`: Width and height (for resize events)

  ## Returns
  A structured `%Event{}` struct.
  """
  def convert_termbox_event(type, mod, key, ch, w \\ nil, h \\ nil) do
    case type do
      :key ->
        convert_termbox_key_event(mod, key, ch)

      :resize ->
        Event.new(:resize, %{
          width: w,
          height: h
        })

      :mouse ->
        convert_termbox_mouse_event(mod, key, ch, w, h)

      # Pass through other event types
      other ->
        Event.new(other, %{
          raw_event: {type, mod, key, ch, w, h}
        })
    end
  end

  @doc """
  Converts a VS Code extension event to the standardized Raxol event format.

  ## Parameters
  - `event`: The VS Code event map

  ## Returns
  A structured `%Event{}` struct.
  """
  def convert_vscode_event(event) do
    case event.type do
      "keydown" -> convert_vscode_keydown_event(event)
      "resize" -> convert_vscode_resize_event(event)
      "mouse" -> convert_vscode_mouse_event(event)
      "text" -> convert_vscode_text_event(event)
      "focus" -> convert_vscode_focus_event(event)
      "quit" -> Event.new(:quit, nil)
      _ -> Event.new(:unknown, %{raw_event: event})
    end
  end

  @doc """
  Normalizes events from various sources into a consistent format.

  This is useful when handling events from multiple backends to ensure
  they all follow the same structure before processing.

  ## Parameters
  - `event`: The event to normalize

  ## Returns
  A normalized `%Event{}` struct.
  """
  def normalize_event(event) do
    case event do
      %Event{} = e ->
        e

      {type, mod, key, ch, w, h} ->
        convert_termbox_event(type, mod, key, ch, w, h)

      %{type: _} = e ->
        convert_vscode_event(e)

      {:key, key} ->
        Event.new(:key, %{key: key})

      {:mouse, x, y, button} ->
        Event.new(:mouse, %{x: x, y: y, button: button})

      {:text, text} ->
        Event.new(:text, %{text: text})

      other ->
        Event.new(:unknown, %{raw_event: other})
    end
  end

  # Private functions

  defp convert_termbox_key_event(mod, key, ch) do
    modifiers = extract_key_modifiers(mod)

    # If ch is non-zero, it's a character key
    case ch do
      0 ->
        # It's a special key (function key, arrow, etc.)
        Event.new(:key, %{
          key: key,
          modifiers: modifiers
        })
      _ ->
        Event.new(:key, %{
          key: ch,
          key_code: key,
          modifiers: modifiers
        })
    end
  end

  defp convert_termbox_mouse_event(mod, key, ch, x, y) do
    button =
      case key do
        1 -> :left
        2 -> :middle
        3 -> :right
        _ -> :unknown
      end

    action =
      case ch do
        0 -> :press
        1 -> :release
        2 -> :drag
        _ -> :unknown
      end

    Event.new(:mouse, %{
      action: action,
      button: button,
      x: x,
      y: y,
      modifiers: extract_key_modifiers(mod)
    })
  end

  defp convert_vscode_keydown_event(%{key: key, modifiers: mods}) do
    convert_vscode_key_event(key, mods)
  end

  defp convert_vscode_resize_event(%{width: width, height: height}) do
    Event.new(:resize, %{width: width, height: height})
  end

  defp convert_vscode_mouse_event(%{action: action, x: x, y: y, button: button}) do
    convert_vscode_mouse_event(action, x, y, button)
  end

  defp convert_vscode_text_event(%{content: text}) do
    Event.new(:text, %{text: text})
  end

  defp convert_vscode_focus_event(%{focused: focused}) do
    Event.new(:focus, %{focused: focused})
  end

  defp convert_vscode_key_event(key, mods) do
    key_value = convert_vscode_key_to_value(key)
    modifiers = parse_vscode_modifiers(mods)

    Event.new(:key, %{
      key: key_value,
      raw_key: key,
      modifiers: modifiers
    })
  end

  @vscode_key_map %{
    "Enter" => :enter,
    "Escape" => :escape,
    "Backspace" => :backspace,
    "Tab" => :tab,
    "Space" => :space,
    "ArrowLeft" => :arrow_left,
    "ArrowRight" => :arrow_right,
    "ArrowUp" => :arrow_up,
    "ArrowDown" => :arrow_down
  }

  defp convert_vscode_key_to_value(key) do
    case key do
      k when is_binary(k) and byte_size(k) == 1 -> :binary.first(k)
      k when is_binary(k) -> k
      _ -> key
    end
    |> Map.get(@vscode_key_map, key)
  end

  @vscode_button_map %{
    "left" => :left,
    "middle" => :middle,
    "right" => :right
  }

  @vscode_action_map %{
    "down" => :press,
    "up" => :release,
    "move" => :move
  }

  defp convert_vscode_mouse_event(action, x, y, button) do
    button_atom = Map.get(@vscode_button_map, button, :unknown)
    action_atom = Map.get(@vscode_action_map, action, :unknown)

    Event.new(:mouse, %{
      action: action_atom,
      button: button_atom,
      x: x,
      y: y
    })
  end

  defp extract_key_modifiers(mod) do
    [
      ctrl: (mod &&& 1) != 0,
      alt: (mod &&& 2) != 0,
      shift: (mod &&& 4) != 0
    ]
  end

  defp parse_vscode_modifiers(mods) when is_list(mods) do
    ctrl = "ctrl" in mods or "control" in mods
    alt = "alt" in mods or "option" in mods
    shift = "shift" in mods
    meta = "meta" in mods or "command" in mods

    [
      ctrl: ctrl,
      alt: alt,
      shift: shift,
      meta: meta
    ]
  end

  defp parse_vscode_modifiers(_), do: []
end
