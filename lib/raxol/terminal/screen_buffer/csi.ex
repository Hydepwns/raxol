defmodule Raxol.Terminal.ScreenBuffer.CSI do
  @moduledoc """
  Handles CSI (Control Sequence Introducer) sequences for the screen buffer.
  """

  defstruct [
    :params,
    :intermediate,
    :final
  ]

  @type t :: %__MODULE__{
          params: list(String.t()),
          intermediate: String.t(),
          final: String.t()
        }

  @doc """
  Initializes a new CSI state.
  """
  def init do
    %__MODULE__{
      params: [],
      intermediate: "",
      final: ""
    }
  end

  @doc """
  Handles a CSI sequence.
  """
  def handle_sequence(%__MODULE__{} = state, sequence, params) do
    %{state | params: params, intermediate: sequence, final: sequence}
  end
end
