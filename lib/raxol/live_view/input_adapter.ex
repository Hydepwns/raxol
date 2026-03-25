defmodule Raxol.LiveView.InputAdapter do
  @moduledoc """
  Translates browser keyboard events into `Raxol.Core.Events.Event` structs.

  This is the LiveView counterpart of `Raxol.Terminal.ANSI.InputParser`,
  which does the same translation for terminal ANSI escape sequences.
  """

  alias Raxol.Core.Events.Event

  @special_keys %{
    "Enter" => :enter,
    "Backspace" => :backspace,
    "Tab" => :tab,
    "Escape" => :escape,
    "ArrowUp" => :up,
    "ArrowDown" => :down,
    "ArrowLeft" => :left,
    "ArrowRight" => :right,
    "Home" => :home,
    "End" => :end,
    "PageUp" => :page_up,
    "PageDown" => :page_down,
    "Delete" => :delete,
    "Insert" => :insert,
    "F1" => :f1,
    "F2" => :f2,
    "F3" => :f3,
    "F4" => :f4,
    "F5" => :f5,
    "F6" => :f6,
    "F7" => :f7,
    "F8" => :f8,
    "F9" => :f9,
    "F10" => :f10,
    "F11" => :f11,
    "F12" => :f12
  }

  @modifier_keys ~w(Shift Control Alt Meta CapsLock)

  @doc """
  Translates a browser keydown event map into a `Raxol.Core.Events.Event`.

  The input `params` map is expected to have keys like `"key"`, `"ctrlKey"`,
  `"altKey"`, `"shiftKey"`, and `"metaKey"` as provided by Phoenix LiveView's
  `phx-window-keydown` binding.
  """
  @spec translate_key_event(map()) :: Event.t()
  def translate_key_event(params) do
    key_name = Map.get(params, "key", "")
    modifiers = extract_modifiers(params)

    cond do
      key_name in @modifier_keys ->
        Event.new(:key, Map.merge(%{key: :modifier, char: nil}, modifiers))

      special = Map.get(@special_keys, key_name) ->
        Event.new(:key, Map.merge(%{key: special, char: nil}, modifiers))

      true ->
        Event.new(:key, Map.merge(%{key: :char, char: key_name}, modifiers))
    end
  end

  defp extract_modifiers(params) do
    %{
      ctrl: Map.get(params, "ctrlKey", false),
      alt: Map.get(params, "altKey", false),
      shift: Map.get(params, "shiftKey", false)
    }
  end
end
