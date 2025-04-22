defmodule Raxol.Core.Events.TermboxConverter do
  @moduledoc """
  Handles conversion of raw termbox event data to Raxol.Core.Events.Event.
  """

  alias Raxol.Core.Events.Event
  alias ExTermbox.Constants
  import Bitwise

  # Event Conversion from Raw Data

  @doc """
  Converts raw termbox event data into a Raxol event.
  Accepts the decoded tuple elements from the poller.
  """
  @spec convert(
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer()
        ) ::
          Event.t()
  def convert(type_int, mod, key, ch, w, h, x, y) do
    case type_int do
      # Key event
      1 ->
        # Pass mod, key, ch to helpers
        raxol_key = map_key_code(key, ch)
        modifiers = map_modifiers(mod)
        Event.key_event(raxol_key, :pressed, modifiers)

      # Resize event
      2 ->
        Event.window_event(w, h, :resize)

      # Mouse event
      3 ->
        # Pass mod, key, x, y to helpers
        # key is button code for mouse
        button = map_button_code(key)
        modifiers = map_modifiers(mod)
        Event.mouse_event(button, {x, y}, :pressed, modifiers)

      # Unknown event type
      _ ->
        Event.new(:unknown, {type_int, mod, key, ch, w, h, x, y})
    end
  end

  # --- Private Conversion Helpers (Adjusted) ---

  # Requires constants from ExTermbox.Constants
  # Takes key_code and char_code
  defp map_key_code(key_code, char_code) do
    # Prioritize char_code if present (non-zero)
    if char_code > 0 do
      <<char_code>>
    else
      # Use key_code for special keys
      cond do
        key_code == Constants.key(:f1) -> :f1
        key_code == Constants.key(:f2) -> :f2
        key_code == Constants.key(:f3) -> :f3
        key_code == Constants.key(:f4) -> :f4
        key_code == Constants.key(:f5) -> :f5
        key_code == Constants.key(:f6) -> :f6
        key_code == Constants.key(:f7) -> :f7
        key_code == Constants.key(:f8) -> :f8
        key_code == Constants.key(:f9) -> :f9
        key_code == Constants.key(:f10) -> :f10
        key_code == Constants.key(:f11) -> :f11
        key_code == Constants.key(:f12) -> :f12
        key_code == Constants.key(:insert) -> :insert
        key_code == Constants.key(:delete) -> :delete
        key_code == Constants.key(:home) -> :home
        key_code == Constants.key(:end) -> :end
        key_code == Constants.key(:pgup) -> :page_up
        key_code == Constants.key(:pgdn) -> :page_down
        key_code == Constants.key(:arrow_up) -> :up
        key_code == Constants.key(:arrow_down) -> :down
        key_code == Constants.key(:arrow_left) -> :left
        key_code == Constants.key(:arrow_right) -> :right
        # May need adjustment
        key_code == Constants.key(:ctrl_tilde) -> {:ctrl, :tilde}
        # ... map other special keys ...
        key_code == Constants.key(:esc) -> :escape
        key_code == Constants.key(:enter) -> :enter
        key_code == Constants.key(:space) -> :space
        # Or KEY_BACKSPACE?
        key_code == Constants.key(:backspace2) -> :backspace
        key_code == Constants.key(:tab) -> :tab
        true -> {:unknown_key, key_code}
      end
    end
  end

  # Takes modifier integer
  defp map_modifiers(mod) do
    # Modifier constants seem to be missing from ExTermbox.Constants?
    mods = []
    # 0x4 for Shift
    mods = if band(mod, 4) != 0, do: [:shift | mods], else: mods
    # 0x8 for Alt
    mods = if band(mod, 8) != 0, do: [:alt | mods], else: mods
    # 0x10 for Ctrl
    mods = if band(mod, 16) != 0, do: [:ctrl | mods], else: mods
    Enum.reverse(mods)
  end

  # Takes mouse button integer code
  defp map_button_code(button_code) do
    cond do
      button_code == Constants.key(:mouse_left) -> :left
      button_code == Constants.key(:mouse_right) -> :right
      button_code == Constants.key(:mouse_middle) -> :middle
      button_code == Constants.key(:mouse_wheel_up) -> :wheel_up
      button_code == Constants.key(:mouse_wheel_down) -> :wheel_down
      # Termbox might send release as a separate key event, not button code
      # button_code == ExTermbox.Constants.key(:mouse_release) -> :release
      # Return atom instead of nil
      true -> :unknown_button
    end
  end
end
