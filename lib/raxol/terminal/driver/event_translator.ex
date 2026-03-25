defmodule Raxol.Terminal.Driver.EventTranslator do
  @moduledoc """
  Translates termbox NIF events into Raxol.Core.Events.Event structs.
  """

  alias Raxol.Core.Events.Event

  @doc """
  Translates a termbox event map into an Event struct.
  Returns {:ok, event}, :ignore, or {:error, reason}.
  """
  def translate(event_map) do
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           translate_event_map(event_map)
         end) do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end

  defp translate_event_map(%{
         type: :key,
         key: key_code,
         char: char_code,
         mod: mod_code
       }) do
    translated_key = translate_key(key_code, char_code, mod_code)
    {:ok, %Event{type: :key, data: translated_key}}
  end

  defp translate_event_map(%{type: :resize, width: w, height: h}) do
    {:ok, %Event{type: :resize, data: %{width: w, height: h}}}
  end

  defp translate_event_map(%{type: :mouse, x: x, y: y, button: btn_code}) do
    translated_button = translate_mouse_button(btn_code)
    {:ok, %Event{type: :mouse, data: %{x: x, y: y, button: translated_button}}}
  end

  defp translate_event_map(_other), do: :ignore

  defp translate_key(key_code, char_code, mod_code) do
    shift = Bitwise.&&&(mod_code, 1) != 0
    ctrl = Bitwise.&&&(mod_code, 2) != 0
    alt = Bitwise.&&&(mod_code, 4) != 0
    meta = Bitwise.&&&(mod_code, 8) != 0

    data = %{
      shift: shift,
      ctrl: ctrl,
      alt: alt,
      meta: meta,
      char: nil,
      key: nil
    }

    translate_key_or_char(data, char_code, key_code)
  end

  defp translate_key_or_char(data, char_code, _key_code) when char_code > 0 do
    Map.put(data, :char, <<char_code::utf8>>)
  end

  defp translate_key_or_char(data, _char_code, 65), do: Map.put(data, :key, :up)

  defp translate_key_or_char(data, _char_code, 66),
    do: Map.put(data, :key, :down)

  defp translate_key_or_char(data, _char_code, 67),
    do: Map.put(data, :key, :right)

  defp translate_key_or_char(data, _char_code, 68),
    do: Map.put(data, :key, :left)

  defp translate_key_or_char(data, _char_code, 265),
    do: Map.put(data, :key, :f1)

  defp translate_key_or_char(data, _char_code, 266),
    do: Map.put(data, :key, :f2)

  defp translate_key_or_char(data, _char_code, _key_code),
    do: Map.put(data, :key, :unknown)

  defp translate_mouse_button(btn_code) do
    case btn_code do
      0 -> :left
      1 -> :right
      2 -> :middle
      3 -> :wheel_up
      4 -> :wheel_down
      _ -> :unknown
    end
  end
end
