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

    cond do
      byte_size(key) == 1 ->
        <<code::utf8>> = key
        "\e[#{modifiers}#{code}"

      key in [
        "ArrowUp",
        "ArrowDown",
        "ArrowRight",
        "ArrowLeft",
        "Home",
        "End",
        "PageUp",
        "PageDown",
        "Insert",
        "Delete",
        "F1",
        "F2",
        "F3",
        "F4",
        "F5",
        "F6",
        "F7",
        "F8",
        "F9",
        "F10",
        "F11",
        "F12"
      ] ->
        get_arrow_or_function_key_sequence(key, modifiers)

      key == "Tab" ->
        if state.ctrl, do: "\e[9", else: "\t"

      key == "Enter" ->
        "\r"

      key == "Backspace" ->
        "\b"

      key == "Escape" ->
        "\e"

      true ->
        ""
    end
  end

  @atom_key_sequences %{
    up: "\e[A",
    down: "\e[B",
    right: "\e[C",
    left: "\e[D",
    home: "\e[H",
    end: "\e[F",
    page_up: "\e[5~",
    page_down: "\e[6~",
    f1: "\eOP",
    f2: "\eOQ",
    f3: "\eOR",
    f4: "\eOS",
    f5: "\e[15~",
    f6: "\e[17~",
    f7: "\e[18~",
    f8: "\e[19~",
    f9: "\e[20~",
    f10: "\e[21~",
    f11: "\e[23~",
    f12: "\e[24~"
  }

  @doc """
  Converts an atom key to its corresponding escape sequence.
  """
  def atom_to_escape_sequence(key) do
    Map.get(@atom_key_sequences, key, "")
  end

  @doc """
  Converts a key with modifiers to its corresponding escape sequence.
  """
  def key_with_modifiers_to_escape_sequence(modifier_state, key) do
    modifier_code = calculate_modifier_code(modifier_state)

    case key do
      "ArrowUp" ->
        "\e[#{modifier_code}A"

      "ArrowDown" ->
        "\e[#{modifier_code}B"

      "ArrowRight" ->
        "\e[#{modifier_code}C"

      "ArrowLeft" ->
        "\e[#{modifier_code}D"

      _ when is_binary(key) and byte_size(key) == 1 ->
        char_code = :binary.first(key)
        "\e[#{modifier_code}#{char_code}"

      _ ->
        ""
    end
  end

  @key_sequences %{
    "ArrowUp" => "A",
    "ArrowDown" => "B",
    "ArrowRight" => "C",
    "ArrowLeft" => "D",
    "Home" => "H",
    "End" => "F",
    "PageUp" => "5~",
    "PageDown" => "6~",
    "Insert" => "2~",
    "Delete" => "3~",
    "F1" => "P",
    "F2" => "Q",
    "F3" => "R",
    "F4" => "S",
    "F5" => "15~",
    "F6" => "17~",
    "F7" => "18~",
    "F8" => "19~",
    "F9" => "20~",
    "F10" => "21~",
    "F11" => "23~",
    "F12" => "24~"
  }

  defp get_arrow_or_function_key_sequence(key, modifiers) do
    case Map.get(@key_sequences, key) do
      nil -> ""
      suffix -> "\e[#{modifiers}#{suffix}"
    end
  end

  # Private functions

  defp calculate_modifiers(state) do
    modifier_value =
      if(state.ctrl, do: 1, else: 0) +
        if(state.alt, do: 2, else: 0) +
        if(state.shift, do: 4, else: 0) +
        if state.meta, do: 8, else: 0

    if modifier_value > 0, do: "#{modifier_value};", else: ""
  end

  defp calculate_modifier_code(state) do
    code =
      if(state.ctrl, do: 1, else: 0) +
        if(state.shift, do: 2, else: 0) +
        if(state.alt, do: 4, else: 0) +
        if state.meta, do: 8, else: 0

    if code > 0, do: "#{code};", else: ""
  end
end
