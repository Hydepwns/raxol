defmodule Raxol.Terminal.ScreenBuffer.Mode do
  @moduledoc """
  Deprecated: This module is not used in the codebase.

  Originally intended for mode state but never integrated.
  Use `Raxol.Terminal.ModeManager` instead.
  """

  defstruct [:insert_mode, :origin_mode, :auto_wrap, :cursor_visible]

  @type t :: %__MODULE__{
          insert_mode: boolean(),
          origin_mode: boolean(),
          auto_wrap: boolean(),
          cursor_visible: boolean()
        }

  def init do
    %__MODULE__{
      insert_mode: false,
      origin_mode: false,
      auto_wrap: true,
      cursor_visible: true
    }
  end

  def handle(%__MODULE__{} = state, mode, value) do
    case mode do
      :insert_mode -> %{state | insert_mode: value}
      :origin_mode -> %{state | origin_mode: value}
      :auto_wrap -> %{state | auto_wrap: value}
      :cursor_visible -> %{state | cursor_visible: value}
      _ -> state
    end
  end
end
