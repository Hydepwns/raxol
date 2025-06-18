defmodule Raxol.Terminal.Sync.Component do
  @moduledoc '''
  Defines the structure for synchronized components.
  '''

  defstruct [
    :id,
    :type,
    :state,
    :version,
    :timestamp,
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          state: term(),
          version: integer(),
          timestamp: integer(),
          metadata: map()
        }
end
