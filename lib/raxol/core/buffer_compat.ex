defmodule Raxol.Core.Buffer do
  @moduledoc """
  Compatibility layer for legacy Raxol.Core.Buffer references.

  This module exists to maintain backwards compatibility with plugins
  that reference the old apps/raxol_core modules.

  Maps to Raxol.Terminal.Buffer operations.
  """

  alias Raxol.Terminal.Buffer

  @doc "Write text at specific coordinates"
  def write_at(buffer, x, y, text) when is_binary(text) do
    Buffer.write_at(buffer, x, y, text)
  end

  def write_at(buffer, x, y, text, style) when is_binary(text) and is_map(style) do
    Buffer.write_at(buffer, x, y, text, style)
  end
end
