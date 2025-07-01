defmodule Raxol.Terminal.Sync.Component do
  @moduledoc """
  Defines the structure for synchronized components.
  """

  defstruct [
    :id,
    :type,
    :state,
    :version,
    :timestamp,
    :metadata,
    :sync_count,
    :conflict_count
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          state: term(),
          version: integer(),
          timestamp: integer(),
          metadata: map(),
          sync_count: non_neg_integer(),
          conflict_count: non_neg_integer()
        }
end
