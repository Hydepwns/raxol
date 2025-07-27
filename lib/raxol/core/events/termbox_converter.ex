defmodule Raxol.Core.Events.TermboxConverter do
  @moduledoc """
  Converts rrex_termbox v2.0.1 NIF events to Raxol.Core.Events.Event structs.

  This module handles the translation from the low-level rrex_termbox event format
  to the Raxol event system format.
  """

  import Bitwise
  alias Raxol.Core.Events.Event

  # Define key constants for use in guards (termbox2_nif key codes)
  @arrow_up 259
  @arrow_down 258
  @arrow_left 260
  @arrow_right 261
  @home 262
  @end_key 360
  @page_up 339
  @page_down 338
  @delete 330
  @backspace 263
  @tab 9
  @enter 13
  @esc 27
  @space 32
  @f1 265
  @f2 266
  @f3 267
  @f4 268
  @f5 269
  @f6 270
  @f7 271
  @f8 272
  @f9 273
  @f10 274
  @f11 275
  @f12 276

  # Key code to atom mapping
  @key_mapping %{
    @arrow_up => :up,
    @arrow_down => :down,
    @arrow_left => :left,
    @arrow_right => :right,
    @home => :home,
    @end_key => :end,
    @page_up => :page_up,
    @page_down => :page_down,
    @delete => :delete,
    @backspace => :backspace,
    @tab => :tab,
    @enter => :enter,
    @esc => :esc,
    @space => :space,
    @f1 => :f1,
    @f2 => :f2,
    @f3 => :f3,
    @f4 => :f4,
    @f5 => :f5,
    @f6 => :f6,
    @f7 => :f7,
    @f8 => :f8,
    @f9 => :f9,
    @f10 => :f10,
    @f11 => :f11,
    @f12 => :f12,
    0 => :char
  }

  # Mouse button code to atom mapping
  @button_mapping %{
    0 => :left,
    1 => :middle,
    2 => :right,
    3 => :release,
    4 => :wheel_up,
    5 => :wheel_down
  }

  # Button to action mapping
  @action_mapping %{
    :wheel_up => :scroll_up,
    :wheel_down => :scroll_down,
    :release => :release
  }

  @doc """
  Converts a rrex_termbox v2.0.1 event map to a Raxol Event struct.

  ## Parameters

  - event_map: The event map from rrex_termbox

  ## Returns

  - `{:ok, %Event{}}` if the conversion was successful
  - `:ignore` if the event should be ignored
  - `{:error, reason}` if the conversion failed
  """
  @spec convert(map()) :: {:ok, Event.t()} | :ignore | {:error, term()}
  def convert(event_map) do
    try do
      handle_event(event_map)
    catch
      kind, reason ->
        {:error, {kind, reason, __STACKTRACE__}}
    end
  end

  defp handle_event(%{
         type: :key,
         key: key_code,
         char: char_code,
         mod: mod_code
       }) do
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
  end

  defp handle_event(%{type: :resize, width: w, height: h}) do
    {:ok, %Event{type: :resize, data: %{width: w, height: h}}}
  end

  defp handle_event(%{type: :mouse, x: x, y: y, button: button_code}) do
    mouse_event = translate_mouse_event(x, y, button_code)
    {:ok, %Event{type: :mouse, data: mouse_event}}
  end

  defp handle_event(_), do: :ignore

  # Translates termbox key codes to Raxol key atoms
  defp translate_key(key_code) do
    Map.get(@key_mapping, key_code, :unknown)
  end

  # Translates termbox mouse events to Raxol mouse event maps
  defp translate_mouse_event(x, y, button_code) do
    button = Map.get(@button_mapping, button_code, :unknown)
    action = Map.get(@action_mapping, button, :press)

    %{
      x: x,
      y: y,
      button: button,
      action: action,
      ctrl: false,
      alt: false,
      shift: false
    }
  end
end
