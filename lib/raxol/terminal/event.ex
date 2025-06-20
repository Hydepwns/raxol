defmodule Raxol.Terminal.Event do
  @moduledoc """
  Defines the structure for terminal events.
  """

  defstruct [
    :handlers,
    :queue
  ]

  @type t :: %__MODULE__{
          handlers: map(),
          queue: :queue.queue()
        }
end
