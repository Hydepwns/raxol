defmodule Raxol.Terminal.ScreenBuffer.CSI do
  @moduledoc """
  Deprecated: This module is not used in the codebase.

  Originally intended for CSI sequence handling but never integrated.
  CSI parsing is handled by `Raxol.Terminal.ANSI.Parser` instead.
  """

  defstruct [
    :params,
    :intermediate,
    :final_byte
  ]

  @type t :: %__MODULE__{
          params: list(String.t()),
          intermediate: String.t(),
          final_byte: String.t()
        }

  def init do
    %__MODULE__{
      params: [],
      intermediate: "",
      final_byte: ""
    }
  end

  def handle_sequence(%__MODULE__{} = state, sequence, params) do
    %{state | params: params, intermediate: sequence, final_byte: sequence}
  end
end
