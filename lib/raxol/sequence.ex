defmodule Raxol.Sequence do
  @moduledoc """
  Manages sequences and animations.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          steps: list(String.t())
        }

  defstruct [:name, :steps]
end
