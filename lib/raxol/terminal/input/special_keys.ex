defmodule Raxol.Terminal.Input.SpecialKeys do
  @moduledoc """
  Handles special key combinations and their escape sequences.

  This module provides functionality for:
  - Detecting special key combinations (Ctrl, Alt, Shift, Meta)
  - Converting special keys to their corresponding escape sequences
  - Handling modifier key state
  - Supporting extended key combinations
  """

  @type modifier :: :ctrl | :alt | :shift | :meta
  @type modifier_state :: %{modifier() => boolean()}

  @doc """
  Creates a new modifier state.

  ## Examples

      iex> state = SpecialKeys.new_state()
      iex> state.ctrl
      false
  """
  def new_state do
    %{
      ctrl: false,
      alt: false,
      shift: false,
      meta: false
    }
  end

  @doc """
  Updates the modifier state based on a key event.

  ## Examples

      iex> state = SpecialKeys.new_state()
      iex> state = SpecialKeys.update_state(state, "Control", true)
      iex> state.ctrl
      true
  """
  def update_state(state, key, pressed) do
    case key do
      "Control" -> %{state | ctrl: pressed}
      "Alt" -> %{state | alt: pressed}
      "Shift" -> %{state | shift: pressed}
      "Meta" -> %{state | meta: pressed}
      _ -> state
    end
  end

  @doc """
  Converts a key combination to its corresponding escape sequence.

  ## Examples

      iex> state = SpecialKeys.new_state() |> SpecialKeys.update_state("Control", true)
      iex> SpecialKeys.to_escape_sequence(state, "c")
      "\e[99"
  """
  def to_escape_sequence(state, key) do
    modifiers = calculate_modifiers(state)
    case key do
      key when byte_size(key) == 1 ->
        <<code::utf8>> = key
        if state.ctrl do
          # Handle Ctrl+key combinations
          case code do
            c when c >= ?a and c <= ?z -> "\e[#{modifiers}#{c - ?a + 1}"
            c when c >= ?A and c <= ?Z -> "\e[#{modifiers}#{c - ?A + 1}"
            _ -> "\e[#{modifiers}#{code}"
          end
        else
          "\e[#{modifiers}#{code}"
        end
      key when is_binary(key) ->
        case key do
          "ArrowUp" -> "\e[#{modifiers}A"
          "ArrowDown" -> "\e[#{modifiers}B"
          "ArrowRight" -> "\e[#{modifiers}C"
          "ArrowLeft" -> "\e[#{modifiers}D"
          "Home" -> "\e[#{modifiers}H"
          "End" -> "\e[#{modifiers}F"
          "PageUp" -> "\e[#{modifiers}5~"
          "PageDown" -> "\e[#{modifiers}6~"
          "Insert" -> "\e[#{modifiers}2~"
          "Delete" -> "\e[#{modifiers}3~"
          "F1" -> "\e[#{modifiers}P"
          "F2" -> "\e[#{modifiers}Q"
          "F3" -> "\e[#{modifiers}R"
          "F4" -> "\e[#{modifiers}S"
          "F5" -> "\e[#{modifiers}15~"
          "F6" -> "\e[#{modifiers}17~"
          "F7" -> "\e[#{modifiers}18~"
          "F8" -> "\e[#{modifiers}19~"
          "F9" -> "\e[#{modifiers}20~"
          "F10" -> "\e[#{modifiers}21~"
          "F11" -> "\e[#{modifiers}23~"
          "F12" -> "\e[#{modifiers}24~"
          "Tab" -> if state.ctrl, do: "\e[9", else: "\t"
          "Enter" -> "\r"
          "Backspace" -> "\b"
          "Escape" -> "\e"
          _ -> ""
        end
    end
  end

  # Private functions

  defp calculate_modifiers(state) do
    modifier_value = cond do
      state.ctrl -> 1
      true -> 0
    end + cond do
      state.alt -> 2
      true -> 0
    end + cond do
      state.shift -> 4
      true -> 0
    end + cond do
      state.meta -> 8
      true -> 0
    end

    if modifier_value > 0, do: "#{modifier_value};", else: ""
  end
end
