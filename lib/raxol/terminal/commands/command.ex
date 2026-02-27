defmodule Raxol.Terminal.Commands.Command do
  @moduledoc """
  Defines the structure for terminal commands.
  """

  defstruct [
    :history,
    :current,
    :max_history,
    :command_buffer,
    :history_index,
    :last_key_event,
    :command_state
  ]

  @type t :: %__MODULE__{
          history: [String.t()],
          current: String.t() | nil,
          max_history: non_neg_integer(),
          command_buffer: String.t(),
          history_index: integer(),
          last_key_event: any(),
          command_state: any()
        }
end
