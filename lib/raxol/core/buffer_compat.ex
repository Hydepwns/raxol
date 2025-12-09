defmodule Raxol.Core.Buffer do
  @moduledoc """
  Compatibility layer for legacy Raxol.Core.Buffer references.

  This module exists to maintain backwards compatibility with plugins
  that reference the old apps/raxol_core modules.

  Maps to Raxol.Terminal.Buffer operations where possible.
  """

  @doc "Create blank buffer (stub - returns empty map)"
  def create_blank_buffer(width, height) do
    %{width: width, height: height, cells: []}
  end

  @doc "Write text at coordinates (stub)"
  def write_at(buffer, _x, _y, _text), do: buffer
  def write_at(buffer, _x, _y, _text, _style), do: buffer

  @doc "Get cell at coordinates (stub)"
  def get_cell(_buffer, _x, _y), do: %{char: " ", style: %{}}

  @doc "Set cell at coordinates (stub)"
  def set_cell(buffer, _x, _y, _char, _style), do: buffer

  @doc "Convert buffer to string (stub)"
  def to_string(_buffer), do: ""
end
