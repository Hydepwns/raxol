defmodule Raxol.Event do
  @moduledoc """
  Event handling and conversion utilities.

  This module handles conversion between ex_termbox events and Raxol
  events, as well as providing utilities for event handling.
  """

  require Logger
  # alias Raxol.Terminal.CharacterHandling # Remove unused
  require MapSet

  # Define the structure of the returned event map
  @type event_map :: %{
          type: :key | :resize | :mouse | :unknown,
          modifiers: list(atom()),
          # For key events
          key: atom() | integer() | nil,
          # For mouse events
          button: atom() | nil,
          # For resize events
          width: integer() | nil,
          height: integer() | nil,
          # For mouse events
          x: integer() | nil,
          y: integer() | nil,
          # For unknown events
          raw: term() | nil
        }

  @doc """
  Converts an ex_termbox event to a Raxol event.

  ## Parameters

  * `event` - An ex_termbox event tuple

  ## Returns

  A Raxol event map.

  ## Example

  ```elixir
  event = Raxol.Event.convert({:key, :none, ?a})
  # Returns %{type: :key, meta: :none, key: ?a}
  ```
  """
  @spec convert(
          {:key, integer() | atom(), term()}
          | {:resize, integer(), integer()}
          | {:mouse, atom(), integer(), integer(), integer() | atom()}
          | term()
        ) :: event_map()
  # Takes the standard ex_termbox tuple like {:key, meta_int, key_code_or_char}
  def convert({:key, meta_int, key}) when is_integer(meta_int) do
    # Handle Ctrl + Letter combinations (ASCII codes 1-26)
    cond do
      meta_int == 0 and key >= 1 and key <= 26 ->
        # Ctrl is implied, convert code back to letter
        modifiers = [:ctrl]
        converted_key = key + ?a - 1

        %{
          type: :key,
          modifiers: modifiers,
          key: converted_key
        }

      # Handle Ctrl + Backspace (sometimes sends code 8)
      meta_int == 0 and key == 8 ->
        modifiers = [:ctrl]
        converted_key = :backspace

        %{
          type: :key,
          modifiers: modifiers,
          key: converted_key
        }

      # Default case: Use standard modifier logic and key conversion
      true ->
        modifiers = convert_modifiers(meta_int)
        converted_key = convert_key(key)

        %{
          type: :key,
          modifiers: modifiers,
          key: converted_key
        }
    end
  end

  def convert({:resize, width, height}) do
    %{
      type: :resize,
      width: width,
      height: height
    }
  end

  def convert({:mouse, button, x, y, meta}) do
    modifiers = if is_integer(meta), do: convert_modifiers(meta), else: [meta]

    %{
      type: :mouse,
      button: button,
      x: x,
      y: y,
      modifiers: modifiers
    }
  end

  def convert(event) do
    %{
      type: :unknown,
      raw: event
    }
  end

  @doc """
  Checks if an event is a key press matching the given key and *any* of the specified modifiers.
  """
  def key_match?(event, key, modifiers \\ [])

  def key_match?(
        %{type: :key, modifiers: event_mods, key: event_key},
        key,
        modifiers
      ) do
    event_key == key && Enum.all?(modifiers, fn mod -> mod in event_mods end)
  end

  def key_match?(_, _, _), do: false

  @doc """
  Checks if an event is a specific key press with *exact* modifiers.
  """
  def key_exact_match?(event, key, modifiers \\ [])

  def key_exact_match?(
        %{type: :key, modifiers: event_mods, key: event_key},
        key,
        modifiers
      ) do
    event_key == key &&
      MapSet.equal?(MapSet.new(event_mods), MapSet.new(modifiers))
  end

  def key_exact_match?(_, _, _), do: false

  @doc "Checks if an event is a specific key press (ignoring modifiers)."
  def key_is?(%{type: :key, key: event_key}, key), do: event_key == key
  def key_is?(_, _), do: false

  @doc "Checks if an event has the Ctrl modifier and matches the given key."
  def ctrl_key?(%{type: :key, modifiers: mods, key: event_key}, key),
    do: :ctrl in mods && event_key == key

  def ctrl_key?(_, _), do: false

  @doc "Checks if an event has the Shift modifier and matches the given key."
  def shift_key?(%{type: :key, modifiers: mods, key: event_key}, key),
    do: :shift in mods && event_key == key

  def shift_key?(_, _), do: false

  @doc "Checks if an event has the Alt modifier and matches the given key."
  def alt_key?(%{type: :key, modifiers: mods, key: event_key}, key),
    do: :alt in mods && event_key == key

  def alt_key?(_, _), do: false

  @doc "Checks if an event is a mouse click."
  def mouse_click?(%{type: :mouse, button: event_button}, button),
    do: event_button == button

  def mouse_click?(%{type: :mouse}, :any), do: true
  def mouse_click?(_, _), do: false

  @doc "Checks if an event is a resize event."
  def resize?(%{type: :resize}), do: true
  def resize?(_), do: false

  # --- Private Helpers ---

  defp convert_modifiers(0), do: []
  defp convert_modifiers(1), do: [:alt]
  defp convert_modifiers(2), do: [:ctrl]
  defp convert_modifiers(3), do: [:alt, :ctrl]
  defp convert_modifiers(4), do: [:shift]
  defp convert_modifiers(5), do: [:alt, :shift]
  defp convert_modifiers(6), do: [:ctrl, :shift]
  defp convert_modifiers(7), do: [:alt, :ctrl, :shift]

  defp convert_modifiers(meta_int) do
    Logger.warning("Unknown key modifier integer: #{meta_int}")
    [:unknown]
  end

  # Convert numeric key codes to named keys or keep printable chars
  defp convert_key(13), do: :enter
  defp convert_key(9), do: :tab
  defp convert_key(27), do: :escape
  defp convert_key(32), do: :space
  defp convert_key(127), do: :backspace
  # NCurses backspace
  defp convert_key(263), do: :backspace
  defp convert_key(330), do: :delete
  defp convert_key(259), do: :arrow_up
  defp convert_key(258), do: :arrow_down
  defp convert_key(260), do: :arrow_left
  defp convert_key(261), do: :arrow_right
  defp convert_key(262), do: :home
  defp convert_key(360), do: :end
  defp convert_key(339), do: :page_up
  defp convert_key(338), do: :page_down
  defp convert_key(265), do: :f1
  defp convert_key(266), do: :f2
  defp convert_key(267), do: :f3
  defp convert_key(268), do: :f4
  defp convert_key(269), do: :f5
  defp convert_key(270), do: :f6
  defp convert_key(271), do: :f7
  defp convert_key(272), do: :f8
  defp convert_key(273), do: :f9
  defp convert_key(274), do: :f10
  defp convert_key(275), do: :f11
  defp convert_key(276), do: :f12
  # Keep printable ASCII/Unicode chars
  defp convert_key(key) when key >= 32, do: key
  # Fallback for unmapped control codes, etc.
  defp convert_key(key), do: {:unknown_key, key}
end
