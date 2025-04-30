defmodule Raxol.Core.Events.TermboxConverter do
  @moduledoc """
  Converts rrex_termbox v2.0.1 NIF events to Raxol.Core.Events.Event structs.

  This module handles the translation from the low-level rrex_termbox event format
  to the Raxol event system format.
  """

  import Bitwise
  alias Raxol.Core.Events.Event
  alias Raxol.Terminal.Constants

  # Define key constants for use in guards
  @arrow_up Constants.key(:arrow_up)
  @arrow_down Constants.key(:arrow_down)
  @arrow_left Constants.key(:arrow_left)
  @arrow_right Constants.key(:arrow_right)
  @home Constants.key(:home)
  @end_key Constants.key(:end)
  @page_up Constants.key(:pgup)
  @page_down Constants.key(:pgdn)
  @delete Constants.key(:delete)
  @backspace Constants.key(:backspace)
  @tab Constants.key(:tab)
  @enter Constants.key(:enter)
  @esc Constants.key(:esc)
  @space Constants.key(:space)
  @f1 Constants.key(:f1)
  @f2 Constants.key(:f2)
  @f3 Constants.key(:f3)
  @f4 Constants.key(:f4)
  @f5 Constants.key(:f5)
  @f6 Constants.key(:f6)
  @f7 Constants.key(:f7)
  @f8 Constants.key(:f8)
  @f9 Constants.key(:f9)
  @f10 Constants.key(:f10)
  @f11 Constants.key(:f11)
  @f12 Constants.key(:f12)

  @doc """
  Converts a rrex_termbox v2.0.1 event map to a Raxol Event struct.

  ## Parameters

  - event_map: The event map from rrex_termbox

  ## Returns

  - {:ok, %Event{}} if the conversion was successful
  - :ignore if the event should be ignored
  - {:error, reason} if the conversion failed
  """
  @spec convert(map()) :: {:ok, Event.t()} | :ignore | {:error, term()}
  def convert(event_map) do
    try do
      case event_map do
        %{type: :key, key: key_code, char: char_code, mod: mod_code} ->
          event = %Event{
            type: :key,
            data: %{
              key: translate_key(key_code),
              char: if(char_code > 0, do: <<char_code::utf8>>, else: nil),
              ctrl: (mod_code &&& 2) > 0,
              alt: (mod_code &&& 4) > 0,
              shift: (mod_code &&& 1) > 0
            }
          }
          {:ok, event}

        %{type: :resize, width: w, height: h} ->
          {:ok, %Event{type: :resize, data: %{width: w, height: h}}}

        %{type: :mouse, x: x, y: y, button: button_code} ->
          mouse_event = translate_mouse_event(x, y, button_code)
          {:ok, %Event{type: :mouse, data: mouse_event}}

        _ ->
          :ignore
      end
    catch
      kind, reason ->
        {:error, {kind, reason, __STACKTRACE__}}
    end
  end

  # Translates termbox key codes to Raxol key atoms
  defp translate_key(key_code) do
    case key_code do
      c when c in [@arrow_up] -> :up
      c when c in [@arrow_down] -> :down
      c when c in [@arrow_left] -> :left
      c when c in [@arrow_right] -> :right
      c when c in [@home] -> :home
      c when c in [@end_key] -> :end
      c when c in [@page_up] -> :page_up
      c when c in [@page_down] -> :page_down
      c when c in [@delete] -> :delete
      c when c in [@backspace] -> :backspace
      c when c in [@tab] -> :tab
      c when c in [@enter] -> :enter
      c when c in [@esc] -> :esc
      c when c in [@space] -> :space
      c when c in [@f1] -> :f1
      c when c in [@f2] -> :f2
      c when c in [@f3] -> :f3
      c when c in [@f4] -> :f4
      c when c in [@f5] -> :f5
      c when c in [@f6] -> :f6
      c when c in [@f7] -> :f7
      c when c in [@f8] -> :f8
      c when c in [@f9] -> :f9
      c when c in [@f10] -> :f10
      c when c in [@f11] -> :f11
      c when c in [@f12] -> :f12
      0 -> :char  # When key is 0, it's a regular character input
      _ -> :unknown
    end
  end

  # Translates termbox mouse events to Raxol mouse event maps
  defp translate_mouse_event(x, y, button_code) do
    # Simple example mapping - will need to be expanded based on actual rrex_termbox codes
    button = case button_code do
      0 -> :left
      1 -> :middle
      2 -> :right
      3 -> :release
      4 -> :wheel_up
      5 -> :wheel_down
      _ -> :unknown
    end

    action = case button do
      :wheel_up -> :scroll_up
      :wheel_down -> :scroll_down
      :release -> :release
      _ -> :press
    end

    %{
      x: x,
      y: y,
      button: button,
      action: action,
      ctrl: false,  # These would come from mod flags in a real implementation
      alt: false,
      shift: false
    }
  end
end
