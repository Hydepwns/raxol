defmodule Raxol.Terminal.Command do
  @moduledoc """
  Defines the structure for terminal commands.
  """

  defstruct [
    :history,
    :current,
    :max_history
  ]

  @type t :: %__MODULE__{
          history: [String.t()],
          current: String.t() | nil,
          max_history: non_neg_integer()
        }
end
