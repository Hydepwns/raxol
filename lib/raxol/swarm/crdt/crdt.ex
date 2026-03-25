defmodule Raxol.Swarm.CRDT do
  @moduledoc """
  Behaviour for convergent replicated data types (CRDTs).

  All CRDTs must implement `merge/2` which is required to be:
  - Commutative: merge(a, b) == merge(b, a)
  - Associative: merge(merge(a, b), c) == merge(a, merge(b, c))
  - Idempotent: merge(a, a) == a
  """

  @type t :: term()

  @callback merge(t(), t()) :: t()
end
