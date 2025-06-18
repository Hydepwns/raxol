defmodule Raxol.Protocols.Protocol do
  @moduledoc '''
  Protocol module for handling protocol-related functionality.
  '''

  defstruct [
    :id,
    :name,
    :description,
    :version,
    :created_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          version: String.t(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  def new(attrs \\ %{}) do
    struct!(__MODULE__, attrs)
  end
end
