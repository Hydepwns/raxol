defmodule Raxol.Sequence do
  @moduledoc '''
  Defines the structure for a sequence of terminal commands.
  '''

  @type t :: %__MODULE__{
          name: String.t(),
          steps: list(String.t())
        }

  defstruct [:name, :steps]
end
