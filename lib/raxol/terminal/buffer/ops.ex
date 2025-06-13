defmodule Raxol.Terminal.Buffer.Ops do
  @moduledoc """
  Delegates buffer operations to Raxol.Terminal.Buffer.Operations.
  This module exists to resolve undefined function errors for BufferOps.*
  """

  alias Raxol.Terminal.Buffer.Operations, as: Impl

  defdelegate resize(buffer, width, height), to: Impl
  defdelegate maybe_scroll(buffer), to: Impl
  defdelegate index(buffer), to: Impl
  defdelegate next_line(buffer), to: Impl
  defdelegate reverse_index(buffer), to: Impl
end
