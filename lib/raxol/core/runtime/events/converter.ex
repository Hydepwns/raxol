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
    case event do
      %{type: "keydown", key: key, modifiers: mods} ->
        convert_vscode_key_event(key, mods)

      %{type: "resize", width: width, height: height} ->
        Event.new(:resize, %{
          width: width,
          height: height
        })

      %{type: "mouse", action: action, x: x, y: y, button: button} ->
        convert_vscode_mouse_event(action, x, y, button)

      %{type: "text", content: text} ->
        Event.new(:text, %{
          text: text
        })

      %{type: "focus", focused: focused} ->
        Event.new(:focus, %{
          focused: focused
        })

      %{type: "quit"} ->
        Event.new(:quit, nil)

      # For unknown events, just wrap the original
      other ->
        Event.new(:unknown, %{
          raw_event: other
        })
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
      # Already an Event struct
      %Event{} = e ->
        e

      # Termbox style event tuple
      {type, mod, key, ch, w, h} ->
        convert_termbox_event(type, mod, key, ch, w, h)

      # VS Code style event map
      %{type: _} = e ->
        convert_vscode_event(e)

      # Simple message events
      {:key, key} ->
        Event.new(:key, %{key: key})

      {:mouse, x, y, button} ->
        Event.new(:mouse, %{x: x, y: y, button: button})

      {:text, text} ->
        Event.new(:text, %{text: text})

      # Unknown format - wrap as is
      other ->
        Event.new(:unknown, %{raw_event: other})
    end
  end

  # Private functions

  defp convert_termbox_key_event(mod, key, ch) do
    modifiers = extract_key_modifiers(mod)

    # If ch is non-zero, it's a character key
    if ch != 0 do
      Event.new(:key, %{
        key: ch,
        key_code: key,
        modifiers: modifiers
      })
    else
      # It's a special key (function key, arrow, etc.)
      Event.new(:key, %{
        key: key,
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

  defp convert_vscode_key_event(key, mods) do
    # Convert key string to atom or code
    key_value =
      case key do
        "Enter" ->
          :enter

        "Escape" ->
          :escape

        "Backspace" ->
          :backspace

        "Tab" ->
          :tab

        "Space" ->
          :space

        "ArrowLeft" ->
          :arrow_left

        "ArrowRight" ->
          :arrow_right

        "ArrowUp" ->
          :arrow_up

        "ArrowDown" ->
          :arrow_down

        # For regular characters, use the first character's code point
        _ when is_binary(key) and byte_size(key) == 1 ->
          :binary.first(key)

        _ ->
          key
      end

    # Convert modifiers
    modifiers = parse_vscode_modifiers(mods)

    Event.new(:key, %{
      key: key_value,
      raw_key: key,
      modifiers: modifiers
    })
  end

  defp convert_vscode_mouse_event(action, x, y, button) do
    # Convert button string to atom
    button_atom =
      case button do
        "left" -> :left
        "middle" -> :middle
        "right" -> :right
        _ -> :unknown
      end

    # Convert action string to atom
    action_atom =
      case action do
        "down" -> :press
        "up" -> :release
        "move" -> :move
        _ -> :unknown
      end

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
